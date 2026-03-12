import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const _notesBoxName = 'notes_box';
const _queueBoxName = 'sync_queue_box';

String buildIdempotencyKey({
  required String noteId,
  required SyncActionType actionType,
  required DateTime updatedAt,
}) {
  return '$noteId-${actionType.name}-${updatedAt.millisecondsSinceEpoch}';
}

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

class SyncMetrics {
  final int successCount;
  final int failureCount;
  final int droppedCount;

  const SyncMetrics({
    this.successCount = 0,
    this.failureCount = 0,
    this.droppedCount = 0,
  });

  SyncMetrics copyWith({
    int? successCount,
    int? failureCount,
    int? droppedCount,
  }) {
    return SyncMetrics(
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      droppedCount: droppedCount ?? this.droppedCount,
    );
  }
}

class SyncMetricsNotifier extends StateNotifier<SyncMetrics> {
  SyncMetricsNotifier() : super(const SyncMetrics());

  void recordSuccess() =>
      state = state.copyWith(successCount: state.successCount + 1);

  void recordFailure() =>
      state = state.copyWith(failureCount: state.failureCount + 1);

  void recordDropped() =>
      state = state.copyWith(droppedCount: state.droppedCount + 1);

  void reset() => state = const SyncMetrics();
}

final syncMetricsProvider =
    StateNotifierProvider<SyncMetricsNotifier, SyncMetrics>((ref) {
  return SyncMetricsNotifier();
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return NotesRepository(
    firestore: firestore,
  );
});

final syncQueueManagerProvider = Provider<SyncQueueManager>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final notesRepo = ref.watch(notesRepositoryProvider);
  final metrics = ref.watch(syncMetricsProvider.notifier);
  return SyncQueueManager(
    firestore: firestore,
    notesRepository: notesRepo,
    metrics: metrics,
  );
});

final notesStreamProvider = StreamProvider<List<Note>>((ref) async* {
  final box = await Hive.openBox<Note>(_notesBoxName);
  yield box.values.toList();
  yield* box.watch().map((_) => box.values.toList());
});

class NotesRepository {
  NotesRepository({
    required this.firestore,
  });

  final FirebaseFirestore firestore;
  final _uuid = const Uuid();

  Future<Box<Note>> _openNotesBox() => Hive.openBox<Note>(_notesBoxName);

  Future<Box<SyncQueueItem>> _openQueueBox() =>
      Hive.openBox<SyncQueueItem>(_queueBoxName);

  Future<Note> addNoteLocal({
    required String title,
    required String content,
  }) async {
    final box = await _openNotesBox();
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
    );
    await box.put(note.id, note);
    return note;
  }

  Future<void> toggleLikeLocal(Note note) async {
    final box = await _openNotesBox();
    note.liked = !note.liked;
    note.updatedAt = DateTime.now();
    await box.put(note.id, note);
  }

  Future<void> refreshFromRemote() async {
    final box = await _openNotesBox();
    final snapshot = await firestore.collection('notes').get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final remoteUpdatedAt = (data['updatedAt'] as Timestamp).toDate();
      final local = box.get(doc.id);
      if (local == null || remoteUpdatedAt.isAfter(local.updatedAt)) {
        final note = Note(
          id: doc.id,
          title: data['title'] as String,
          content: data['content'] as String,
          liked: data['liked'] as bool? ?? false,
          updatedAt: remoteUpdatedAt,
        );
        await box.put(note.id, note);
      }
    }
  }

  Future<void> enqueueAction({
    required Note note,
    required SyncActionType actionType,
    Map<String, dynamic>? extraPayload,
  }) async {
    final queueBox = await _openQueueBox();
    final idempotencyKey = buildIdempotencyKey(
      noteId: note.id,
      actionType: actionType,
      updatedAt: note.updatedAt,
    );

    // Simple idempotency: if an item with this key already exists, skip enqueue.
    if (queueBox.containsKey(idempotencyKey)) {
      return;
    }

    final payload = <String, dynamic>{
      'title': note.title,
      'content': note.content,
      'liked': note.liked,
      'updatedAt': note.updatedAt.toIso8601String(),
      if (extraPayload != null) ...extraPayload,
    };

    final item = SyncQueueItem(
      idempotencyKey: idempotencyKey,
      noteId: note.id,
      actionType: actionType,
      payload: payload,
    );
    await queueBox.put(item.idempotencyKey, item);
    // ignore: avoid_print
    print('[QUEUE] Enqueued ${item.actionType} for note ${item.noteId}');
  }
}

class SyncQueueManager {
  SyncQueueManager({
    required this.firestore,
    required this.notesRepository,
    required this.metrics,
  });

  final FirebaseFirestore firestore;
  final NotesRepository notesRepository;
  final SyncMetricsNotifier metrics;

  Future<Box<SyncQueueItem>> _openQueueBox() =>
      Hive.openBox<SyncQueueItem>(_queueBoxName);

  Future<int> getPendingCount() async {
    final box = await _openQueueBox();
    return box.length;
  }

  Future<void> processQueueOnce() async {
    final box = await _openQueueBox();
    final items = box.values.toList();

    // ignore: avoid_print
    print('[SYNC] Starting queue processing: ${items.length} items');

    for (final item in items) {
      try {
        await _applyItem(item);
        await box.delete(item.idempotencyKey);
        metrics.recordSuccess();
        // ignore: avoid_print
        print('[SYNC] Success for ${item.idempotencyKey}');
      } catch (e) {
        // ignore: avoid_print
        print('[SYNC] Failure for ${item.idempotencyKey}: $e');
        metrics.recordFailure();

        // Retry once with a small backoff, then persist retryCount.
        if (item.retryCount == 0) {
          final backoffMs = 600;
          // ignore: avoid_print
          print(
            '[SYNC] Retrying after ${backoffMs}ms for ${item.idempotencyKey}',
          );
          await Future<void>.delayed(Duration(milliseconds: backoffMs));
          try {
            await _applyItem(item);
            await box.delete(item.idempotencyKey);
            metrics.recordSuccess();
            // ignore: avoid_print
            print('[SYNC] Success on retry for ${item.idempotencyKey}');
            continue;
          } catch (e2) {
            metrics.recordFailure();
            // ignore: avoid_print
            print('[SYNC] Retry failed for ${item.idempotencyKey}: $e2');
            item.retryCount = 1;
            await item.save();
            continue;
          }
        }

        // Already retried once earlier; drop it.
        await box.delete(item.idempotencyKey);
        metrics.recordDropped();
        // ignore: avoid_print
        print('[SYNC] Dropping item after retries ${item.idempotencyKey}');
      }
    }

    await notesRepository.refreshFromRemote();
  }

  Future<void> _applyItem(SyncQueueItem item) async {
    final ref = firestore.collection('notes').doc(item.noteId);
    switch (item.actionType) {
      case SyncActionType.create:
      case SyncActionType.update:
        await ref.set(
          {
            ...item.payload,
            'updatedAt': DateTime.parse(item.payload['updatedAt'] as String),
          },
          SetOptions(merge: true),
        );
        break;
      case SyncActionType.likeToggle:
        await ref.set(
          {
            'liked': item.payload['liked'],
            'updatedAt': DateTime.parse(item.payload['updatedAt'] as String),
          },
          SetOptions(merge: true),
        );
        break;
    }
  }
}
