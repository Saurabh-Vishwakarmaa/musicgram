import 'package:flutter/material.dart';
import 'package:appwrite/models.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessageBubble extends StatelessWidget {
  final Document message;
  final bool isCurrentUser;
  final String currentUserId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final messageText = message.data['message'] as String;
    final timestamp = DateTime.parse(message.data['timestamp']);
    final isRead = message.data['is_read'] ?? false;

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isCurrentUser 
              ? Theme.of(context).primaryColor 
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(18),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messageText,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeago.format(timestamp),
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                if (isCurrentUser)
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.blue : Colors.white70,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}