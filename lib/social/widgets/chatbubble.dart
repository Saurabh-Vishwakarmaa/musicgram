import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime timestamp;
  final bool isRead;
  final String messageType;
  final VoidCallback? onLongPress;
  final MessageStatus status; // Add this parameter

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
    this.onLongPress,
    this.status = MessageStatus.sent, // Default to sent
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(timestamp);
    
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 64 : 0,
          right: isMe ? 0 : 64,
        ),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? Colors.greenAccent.shade200 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Message content based on type
              if (messageType == 'text') 
                _buildTextMessage()
              else if (messageType == 'image')
                _buildImageMessage()
              else if (messageType == 'song')
                _buildSongMessage()
              else
                _buildTextMessage(), // Default to text
              
              SizedBox(height: 4),
              
              // Time and read status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeago.format(timestamp, locale: 'en_short'),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(width: 4),
                  if (isMe) _buildStatusIndicator(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTextMessage() {
    return Text(
      message,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }
  
  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 200,
              height: 150,
              color: Colors.grey[300],
              child: Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSongMessage() {
    // This would display a song preview
    return Container(
      width: 200,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.music_note, color: Colors.grey[600]),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Song Title',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Artist Name',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.play_circle_fill,
            color: Colors.green,
            size: 24,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusIndicator() {
    // Status icons
    IconData icon;
    Color color;
    
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }
    
    return Icon(icon, size: 12, color: color);
  }
}

enum MessageStatus { sending, sent, delivered, read, failed }