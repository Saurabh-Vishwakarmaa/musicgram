import 'package:appwrite/models.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final String? attachmentType; // null, 'song', 'album', etc.
  final String? attachmentId; // References a song, album, etc.

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.attachmentType,
    this.attachmentId,
  });

  factory Message.fromDocument(Document document) {
    return Message(
      id: document.$id,
      senderId: document.data['sender_id'],
      receiverId: document.data['receiver_id'],
      content: document.data['content'] ?? '',
      createdAt: DateTime.parse(document.data['created_at']),
      isRead: document.data['is_read'] ?? false,
      attachmentType: document.data['attachment_type'],
      attachmentId: document.data['attachment_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'attachment_type': attachmentType,
      'attachment_id': attachmentId,
    };
  }

  Message markAsRead() {
    return Message(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      createdAt: createdAt,
      isRead: true,
      attachmentType: attachmentType,
      attachmentId: attachmentId,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, senderId: $senderId, receiverId: $receiverId)';
  }
}