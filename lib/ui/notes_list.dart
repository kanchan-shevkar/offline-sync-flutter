import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../sync_repository.dart';
import 'add_note.dart';

final pendingQueueCountProvider = FutureProvider<int>((ref) async {
  final manager = ref.watch(syncQueueManagerProvider);
  return manager.getPendingCount();
});

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Background refresh (local-first UI still shows Hive immediately).
      try {
        await ref.read(notesRepositoryProvider).refreshFromRemote();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final pendingAsync = ref.watch(pendingQueueCountProvider);
    final metrics = ref.watch(syncMetricsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text(
          'Offline Notes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final manager = ref.read(syncQueueManagerProvider);
              await manager.processQueueOnce();
              ref.invalidate(pendingQueueCountProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddNoteScreen()),
          );
          ref.invalidate(pendingQueueCountProvider);
        },
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.orange.shade100,
            padding: const EdgeInsets.all(10),
            child: pendingAsync.when(
              data: (count) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Pending: $count',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'OK: ${metrics.successCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Fail: ${metrics.failureCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dropped: ${metrics.droppedCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              loading: () => const Text(
                'Sync stats loading…',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              error: (_, __) => const Text(
                'Sync stats error',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: notesAsync.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return const Center(
                    child: Text('No notes yet. Add one!'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final repo = ref.read(notesRepositoryProvider);
                    await repo.refreshFromRemote();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      note.content,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  note.liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: note.liked ? Colors.red : Colors.grey,
                                ),
                                onPressed: () async {
                                  final repo = ref.read(notesRepositoryProvider);
                                  await repo.toggleLikeLocal(note);
                                  await repo.enqueueAction(
                                    note: note,
                                    actionType: SyncActionType.likeToggle,
                                  );
                                  ref.invalidate(pendingQueueCountProvider);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}