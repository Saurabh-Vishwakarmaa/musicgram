import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/screens/profile2.dart' hide PairedListeningScreen;
import 'package:musicgram4/screens/user_browser_page.dart';
import 'package:musicgram4/services/appwrite_service.dart';
import 'package:musicgram4/services/chat_service.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:musicgram4/social/screens/conversations_list.dart';
import 'package:musicgram4/social/screens/friend_finder.dart';
import 'package:musicgram4/social/screens/paired_listening.dart';
import 'package:musicgram4/social/widgets/activity_item.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:timeago/timeago.dart' as timeago;

class SocialHub extends StatefulWidget {
  const SocialHub({Key? key}) : super(key: key);

  @override
  State<SocialHub> createState() => _SocialHubState();
}

class _SocialHubState extends State<SocialHub> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SocialDatabaseService _socialService;
  String? _currentUserId;
  bool _isLoading = true;
  int _unreadMessageCount = 0;
  
  // Data for different tabs
  List<Document> _activityFeed = [];
  List<Document> _notifications = [];
  List<Document> _trendingSongs = [];
  List<UserProfile> _recommendedFriends = [];
  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoadingUsers = false;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize the social service
    _socialService = SocialDatabaseService(
      databases: databases,
      storage: storage,
      account: account
    );
    
    _loadSocialData();
    
    // Add this line to load users when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllUsers();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSocialData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user ID - replace with your actual method
      _currentUserId = (await account.get()).$id;
      
      if (_currentUserId != null) {
        // Load activity feed from followed users
        final following = await _socialService.getFollowing(_currentUserId!);
        List<String> followedUserIds = following.map((doc) => doc.data['followee_id'] as String).toList();
        
        // Add sample activities for now (implement properly with actual data)
        _activityFeed = [];
        _notifications = [];
        _trendingSongs = [];
        
        // Sample recommended friends
        final randomUsers = await _socialService.searchUsers("");
        _recommendedFriends = randomUsers
            .where((doc) => doc.data['user_id'] != _currentUserId)
            .map((doc) => UserProfile.fromDocument(doc))
            .take(5)
            .toList();
      }
    } catch (e) {
      print('Error loading social data: $e');
      // Show error message
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkUnreadMessages() async {
    if (_currentUserId == null) return;
    
    try {
      final chatService = ChatService(
        databases: AppwriteService.databases,
        realtime: Realtime(AppwriteService.client),
        account: AppwriteService.account,
      );
      
      final count = await chatService.getUnreadMessageCount(_currentUserId!);
      
      setState(() {
        _unreadMessageCount = count;
      });
    } catch (e) {
      print('Error checking unread messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Social Hub',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.greenAccent,
          tabs: [
            Tab(text: 'Feed'),
            Tab(text: 'Discover'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Messages'),
                  if (_unreadMessageCount > 0)
                    Container(
                      margin: EdgeInsets.only(left: 4),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadMessageCount.toString(),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          labelStyle: GoogleFonts.firaSansCondensed(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.greenAccent),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => FriendFinder()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.greenAccent),
            onPressed: () {
              // Show notifications
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFeedTab(),
                _buildDiscoverTab(),
                _buildMessagesTab(),
              ],
            ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Add new post/share music
      //     _showShareMusicSheet();
      //   },
      //   backgroundColor: Colors.purple,
      //   child: Icon(Icons.music_note),
      // ),
    );
  }
  
  Widget _buildFeedTab() {
    if (_activityFeed.isEmpty) {
      return _buildEmptyState(
        icon: Icons.feed,
        title: 'Your Feed is Empty',
        subtitle: 'Follow friends to see their activity here',
        buttonText: 'Find Friends',
        onButtonPressed: () {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => FriendFinder()),
          );
        },
      );
    }
    
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Mock activity feed with sample data
        _buildActivityCard(
          username: 'music_lover',
          action: 'listened to',
          target: 'Blinding Lights - The Weeknd',
          timeAgo: '2h',
          iconData: Icons.headphones,
          iconColor: Colors.deepPurple,
        ),
        _buildActivityCard(
          username: 'beat_master',
          action: 'created playlist',
          target: 'Summer Vibes 2025',
          timeAgo: '6h',
          iconData: Icons.playlist_add,
          iconColor: Colors.blue,
        ),
        _buildActivityCard(
          username: 'rock_star',
          action: 'shared',
          target: 'New Imagine Dragons Album',
          timeAgo: '1d',
          iconData: Icons.share,
          iconColor: Colors.amber,
        ),
        _buildActivityCard(
          username: 'dj_cool',
          action: 'is listening with',
          target: 'classic_fan',
          timeAgo: '3m',
          iconData: Icons.people,
          iconColor: Colors.green,
        ),
      ],
    );
  }
  
  Widget _buildDiscoverTab() {
  return RefreshIndicator(
    onRefresh: _loadSocialData,
    color: Colors.greenAccent,
    child: ListView(
      children: [
        // Featured Banner
        Container(
          height: 100,
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade800, Colors.deepPurple.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.5),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcOver,
                    child: Image.asset(
                      'assets/images/discover_banner.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Discover Music Together',
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Connect with friends and find new music',
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // People You Might Like section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Find Friends',
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadAllUsers,
                    child: Text(
                      'Refresh',
                      style: GoogleFonts.firaSansCondensed(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  onChanged: _filterUsers,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name or username...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              // User List
              Container(
                height: 350, // Taller list to show more users
                child: _isLoadingUsers
                  ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                  : _filteredUsers.isEmpty
                      ? _buildEmptyUserList()
                      : ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _buildUserListItem(user);
                          },
                        ),
              ),
            ],
          ),
        ),

        // Browse All Users Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _navigateToUserBrowser,
            icon: Icon(Icons.people),
            label: Text(
              'Browse All Users',
              style: GoogleFonts.firaSansCondensed(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
              shadowColor: Colors.purple.withOpacity(0.5),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Trending Section
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trending Music',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
              SizedBox(height: 12),
              _buildTrendingMusicCards(),
            ],
          ),
        ),
        
        // Social Activity Feed Preview
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
              SizedBox(height: 12),
              _buildRecentActivityPreview(),
            ],
          ),
        ),
        
        // Extra space at bottom
        SizedBox(height: 20),
      ],
    ),
  );
}

