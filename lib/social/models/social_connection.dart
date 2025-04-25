import 'package:appwrite/models.dart';

class SocialConnection {
  final String id;
  final String followerId;
  final String followeeId;
  final DateTime createdAt;

  SocialConnection({
    required this.id,
    required this.followerId,
    required this.followeeId,
    required this.createdAt,
  });

  factory SocialConnection.fromDocument(Document document) {
    return SocialConnection(
      id: document.$id,
      followerId: document.data['follower_id'],
      followeeId: document.data['followee_id'],
      createdAt: DateTime.parse(document.data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'follower_id': followerId,
      'followee_id': followeeId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'SocialConnection(id: $id, followerId: $followerId, followeeId: $followeeId)';
  }
}