import 'package:flutter/material.dart';
import 'package:appwrite/models.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/models/user.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:musicgram4/social/widgets/profile_card.dart';
import 'package:musicgram4/social/widgets/activity_item.dart';
import 'package:musicgram4/social/models/activity.dart';

class ProfileView extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileView({
    Key? key,
    required this.userId,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SocialDatabaseService _socialService;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isFollowing = false;
  List<Activity> _recentActivities = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _socialService = SocialDatabaseService(
      databases:databases /* provide your database instance */,
      storage:storage /* provide your storage instance */,
      account: account /* provide your account instance */,
    );
    _loadProfile();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load the user profile
      final profileDoc = await _socialService.getUserProfile(widget.userId);
      _userProfile = UserProfile.fromDocument(profileDoc);
      
      // Check if the current user is following this profile
      if (!widget.isCurrentUser) {
        // Assuming you have a way to get the current user's ID
        String currentUserId = "6801f2b2cff98e72c5bd" /* get current user ID */;
        
        final connections = await _socialService.getFollowing(currentUserId);
        _isFollowing = connections.any((doc) => doc.data['followee_id'] == widget.userId);
      }
      
      // Load recent activities
      // This would require implementing a getActivities method in SocialDatabaseService
      // final activitiesResult = await _socialService.getUserActivities(widget.userId);
      // _recentActivities = activitiesResult.documents.map((doc) => Activity.fromDocument(doc)).toList();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleFollow() async {
    if (_isFollowing) {
      // Unfollow the user
      String currentUserId = "6801f2b2cff98e72c5bd"/* get current user ID */;
      await _socialService.unfollowUser(
        followerId: currentUserId,
        followeeId: widget.userId,
      );
    } else {
      // Follow the user
      String currentUserId = "6801f2b2cff98e72c5bd"/* get current user ID */;
      await _socialService.followUser(
        followerId: currentUserId,
        followeeId: widget.userId,
      );
    }
    
    // Refresh the profile to update follower count
    await _loadProfile();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userProfile?.displayName ?? 'Profile'),
        actions: [
          if (widget.isCurrentUser)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                // Navigate to profile edit screen
              },
            ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : _userProfile == null
          ? Center(child: Text('Profile not found'))
          : Column(
              children: [
                // Profile card
                ProfileCard(profile: _userProfile!),
                
                // Follow button if not current user
                if (!widget.isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                      label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                      onPressed: _toggleFollow,
                    ),
                  ),
                
                // Tab bar
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'Activity'),
                    Tab(text: 'Liked Songs'),
                    Tab(text: 'Paired Sessions'),
                  ],
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Activity tab
                      _buildActivityTab(),
                      
                      // Liked songs tab
                      _buildLikedSongsTab(),
                      
                      // Paired sessions tab
                      _buildPairedSessionsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildActivityTab() {
    if (_recentActivities.isEmpty) {
      return Center(child: Text('No recent activity'));
    }
    
    return ListView.builder(
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        return ActivityItem(activity: _recentActivities[index]);
      },
    );
  }
  
  Widget _buildLikedSongsTab() {
    // Implement liked songs display
    return Center(child: Text('Liked songs will appear here'));
  }
  
  Widget _buildPairedSessionsTab() {
    // Implement paired sessions history
    return Center(child: Text('Paired listening history will appear here'));
  }
}