// Add these new helper methods to your class:

Widget _buildEmptyRecommendations() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people_outline, size: 40, color: Colors.grey[600]),
        SizedBox(height: 12),
        Text(
          'No recommendations yet',
          style: GoogleFonts.firaSansCondensed(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _refreshRecommendedUsers,
          child: Text('Find People'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildRecommendedUserCard(UserProfile user) {
  return Container(
    width: 150,
    margin: EdgeInsets.only(right: 12),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      border: Border.all(
        color: Colors.grey[800]!,
        width: 1,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with gradient
          Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade900, Colors.greenAccent.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[800],
                backgroundImage: user.avatarFileId != null
                  ? NetworkImage(AppwriteService.getFilePreview(user.avatarFileId!))
                  : null,
                child: user.avatarFileId == null
                  ? Icon(Icons.person, color: Colors.white, size: 30)
                  : null,
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.displayName,
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Listen Together button
          InkWell(
            onTap: () => _startPairedListeningWithUser(user),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.headphones, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Listen Together',
                    style: GoogleFonts.firaSansCondensed(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8), // Add space between this and Follow button
          
          // Follow button
          InkWell(
            onTap: () => _followUser(user),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(
                  'Follow',
                  style: GoogleFonts.firaSansCondensed(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTrendingMusicCards() {
  // Sample trending songs - replace with real data
  final trendingSongs = [
    {'title': 'Blinding Lights', 'artist': 'The Weeknd', 'listens': '1.2M'},
    {'title': 'Dynamite', 'artist': 'BTS', 'listens': '892K'},
    {'title': 'Bad Habits', 'artist': 'Ed Sheeran', 'listens': '754K'},
    {'title': 'Stay', 'artist': 'Kid Laroi & Justin Bieber', 'listens': '623K'},
  ];
  
  return Container(
    height: 180,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: trendingSongs.length,
      itemBuilder: (context, index) {
        final song = trendingSongs[index];
        return Container(
          width: 150,
          margin: EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Song image placeholder
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade900,
                      Colors.blue.shade900,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(child: Icon(Icons.music_note, color: Colors.white, size: 40)),
              ),
              
              // Song
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildRecentActivityPreview() {
  // Sample recent activities - replace with real data
  final recentActivities = [
    {'username': 'music_lover', 'action': 'listened to', 'target': 'Blinding Lights - The Weeknd', 'timeAgo': '2h'},
    {'username': 'beat_master', 'action': 'created playlist', 'target': 'Summer Vibes 2025', 'timeAgo': '6h'},
    {'username': 'rock_star', 'action': 'shared', 'target': 'New Imagine Dragons Album', 'timeAgo': '1d'},
    {'username': 'dj_cool', 'action': 'is listening with', 'target': 'classic_fan', 'timeAgo': '3m'},
  ];
  
  return Column(
    children: recentActivities.map((activity) {
      return _buildActivityCard(
        username: activity['username']!,
        action: activity['action']!,
        target: activity['target']!,
        timeAgo: activity['timeAgo']!,
        iconData: Icons.music_note,
        iconColor: Colors.greenAccent,
      );
    }).toList(),
  );
}

Widget _buildMessagesTab() {
  return ConversationsList();
}
  
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[700]),
          SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.firaSansCondensed(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: onButtonPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityCard({
    required String username,
    required String action,
    required String target,
    required String timeAgo,
    required IconData iconData,
    required Color iconColor,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: iconColor.withOpacity(0.2),
              child: Icon(iconData, color: iconColor),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: username,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' $action '),
                        TextSpan(
                          text: target,
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    timeAgo,
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  // Add like/comment buttons
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.favorite_border,
                        label: 'Like',
                        onPressed: () {},
                      ),
                      SizedBox(width: 16),
                      _buildActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Comment',
                        onPressed: () {},
                      ),
                      SizedBox(width: 16),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Share',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.firaSansCondensed(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.greenAccent,
      ),
    );
  }
  
  Widget _buildTrendingMusic() {
    return Container(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 150,
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[900]!, Colors.purple[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 10,
                  offset: Offset(5, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: 0.6,
                      child: Image.network(
                        'https://picsum.photos/150/200?random=$index',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Trending Song ${index + 1}',
                        style: GoogleFonts.firaSansCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Artist Name',
                        style: GoogleFonts.firaSansCondensed(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.headphones, size: 14, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            '${(index + 1) * 125}K',
                            style: GoogleFonts.firaSansCondensed(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildRecommendedFriends() {
  if (_recommendedFriends.isEmpty) {
    return Container(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No recommendations yet',
              style: GoogleFonts.firaSansCondensed(color: Colors.grey),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _refreshRecommendedUsers(),
              child: Text('Find People'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  return Container(
    height: 120,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _recommendedFriends.length,
      itemBuilder: (context, index) {
        final user = _recommendedFriends[index];
        
        return GestureDetector(
          onTap: () => _viewUserProfile(user),
          child: Container(
            width: 120,
            margin: EdgeInsets.only(right: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.green[900],
                  backgroundImage: user.avatarFileId != null
                    ? NetworkImage(_getAvatarUrl(user.avatarFileId!))
                    : null,
                  child: user.avatarFileId == null
                    ? Icon(Icons.person, color: Colors.white)
                    : null,
                ),
                SizedBox(height: 8),
                Text(
                  user.displayName,
                  style: GoogleFonts.firaSansCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _followUser(user),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Follow',
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  
  Widget _buildFeaturedPlaylists() {
    return Container(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.blue[900]!,
                  Colors.blue[700]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: 0.4,
                      child: Image.network(
                        'https://picsum.photos/160/180?random=${index + 20}',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.playlist_play, size: 36, color: Colors.white),
                      Spacer(),
                      Text(
                        'Playlist ${index + 1}',
                        style: GoogleFonts.firaSansCondensed(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${10 + index} songs',
                        style: GoogleFonts.firaSansCondensed(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _showShareMusicSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share Music',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              _buildShareOption(
                icon: Icons.music_note,
                title: 'Share Current Song',
                subtitle: 'Let friends know what you\'re listening to',
                onTap: () {
                  Navigator.pop(context);
                  // Implement sharing current song
                },
              ),
              Divider(color: Colors.grey[800]),
              _buildShareOption(
                icon: Icons.playlist_add,
                title: 'Share a Playlist',
                subtitle: 'Share one of your playlists with friends',
                onTap: () {
                  Navigator.pop(context);
                  // Implement sharing playlist
                },
              ),
              Divider(color: Colors.grey[800]),
              _buildShareOption(
                icon: Icons.people,
                title: 'Start Paired Listening',
                subtitle: 'Listen to music together in real-time',
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to paired listening screen to create a new session
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PairedListeningScreen(
                        // Pass no parameters to create an open session
                      ),
                    ),
                  ).then((_) => _loadSocialData());
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.purple.withOpacity(0.2),
              child: Icon(icon, color: Colors.greenAccent),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _navigateToUserBrowser() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserBrowserPage(
          socialService: _socialService,
          currentUserId: _currentUserId,
        ),
      ),
    );
  }

  void _viewUserProfile(UserProfile user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: user.userId),
      ),
    ).then((_) => _loadSocialData()); // Reload data when returning
  }

  Future<void> _followUser(UserProfile user) async {
    if (_currentUserId == null) return;
    
    try {
      await _socialService.followUser(
        followerId: _currentUserId!,
        followeeId: user.userId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Following ${user.displayName}')),
      );
      
      // Refresh data
      _loadSocialData();
    } catch (e) {
      print('Error following user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to follow user: $e')),
      );
    }
  }

  Future<void> _refreshRecommendedUsers() async {
  if (_currentUserId == null) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Get all users instead of searching
    final queryResults = await _socialService.listDocuments(
      collectionId: AppConfig.userProfilesCollection,
      queries: [
        Query.limit(50), // Get a reasonable batch
        Query.notEqual('user_id', _currentUserId!), // Exclude current user
      ],
    );
    
    // Convert to UserProfile objects
    final allUsers = queryResults.documents
        .map((doc) => UserProfile.fromDocument(doc))
        .toList();
    
    // Shuffle the list to get random users
    allUsers.shuffle();
    
    // Take the first 5 (or fewer if less available)
    _recommendedFriends = allUsers.take(5).toList();
    
  } catch (e) {
    print('Error refreshing recommended users: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not load friend recommendations')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  String _getAvatarUrl(String fileId) {
    // Replace with your actual implementation - this is just a placeholder
    // If your AppwriteService has getFilePreview method, use that instead
    return 'https://cloud.appwrite.io/v1/storage/buckets/profile_pictures/files/$fileId/view?project=${AppConfig.projectId}';
  }

  void _startPairedListening(UserProfile? targetUser) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PairedListeningScreen(
        guestUserId: targetUser?.userId,
        guestUsername: targetUser?.displayName,
      ),
    ),
  ).then((_) => _loadSocialData()); // Refresh data when returning
}

void _startPairedListeningWithUser(UserProfile user) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PairedListeningScreen(
        guestUserId: user.userId,
        guestUsername: user.displayName,
      ),
    ),
  ).then((_) => _loadSocialData());
}

Future<void> _loadAllUsers() async {
  if (_currentUserId == null) return;
  
  setState(() {
    _isLoadingUsers = true;
  });
  
  try {
    // Get all users except current user
    final queryResults = await AppwriteService.databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.userProfilesCollection,
      queries: [
        Query.limit(100), // Limit to 100 users for performance
        Query.notEqual('user_id', _currentUserId!), // Exclude current user
      ],
    );
    
    // Convert to UserProfile objects
    setState(() {
      _allUsers = queryResults.documents
          .map((doc) => UserProfile.fromDocument(doc))
          .toList();
      
      // Sort alphabetically by display name
      _allUsers.sort((a, b) => a.displayName.compareTo(b.displayName));
      
      // Initialize filtered users with all users
      _filteredUsers = List.from(_allUsers);
      _isLoadingUsers = false;
    });
    
  } catch (e) {
    print('Error loading users: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not load users: $e')),
    );
    setState(() {
      _isLoadingUsers = false;
    });
  }
}

void _filterUsers(String query) {
  setState(() {
    _searchQuery = query.toLowerCase();
    
    if (_searchQuery.isEmpty) {
      _filteredUsers = List.from(_allUsers);
    } else {
      _filteredUsers = _allUsers
          .where((user) => 
              user.displayName.toLowerCase().contains(_searchQuery) ||
              user.username.toLowerCase().contains(_searchQuery))
          .toList();
    }
  });
}

Widget _buildEmptyUserList() {
  if (_searchQuery.isNotEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            'No users found matching "$_searchQuery"',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 16,
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
        SizedBox(height: 16),
        Text(
          'No users found',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 16,
            color: Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadAllUsers,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
          ),
          child: Text('Refresh'),
        ),
      ],
    ),
  );
}

Widget _buildUserListItem(UserProfile user) {
  bool isAlreadyFollowing = false; // Implement logic to check if user is already followed
  
  return Card(
    margin: EdgeInsets.only(bottom: 12),
    color: Colors.grey[850],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      onTap: () => _viewUserProfile(user),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[800],
              backgroundImage: user.avatarFileId != null
                ? NetworkImage(AppwriteService.getFilePreview(user.avatarFileId!))
                : null,
              child: user.avatarFileId == null
                ? Icon(Icons.person, color: Colors.white, size: 30)
                : null,
            ),
            
            SizedBox(width: 16),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Row(
              children: [
                // Listen Together button
                IconButton(
                  icon: Icon(Icons.headphones, color: Colors.purple),
                  tooltip: 'Listen Together',
                  onPressed: () => _startPairedListeningWithUser(user),
                ),
                
                // Follow/Unfollow button
                ElevatedButton(
                  onPressed: () => _followUser(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAlreadyFollowing ? Colors.grey[700] : Colors.greenAccent,
                    foregroundColor: isAlreadyFollowing ? Colors.white : Colors.black,
                    minimumSize: Size(90, 36),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isAlreadyFollowing ? 'Following' : 'Follow',
                    style: GoogleFonts.firaSansCondensed(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

}

Future<List<UserProfile>> getAllUsers({int limit = 20, int offset = 0}) async {
  try {
    final result = await AppwriteService.databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.userProfilesCollection, // Using your const value
      queries: [
        Query.limit(limit),
        Query.offset(offset),
        Query.orderDesc('created_at'),
      ],
    );
    
    return result.documents.map((doc) => UserProfile.fromDocument(doc)).toList();
  } catch (e) {
    print('Error fetching users: $e');
    return [];
  }
}

// Replace the searchUsers function with this implementation

Future<List<UserProfile>> searchUsers(String query) async {
  try {
    // Get all users (limited to 100 for performance)
    final result = await AppwriteService.databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.userProfilesCollection,
      queries: [Query.limit(100)],
    );
    
    if (query.isEmpty) {
      // If no search query, return all users
      return result.documents
          .map((doc) => UserProfile.fromDocument(doc))
          .toList();
    }
    
    // Filter users client-side based on the query
    final lowercaseQuery = query.toLowerCase();
    return result.documents
        .map((doc) => UserProfile.fromDocument(doc))
        .where((profile) => 
            profile.username.toLowerCase().contains(lowercaseQuery) ||
            profile.displayName.toLowerCase().contains(lowercaseQuery))
        .toList();
  } catch (e) {
    print('Error searching users: $e');
    return [];
  }
}

Future<List<UserProfile>> getRandomUsersToFollow(String currentUserId, int limit) async {
  try {
    // First get all users except current user
    final result = await AppwriteService.databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.userProfilesCollection,
      queries: [
        Query.notEqual('user_id', currentUserId),
        Query.limit(100),
      ],
    );
    
    // Convert to profiles
    final profiles = result.documents.map((doc) => UserProfile.fromDocument(doc)).toList();
    
    // Randomize the list
    profiles.shuffle();
    
    // Return limited number
    return profiles.take(limit).toList();
  } catch (e) {
    print('Error getting random users: $e');
    return [];
  }
}

Widget buildUserGrid(List<UserProfile> users) {
  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.8,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
    ),
    itemCount: users.length,
    padding: EdgeInsets.all(16),
    itemBuilder: (context, index) {
      final user = users[index];
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(userId: user.userId),
          ),
        ),
        child: Card(
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[800],
                backgroundImage: user.avatarFileId != null
                  ? NetworkImage(AppwriteService.getFilePreview(user.avatarFileId!))
                  : null,
                child: user.avatarFileId == null
                  ? Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
              ),
              SizedBox(height: 8),
              Text(
                user.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                '@${user.username}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () {
                  // Follow user action here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Follow'),
              ),
              SizedBox(height: 5),
            ],
          ),
        ),
      );
    },
  );
}