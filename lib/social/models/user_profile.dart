import 'package:appwrite/models.dart';

class UserProfile {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarFileId;
  final int followersCount;
  final int followingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.bio,
    this.avatarFileId,
    required this.followersCount,
    required this.followingCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromDocument(Document document) {
    return UserProfile(
      id: document.$id,
      userId: document.data['user_id'],
      username: document.data['username'],
      displayName: document.data['display_name'],
      bio: document.data['bio'] ?? '',
      avatarFileId: document.data['avatar_file_id'],
      followersCount: document.data['followers_count'] ?? 0,
      followingCount: document.data['following_count'] ?? 0,
      createdAt: DateTime.parse(document.data['created_at']),
      updatedAt: DateTime.parse(document.data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'avatar_file_id': avatarFileId,
      'followers_count': followersCount,
      'following_count': followingCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? bio,
    String? avatarFileId,
    int? followersCount,
    int? followingCount,
  }) {
    return UserProfile(
      id: this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarFileId: avatarFileId ?? this.avatarFileId,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, userId: $userId, username: $username, displayName: $displayName)';
  }
}