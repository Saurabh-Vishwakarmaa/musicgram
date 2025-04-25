import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/screens/profile_edit_screen.dart';
import 'package:musicgram4/services/chat_service.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:musicgram4/social/models/activity.dart';
import 'package:musicgram4/social/screens/chat_screen.dart';
import 'package:musicgram4/social/screens/paired_listening.dart';
import 'package:musicgram4/social/screens/friend_finder.dart';
import 'package:musicgram4/services/appwrite_service.dart'; // Assuming we have this service
import 'package:timeago/timeago.dart' as timeago;
 // Ensure this file contains the ProfileEditScreen class

// If the class is not defined, define it here as a placeholder or implement it in the correct file.
class PairedListeningScreen extends StatelessWidget {
  final String guestUserId;
  final String guestUsername;

  const PairedListeningScreen({
    Key? key,
    required this.guestUserId,
    required this.guestUsername,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Paired Listening')),
      body: Center(
        child: Text('Listening with $guestUsername'),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final String? userId; // Optional - if null, show current user's profile

  const ProfilePage({Key? key, this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final SocialDatabaseService _socialService;
  
  UserProfile? _userProfile;
  List<Activity> _recentActivities = [];
  bool _isLoading = true;
  bool _isCurrentUser = false;
  bool _isFollowing = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Check if AppwriteService is initialized
    _initializeServices().then((_) {
      _loadUserProfile();
    });
  }

  Future<void> _initializeServices() async {
    // Check if services are initialized
    if (!AppwriteService.isInitialized) {
      try {
        await AppwriteService.initialize();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing services: $e'))
          );
        }
      }
    }
    
    // Now initialize the social service
    _socialService = SocialDatabaseService(
      databases: AppwriteService.databases,
      storage: AppwriteService.storage,
      account: AppwriteService.account,
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('Starting to load profile...');
      
      // Determine if this is the current user's profile
      final currentUserId = AppwriteService.currentUserId;
      print('Current user ID: $currentUserId');
      
      final profileId = widget.userId ?? currentUserId;
      print('Loading profile for user ID: $profileId');
      
      _isCurrentUser = profileId == currentUserId;
      
      // Try to get the profile, create it if it doesn't exist
      try {
        print('About to call getUserProfile...');
        final profileDoc = await _socialService.getUserProfile(profileId!);
        print('getUserProfile succeeded');
        _userProfile = UserProfile.fromDocument(profileDoc);
      } catch (e) {
        if (e.toString().contains('document_not_found') && _isCurrentUser) {
          // Create a profile for the current user
          print('Profile not found, creating one...');
          final newProfileDoc = await _socialService.createUserProfile(
            userId: profileId!,
            username: 'user_${profileId!.substring(0, 6)}', // Generate a username
            displayName: 'New User', // Default name
          );
          _userProfile = UserProfile.fromDocument(newProfileDoc);
        } else {
          rethrow; // Re-throw if not a document_not_found error or not current user
        }
      }
      
      // Check if current user is following this profile
      if (!_isCurrentUser && currentUserId != null) {
        final following = await _socialService.getFollowing(currentUserId);
        _isFollowing = following.any((doc) => doc.data['followee_id'] == profileId);
      }
      
      // Load recent activities
      // You'll need to implement this method in SocialDatabaseService
      final activities = await _socialService.getUserActivities(profileId);
      _recentActivities = activities.map((doc) => Activity.fromDocument(doc)).toList();
      
    } catch (e) {
      print('Error in _loadUserProfile: $e');
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
    if (_userProfile == null) return;
    
    final currentUserId = AppwriteService.currentUserId;
    if (currentUserId == null) {
      // Prompt user to sign in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to follow users'))
      );
      return;
    }
    
    setState(() {
      // Show loading and optimistically update UI for better user experience
      _isFollowing = !_isFollowing;
      
      // Optimistically update counts in UI
      if (_isFollowing) {
        _userProfile = _userProfile!.copyWith(
          followersCount: _userProfile!.followersCount + 1
        );
      } else {
        _userProfile = _userProfile!.copyWith(
          followersCount: _userProfile!.followersCount - 1
        );
      }
    });
    
    try {
      if (!_isFollowing) {
        // We already toggled the state, so we need to check the inverted condition
        await _socialService.unfollowUser(
          followerId: currentUserId,
          followeeId: _userProfile!.userId,
        );
        print('Unfollowed user');
      } else {
        await _socialService.followUser(
          followerId: currentUserId,
          followeeId: _userProfile!.userId,
        );
        print('Followed user');
      }
      
      // Fully refresh profile to get accurate counts from server
      await _loadUserProfile();
      
    } catch (e) {
      print('Error toggling follow status: $e');
      // Revert optimistic update on error
      setState(() {
        _isFollowing = !_isFollowing;
        
        // Revert optimistic count update
        if (_isFollowing) {
          _userProfile = _userProfile!.copyWith(
            followersCount: _userProfile!.followersCount + 1
          );
        } else {
          _userProfile = _userProfile!.copyWith(
            followersCount: _userProfile!.followersCount - 1
          );
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'))
      );
    }
  }
  
  void _navigateToPairedListening() {
    if (_userProfile == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PairedListeningScreen(
          guestUserId: _userProfile!.userId,
          guestUsername: _userProfile!.displayName,
        ),
      ),
    );
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(
          userProfile: _userProfile!,
          socialService: _socialService,
        ),
      ),
    );
    
    // If profile was updated, refresh the profile data
    if (result == true) {
      _loadUserProfile();
    }
  }
  
  void _startChat() async {
    if (AppwriteService.currentUserId == null || _userProfile == null) return;
    
    try {
      final chatService = ChatService(
        databases: AppwriteService.databases,
        realtime: Realtime(AppwriteService.client),
        account: AppwriteService.account,
      );
      
      // Get current user profile for the name
      final currentUserProfile = await _socialService.getUserProfile(AppwriteService.currentUserId!);
      
      final conversation = await chatService.getOrCreateConversation(
        AppwriteService.currentUserId!,
        _userProfile!.userId,
        user1Name: UserProfile.fromDocument(currentUserProfile).displayName,
        user2Name: _userProfile!.displayName,
        // No extra parameters here
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversation.$id,
            otherUserId: _userProfile!.userId,
            otherUserName: _userProfile!.displayName,
          ),
        ),
      );
    } catch (e) {
      print('Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start conversation')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }
    
