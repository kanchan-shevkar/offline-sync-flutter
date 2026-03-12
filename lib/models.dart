import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  bool liked;

  @HiveField(4)
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.liked = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

@HiveType(typeId: 2)
enum SyncActionType {
  @HiveField(0)
  create,

  @HiveField(1)
  update,

  @HiveField(2)
  likeToggle,
}

@HiveType(typeId: 1)
class SyncQueueItem extends HiveObject {
  @HiveField(0)
  String idempotencyKey;

  @HiveField(1)
  String noteId;

  @HiveField(2)
  SyncActionType actionType;

  @HiveField(3)
  Map<String, dynamic> payload;

  @HiveField(4)
  int retryCount;

  @HiveField(5)
  DateTime createdAt;

  SyncQueueItem({
    required this.idempotencyKey,
    required this.noteId,
    required this.actionType,
    required this.payload,
    this.retryCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
