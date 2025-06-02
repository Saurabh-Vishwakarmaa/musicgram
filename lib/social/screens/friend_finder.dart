import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/screens/profile2.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

class FriendFinder extends StatefulWidget {
  const FriendFinder({Key? key}) : super(key: key);

  @override
  State<FriendFinder> createState() => _FriendFinderState();
}

class _FriendFinderState extends State<FriendFinder> {
  final TextEditingController _searchController = TextEditingController();
  final SocialDatabaseService _socialService = SocialDatabaseService(
    databases: databases,
    storage: storage,
    account: account,
  );
  
  bool _isLoading = false;
  List<UserProfile> _searchResults = [];
  List<UserProfile> _suggestedUsers = [];
  String? _currentUserId;
  Map<String, bool> _followingStatus = {};
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadSuggestedUsers();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await account.get();
      _currentUserId = user.$id;
    } catch (e) {
      print('Error getting current user: $e');
    }
  }
  
  Future<void> _loadSuggestedUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get random users to suggest
      final randomUsers = await _socialService.searchUsers("");
      
      // If we have a current user, get their following list
      List<String> followingIds = [];
      if (_currentUserId != null) {
        final following = await _socialService.getFollowing(_currentUserId!);
        followingIds = following.map((doc) => doc.data['followee_id'] as String).toList();
      }
      
      // Convert to user profiles and filter out current user
      final userProfiles = randomUsers
          .where((doc) => doc.data['user_id'] != _currentUserId)
          .map((doc) => UserProfile.fromDocument(doc))
          .toList();
      
      // Update following status for all users
      for (var user in userProfiles) {
        _followingStatus[user.userId] = followingIds.contains(user.userId);
      }
      
      setState(() {
        _suggestedUsers = userProfiles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading suggested users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final results = await _socialService.searchUsers(query);
      
      // If we have a current user, get their following list
      List<String> followingIds = [];
      if (_currentUserId != null) {
        final following = await _socialService.getFollowing(_currentUserId!);
        followingIds = following.map((doc) => doc.data['followee_id'] as String).toList();
      }
      
      // Convert to user profiles and filter out current user
      final userProfiles = results
          .where((doc) => doc.data['user_id'] != _currentUserId)
          .map((doc) => UserProfile.fromDocument(doc))
          .toList();
      
      // Update following status for all users
      for (var user in userProfiles) {
        _followingStatus[user.userId] = followingIds.contains(user.userId);
      }
      
      setState(() {
        _searchResults = userProfiles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleFollowStatus(UserProfile user) async {
    if (_currentUserId == null) return;
    
    final isFollowing = _followingStatus[user.userId] ?? false;
    
    setState(() {
      _followingStatus[user.userId] = !isFollowing;
    });
    
    try {
      if (isFollowing) {
        // Unfollow
        await _socialService.unfollowUser(
          followerId: _currentUserId!,
          followeeId: user.userId,
        );
      } else {
        // Follow
        await _socialService.followUser(
          followerId: _currentUserId!,
          followeeId: user.userId,
        );
      }
    } catch (e) {
      // Revert on error
      print('Error toggling follow status: $e');
      setState(() {
        _followingStatus[user.userId] = isFollowing;
      });
    }
  }
  
  void _viewUserProfile(UserProfile user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: user.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Find Friends',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.firaSansCondensed(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or username...',
                  hintStyle: GoogleFonts.firaSansCondensed(color: Colors.grey[500]),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                ),
                onChanged: _searchUsers,
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : _searchResults.isNotEmpty
                ? _buildUserList(_searchResults)
                : _buildSuggestedUsers(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuggestedUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Suggested Friends',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
        ),
        Expanded(
          child: _suggestedUsers.isEmpty
            ? Center(
                child: Text(
                  'No suggested users found',
                  style: GoogleFonts.firaSansCondensed(color: Colors.grey[500]),
                ),
              )
            : _buildUserList(_suggestedUsers),
        ),
      ],
    );
  }
  
  Widget _buildUserList(List<UserProfile> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isFollowing = _followingStatus[user.userId] ?? false;
        
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: GestureDetector(
            onTap: () => _viewUserProfile(user),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage: user.avatarFileId != null
                ? NetworkImage(user.avatarFileId!)
                : null,
              child: user.avatarFileId == null
                ? Icon(Icons.person, color: Colors.white)
                : null,
            ),
          ),
          title: Text(
            user.displayName,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '@${user.username}',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          trailing: ElevatedButton(
            onPressed: () => _toggleFollowStatus(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.grey[800] : Colors.greenAccent,
              foregroundColor: isFollowing ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              isFollowing ? 'Unfollow' : 'Follow',
              style: GoogleFonts.firaSansCondensed(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () => _viewUserProfile(user),
        );
      },
    );
  }
}