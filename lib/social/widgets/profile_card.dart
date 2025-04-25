import 'package:flutter/material.dart';
import 'package:musicgram4/social/models/user_profile.dart';

class ProfileCard extends StatelessWidget {
  final UserProfile profile;
  
  const ProfileCard({
    Key? key,
    required this.profile,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: profile.avatarFileId != null
                ? NetworkImage(profile.avatarFileId!) // You might need a method to get the file URL
                : null,
              child: profile.avatarFileId == null
                ? Icon(Icons.person, size: 50)
                : null,
            ),
            
            SizedBox(height: 16),
            
            // Display name
            Text(
              profile.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            
            // Username
            Text(
              '@${profile.username}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 8),
            
            // Bio
            if (profile.bio.isNotEmpty)
              Text(
                profile.bio,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            
            SizedBox(height: 16),
            
            // Follower/Following counts
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatColumn(context, '${profile.followersCount}', 'Followers'),
                Container(
                  height: 24,
                  child: VerticalDivider(
                    width: 32,
                    thickness: 1,
                    color: Colors.grey[300],
                  ),
                ),
                _buildStatColumn(context, '${profile.followingCount}', 'Following'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatColumn(BuildContext context, String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}