    if (_userProfile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Profile not found', style: TextStyle(color: Colors.white))),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Section with Premium Banner
              Stack(
                children: [
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade900, Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _userProfile!.avatarFileId != null
                            ? NetworkImage(_getAvatarUrl(_userProfile!.avatarFileId!))
                            : null,
                          backgroundColor: const Color.fromARGB(255, 212, 212, 212),
                          child: _userProfile!.avatarFileId == null
                            ? Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userProfile!.displayName,
                                style: GoogleFonts.firaSansCondensed(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${_userProfile!.username}',
                                style: GoogleFonts.firaSansCondensed(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Social Actions - Follow/Unfollow or Edit Profile
                  Positioned(
                    top: 180,
                    right: 20,
                    child: _isCurrentUser
                      ? ElevatedButton.icon(
                          icon: Icon(Icons.edit),
                          label: Text('Edit Profile'),
                          onPressed: _navigateToEditProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                              label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                              onPressed: _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? Colors.grey[800] : Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            if (!_isCurrentUser) SizedBox(width: 8),
                            if (!_isCurrentUser)
                              ElevatedButton.icon(
                                icon: Icon(Icons.headset),
                                label: Text('Listen Together'),
                                onPressed: _navigateToPairedListening,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                          ],
                        ),
                  ),
                  
                  // Premium Badge (if applicable)
                  // This would be based on your user data
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.shade600,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.black, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            'Premium',
                            style: GoogleFonts.firaSansCondensed(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Stats Section with 3D Card Effect - Real Follow Data
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stats',
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 20,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            // Navigate to followers list
                          },
                          child: _build3DStatCard('Followers', _userProfile!.followersCount.toString()),
                        ),
                        InkWell(
                          onTap: () {
                            // Navigate to following list
                          },
                          child: _build3DStatCard('Following', _userProfile!.followingCount.toString()),
                        ),
                        _build3DStatCard('Playlists', '23'), // You'd replace this with real data
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tab Bar for different profile sections
              Container(
                color: Colors.black,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.greenAccent,
                  tabs: [
                    Tab(text: 'Activity'),
                    Tab(text: 'Top Artists'),
                    Tab(text: 'Paired Sessions'),
                  ],
                  labelStyle: GoogleFonts.firaSansCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: GoogleFonts.firaSansCondensed(
                    fontSize: 16,
                  ),
                ),
              ),
              
              // Tab Content
              Container(
                height: 400, // Fixed height for tab content
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Activity Tab
                    _buildActivityTab(),
                    // Top Artists Tab
                    _buildArtistsTab(),
                    // Paired Sessions Tab
                    _buildPairedSessionsTab(),
                  ],
                ),
              ),

              // Future Features Section
              const SizedBox(height: 20),
              _buildFutureFeatureSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_recentActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: GoogleFonts.firaSansCondensed(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        final activity = _recentActivities[index];
        return _buildActivityItem(activity);
      },
    );
  }

  Widget _buildActivityItem(Activity activity) {
    IconData icon;
    String description;
    
    switch (activity.activityType) {
      case 'listen':
        icon = Icons.headphones;
        description = 'Listened to ${activity.metadata['song_name'] ?? 'a song'}';
        break;
      case 'follow':
        icon = Icons.person_add;
        description = 'Started following ${activity.metadata['target_name'] ?? 'someone'}';
        break;
      case 'paired_listen':
        icon = Icons.people;
        description = 'Listened with ${activity.metadata['partner_name'] ?? 'a friend'}';
        break;
      default:
        icon = Icons.music_note;
        description = 'Did something on MusicGram';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade800,
            blurRadius: 8,
            offset: Offset(-4, -4),
          ),
          BoxShadow(
            color: Colors.grey.shade700,
            blurRadius: 8,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Colors.greenAccent),
        title: Text(
          description,
          style: GoogleFonts.firaSansCondensed(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          timeago.format(activity.createdAt),
          style: GoogleFonts.firaSansCondensed(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildArtistsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6, // Replace with actual artist count
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade900, Colors.greenAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: Offset(5, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Artist $index',
                style: GoogleFonts.firaSansCondensed(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPairedSessionsTab() {
    // This would show history of paired listening sessions
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No paired sessions yet',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.person_add),
            label: Text('Find Friends'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FriendFinder()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DStatCard(String label, String value) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade800,
            blurRadius: 15,
            offset: Offset(-4, -4),
          ),
          BoxShadow(
            color: Colors.grey.shade700,
            blurRadius: 15,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 18,
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalArtistList() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade900, Colors.greenAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: Offset(5, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Artist $index',
                style: GoogleFonts.firaSansCondensed(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFutureFeatureSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple, Colors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.5),
              blurRadius: 10,
              offset: Offset(5, 5),
            ),
          ],
        ),
        child: Text(
          'Coming Soon: Premium Features like ad-free listening and high-quality streaming!',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _getAvatarUrl(String fileId) {
    // Use the helper method from AppwriteService
    return AppwriteService.getFilePreview(fileId);
  }
}