import 'package:flutter/material.dart';
import 'package:musicgram4/social/models/activity.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityItem extends StatelessWidget {
  final Activity activity;
  
  const ActivityItem({Key? key, required this.activity}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity icon
            _buildActivityIcon(),
            SizedBox(width: 12),
            
            // Activity content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity description
                  _buildActivityDescription(context),
                  SizedBox(height: 4),
                  
                  // Timestamp
                  Text(
                    timeago.format(activity.createdAt),
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityIcon() {
    IconData icon;
    Color color;
    
    switch (activity.activityType) {
      case 'listen':
        icon = Icons.headphones;
        color = Colors.purple;
        break;
      case 'follow':
        icon = Icons.person_add;
        color = Colors.blue;
        break;
      case 'paired_listen':
        icon = Icons.people;
        color = Colors.green;
        break;
      default:
        icon = Icons.music_note;
        color = Colors.grey;
    }
    
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: 24),
    );
  }
  
  Widget _buildActivityDescription(BuildContext context) {
    String description;
    
    switch (activity.activityType) {
      case 'listen':
        final songName = activity.metadata['song_name'] ?? 'a song';
        final artistName = activity.metadata['artist_name'] ?? 'an artist';
        description = 'Listened to $songName by $artistName';
        break;
      case 'follow':
        final targetName = activity.metadata['target_name'] ?? 'someone';
        description = 'Started following $targetName';
        break;
      case 'paired_listen':
        final partnerName = activity.metadata['partner_name'] ?? 'a friend';
        final songName = activity.metadata['song_name'] ?? 'a song';
        description = 'Listened to $songName together with $partnerName';
        break;
      default:
        description = 'Did something on MusicGram';
    }
    
    return Text(
      description,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}