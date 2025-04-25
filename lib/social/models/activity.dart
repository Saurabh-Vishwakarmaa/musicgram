import 'package:appwrite/models.dart';

class Activity {
  final String id;
  final String userId;
  final String activityType; // e.g., 'listen', 'follow', 'paired_listen'
  final Map<String, dynamic> metadata; // Flexible metadata for different activity types
  final DateTime createdAt;

  Activity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.metadata,
    required this.createdAt,
  });

  factory Activity.fromDocument(Document document) {
    return Activity(
      id: document.$id,
      userId: document.data['user_id'],
      activityType: document.data['activity_type'],
      metadata: document.data['metadata'] ?? {},
      createdAt: DateTime.parse(document.data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'activity_type': activityType,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Activity(id: $id, userId: $userId, type: $activityType)';
  }
}