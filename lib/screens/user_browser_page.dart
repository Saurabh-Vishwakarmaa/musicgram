import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/screens/profile2.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:appwrite/models.dart' as appwrite;
import 'package:musicgram4/services/appwrite_service.dart';

class UserBrowserPage extends StatefulWidget {
  final SocialDatabaseService socialService;
  final String? currentUserId;
  
  const UserBrowserPage({
    Key? key, 
    required this.socialService,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<UserBrowserPage> createState() => _UserBrowserPageState();
}

class _UserBrowserPageState extends State<UserBrowserPage> {
  List<UserProfile> _users = [];
  Map<String, bool> _followStatus = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load all users
      final documents = await widget.socialService.getAllUsers(limit: 50);
      
      // Filter out the current user
      final filteredDocs = documents
          .where((doc) => doc.data['user_id'] != widget.currentUserId)
          .toList();
      
      // Convert to UserProfile objects
      final users = filteredDocs
          .map((doc) => UserProfile.fromDocument(doc))
          .toList();
      
      // If searching, filter by search query
      final List<UserProfile> searchResults;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        searchResults = users
            .where((user) => 
                user.displayName.toLowerCase().contains(query) ||
                user.username.toLowerCase().contains(query))
            .toList();
      } else {
        searchResults = users;
      }
      
      // Load following status
      final followStatus = <String, bool>{};
      if (widget.currentUserId != null) {
        final following = await widget.socialService.getFollowing(widget.currentUserId!);
        final followingIds = following
            .map((doc) => doc.data['followee_id'] as String)
            .toList();
        
        for (final user in searchResults) {
          followStatus[user.userId] = followingIds.contains(user.userId);
        }
      }
      
      setState(() {
        _users = searchResults;
        _followStatus = followStatus;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleFollowUser(UserProfile user) async {
    if (widget.currentUserId == null) return;
    
    final currentStatus = _followStatus[user.userId] ?? false;
    
    // Optimistic update
    setState(() {
      _followStatus[user.userId] = !currentStatus;
    });
    
    try {
      if (currentStatus) {
        // Unfollow
        await widget.socialService.unfollowUser(
          followerId: widget.currentUserId!,
          followeeId: user.userId,
        );
      } else {
        // Follow
        await widget.socialService.followUser(
          followerId: widget.currentUserId!,
          followeeId: user.userId,
        );
      }
    } catch (e) {
      // Revert on error
      print('Error toggling follow status: $e');
      setState(() {
        _followStatus[user.userId] = currentStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update follow status: $e')),
      );
    }
  }
  
  void _searchUsers(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadUsers();
  }
  
  void _viewUserProfile(UserProfile user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: user.userId),
      ),
    ).then((_) => _loadUsers()); // Refresh when returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Find People',
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
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or username',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          
          // Display options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_users.length} users found',
                  style: TextStyle(color: Colors.grey),
                ),
                TextButton.icon(
                  onPressed: _loadUsers,
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                  style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                ),
              ],
            ),
          ),
          
          // User list
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 72, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: GoogleFonts.firaSansCondensed(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Try a different search term',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isFollowing = _followStatus[user.userId] ?? false;
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        color: Colors.grey[900],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(12),
                          leading: GestureDetector(
                            onTap: () => _viewUserProfile(user),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: user.avatarFileId != null
                                ? NetworkImage(_getAvatarUrl(user.avatarFileId!))
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${user.username}',
                                style: GoogleFonts.firaSansCondensed(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              if (user.bio != null && user.bio!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    user.bio!,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          trailing: TextButton(
                            onPressed: () => _toggleFollowUser(user),
                            style: TextButton.styleFrom(
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  String _getAvatarUrl(String fileId) {
    // Use the helper method from AppwriteService
    return AppwriteService.getFilePreview(fileId);
  }
}
