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
import 'package:musicgram4/services/appwrite_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
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
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
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
    if (_userProfile == null) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
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
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    try {
      final chatService = ChatService(
        databases: AppwriteService.databases,
        realtime: Realtime(AppwriteService.client),
        account: AppwriteService.account,
        storage: AppwriteService.storage,
      );
      
      // Get current user profile for the name
      final currentUserProfile = await _socialService.getUserProfile(AppwriteService.currentUserId!);
      
      final conversation = await chatService.getOrCreateConversation(
        AppwriteService.currentUserId!,
        _userProfile!.userId,
        user1Name: UserProfile.fromDocument(currentUserProfile).displayName,
        user2Name: _userProfile!.displayName,
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Loading profile...',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_userProfile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text(
                'Profile not found',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text('Go Back', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Color(0xFF121212), // Dark background
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          // Custom app bar with profile header
          SliverAppBar(
            expandedHeight: 320,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Color(0xFF121212),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProfileHeader(),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(48),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Color(0xFF121212),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.greenAccent.withOpacity(0.2),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorColor: Colors.transparent,
                  labelColor: Colors.greenAccent,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 16),
                          SizedBox(width: 4),
                          Text('Activity', style: GoogleFonts.poppins(fontSize: 12)),
                        ],
                      ),
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, size: 16),
                          SizedBox(width: 4),
                          Text('Artists', style: GoogleFonts.poppins(fontSize: 12)),
                        ],
                      ),
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headphones, size: 16),
                          SizedBox(width: 4),
                          Text('Sessions', style: GoogleFonts.poppins(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Stats summary
          SliverToBoxAdapter(
            child: _buildStatsSection(),
          ),
          
          // Tab content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActivityTab(),
                _buildArtistsTab(),
                _buildPairedSessionsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: !_isCurrentUser ? _buildActionButtons() : null,
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.greenAccent.withOpacity(0.2),
                Color(0xFF121212),
              ],
            ),
          ),
        ),
        
        // Profile content
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Profile avatar with animated border
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.greenAccent,
                          Colors.cyanAccent,
                          Colors.purpleAccent,
                          Colors.greenAccent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF121212),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: _userProfile!.avatarFileId != null
                              ? CachedNetworkImage(
                                  imageUrl: _getAvatarUrl(_userProfile!.avatarFileId!),
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[900],
                                    child: Icon(Icons.person, color: Colors.grey[700], size: 40),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[900],
                                    child: Icon(Icons.error, color: Colors.red[300], size: 40),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[900],
                                  child: Icon(Icons.person, color: Colors.grey[700], size: 40),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 20),
                  
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userProfile!.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '@${_userProfile!.username}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            if (_userProfile!.id!=Null) ...[
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, color: Colors.black, size: 10),
                                    SizedBox(width: 2),
                                    Text(
                                      'PREMIUM',
                                      style: GoogleFonts.poppins(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 10),
                        if (_userProfile!.bio != null && _userProfile!.bio!.isNotEmpty)
                          Text(
                            _userProfile!.bio!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // Profile actions
              if (_isCurrentUser)
                ElevatedButton.icon(
                  onPressed: _navigateToEditProfile,
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Edit Profile', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Back button
        Positioned(
          top: 60,
          left: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: BackButton(color: Colors.white),
          ),
        ),
        
        // Menu button (if current user)
        if (_isCurrentUser)
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  // Show options menu
                  _showOptionsMenu();
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Followers', _userProfile!.followersCount.toString()),
          Container(height: 40, width: 1, color: Colors.grey[800]),
          _buildStatItem('Following', _userProfile!.followingCount.toString()),
          Container(height: 40, width: 1, color: Colors.grey[800]),

        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return GestureDetector(
      onTap: () {
        // Handle tap on stats (e.g., view followers)
        if (label == 'Followers' || label == 'Following') {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label list coming soon'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Message button
        FloatingActionButton.small(
          heroTag: 'messageBtn',
          onPressed: _startChat,
          backgroundColor: Colors.grey[800],
          child: Icon(Icons.message_outlined, color: Colors.white),
          tooltip: 'Message',
        ),
        SizedBox(width: 8),
        
        // Follow/Unfollow button
        FloatingActionButton.extended(
          heroTag: 'followBtn',
          onPressed: _toggleFollow,
          backgroundColor: _isFollowing ? Colors.grey[800] : Colors.greenAccent,
          foregroundColor: _isFollowing ? Colors.white : Colors.black,
          icon: Icon(_isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined, size: 20),
          label: Text(
            _isFollowing ? 'Unfollow' : 'Follow',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(width: 8),
        
        // Listen together button
        FloatingActionButton.small(
          heroTag: 'listenBtn',
          onPressed: _navigateToPairedListening,
          backgroundColor: Colors.purpleAccent,
          child: Icon(Icons.headphones, color: Colors.white),
          tooltip: 'Listen Together',
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    if (_recentActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 48, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _isCurrentUser
                ? 'Start listening to music to create activity'
                : '${_userProfile!.displayName} hasn\'t been active recently',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        final activity = _recentActivities[index];
        return _buildActivityItem(activity);
      },
    );
  }

  Widget _buildActivityItem(Activity activity) {
    IconData icon;
    Color iconColor;
    String description;
    
    switch (activity.activityType) {
      case 'listen':
        icon = Icons.headphones;
        iconColor = Colors.greenAccent;
        description = 'Listened to ${activity.metadata['song_name'] ?? 'a song'}';
        break;
      case 'follow':
        icon = Icons.person_add;
        iconColor = Colors.blueAccent;
        description = 'Started following ${activity.metadata['target_name'] ?? 'someone'}';
        break;
      case 'paired_listen':
        icon = Icons.people;
        iconColor = Colors.purpleAccent;
        description = 'Listened with ${activity.metadata['partner_name'] ?? 'a friend'}';
        break;
      default:
        icon = Icons.music_note;
        iconColor = Colors.orangeAccent;
        description = 'Did something on MusicGram';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Handle activity tap (e.g., open song, profile, etc.)
            HapticFeedback.lightImpact();
          },
          splashColor: iconColor.withOpacity(0.1),
          highlightColor: iconColor.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        timeago.format(activity.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      if (activity.activityType == 'listen' && 
                          activity.metadata['artist_name'] != null) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person, size: 12, color: Colors.white54),
                            SizedBox(width: 4),
                            Text(
                              activity.metadata['artist_name'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtistsTab() {
    // This is a placeholder - you'd populate this with real artist data
    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: 6, // Replace with actual count
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Open artist page
                  HapticFeedback.lightImpact();
                },
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          image: DecorationImage(
                            image: NetworkImage('https://picsum.photos/seed/${index + 10}/300/300'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          'Artist ${index + 1}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPairedSessionsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purpleAccent.withOpacity(0.2), Colors.blueAccent.withOpacity(0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.headset_mic,
              size: 48,
              color: Colors.purpleAccent,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No paired sessions yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Listen to music together with friends in real-time',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32),
          if (_isCurrentUser)
            ElevatedButton.icon(
              icon: Icon(Icons.search, size: 18),
              label: Text('Find Friends', style: GoogleFonts.poppins()),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FriendFinder()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildMenuOption(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to settings
                },
              ),
              _buildMenuOption(
                icon: Icons.share,
                label: 'Share Profile',
                onTap: () {
                  Navigator.pop(context);
                  // Share profile
                },
              ),
              _buildMenuOption(
                icon: Icons.playlist_add,
                label: 'Create New Playlist',
                onTap: () {
                  Navigator.pop(context);
                  // Create playlist
                },
              ),
              _buildMenuOption(
                icon: Icons.star_border,
                label: 'Upgrade to Premium',
                onTap: () {
                  Navigator.pop(context);
                  // Upgrade flow
                },
              ),
              SizedBox(height: 20),
              _buildMenuOption(
                icon: Icons.logout,
                label: 'Log Out',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  // Log out
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.redAccent : Colors.white,
                size: 20,
              ),
              SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDestructive ? Colors.redAccent : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAvatarUrl(String fileId) {
    // Use the helper method from AppwriteService
    return AppwriteService.getFilePreview(fileId);
  }
}