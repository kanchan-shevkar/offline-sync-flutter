import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sync_flutter/models.dart';
import 'package:offline_sync_flutter/sync_repository.dart';

void main() {
  test('buildIdempotencyKey is deterministic', () {
    final t = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final k1 = buildIdempotencyKey(
      noteId: 'n1',
      actionType: SyncActionType.create,
      updatedAt: t,
    );
    final k2 = buildIdempotencyKey(
      noteId: 'n1',
      actionType: SyncActionType.create,
      updatedAt: t,
    );
    expect(k1, k2);
  });

  test('buildIdempotencyKey changes when updatedAt changes', () {
    final k1 = buildIdempotencyKey(
      noteId: 'n1',
      actionType: SyncActionType.create,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    );
    final k2 = buildIdempotencyKey(
      noteId: 'n1',
      actionType: SyncActionType.create,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
    );
    expect(k1, isNot(k2));
  });
}

