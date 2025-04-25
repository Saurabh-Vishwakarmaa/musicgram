import 'package:flutter/material.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/social/models/activity.dart';
import 'package:musicgram4/social/widgets/activity_item.dart';

class SocialFeed extends StatefulWidget {
  const SocialFeed({Key? key}) : super(key: key);

  @override
  State<SocialFeed> createState() => _SocialFeedState();
}

class _SocialFeedState extends State<SocialFeed> {
  final SocialDatabaseService _socialService = SocialDatabaseService(
    databases: databases /* provide your database instance */,
    storage: storage /* provide your storage instance */,
    account: account /* provide your account instance */,
  );
  
  List<Activity> _activities = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadFeed();
  }
  
  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user ID
      String currentUserId = "6801f2b2cff98e72c5bd"  /* get current user ID */;
      
      // Get list of users the current user follows
      final following = await _socialService.getFollowing(currentUserId);
      List<String> followingIds = following.map((doc) => doc.data['followee_id'] as String).toList();
      
      // Add current user ID to show their activities too
      followingIds.add(currentUserId);
      
      // Fetch activities from these users
      // You'll need to implement getActivitiesForUsers in SocialDatabaseService
      // final activitiesResult = await _socialService.getActivitiesForUsers(followingIds);
      // _activities = activitiesResult.documents.map((doc) => Activity.fromDocument(doc)).toList();
      
      // Sort by most recent
      _activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading feed: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Music Feed'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFeed,
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : _activities.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No activity yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Follow more users or start listening!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFeed,
              child: ListView.builder(
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  return ActivityItem(activity: _activities[index]);
                },
              ),
            ),
    );
  }
}