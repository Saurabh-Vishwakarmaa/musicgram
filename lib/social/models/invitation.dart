import 'package:appwrite/models.dart';

class Invitation {
  final String id;
  final String senderId;
  final String recipientEmail;
  final String? personalMessage;
  final String status; // 'sent', 'accepted', 'expired'
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String? newUserId; // ID of user who accepted the invitation

  Invitation({
    required this.id,
    required this.senderId,
    required this.recipientEmail,
    this.personalMessage,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.newUserId,
  });

  factory Invitation.fromDocument(Document document) {
    return Invitation(
      id: document.$id,
      senderId: document.data['sender_id'],
      recipientEmail: document.data['recipient_email'],
      personalMessage: document.data['personal_message'],
      status: document.data['status'],
      createdAt: DateTime.parse(document.data['created_at']),
      acceptedAt: document.data['accepted_at'] != null 
          ? DateTime.parse(document.data['accepted_at']) 
          : null,
      newUserId: document.data['new_user_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_email': recipientEmail,
      'personal_message': personalMessage,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'new_user_id': newUserId,
    };
  }

  @override
  String toString() {
    return 'Invitation(id: $id, senderId: $senderId, email: $recipientEmail, status: $status)';
  }
}