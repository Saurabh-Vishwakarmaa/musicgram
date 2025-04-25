import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:musicgram4/services/appwrite_service.dart' as apt;

class NewMessageBottomSheet extends StatefulWidget {
  final Function(UserProfile) onUserSelected;
  
  const NewMessageBottomSheet({
    Key? key,
    required this.onUserSelected,
  }) : super(key: key);

  @override
  State<NewMessageBottomSheet> createState() => _NewMessageBottomSheetState();
}

class _NewMessageBottomSheetState extends State<NewMessageBottomSheet> {
  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await AppwriteService.account.get();
      _currentUserId = user.$id;
      _loadAllUsers();
    } catch (e) {
      print('Error getting current user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadAllUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all users from the user profiles collection
      final result = await AppwriteService.databases.listDocuments(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.userProfilesCollection,
      );
      
      List<UserProfile> users = [];
      
      for (var doc in result.documents) {
        // Skip the current user from the list
        if (doc.data['user_id'] != _currentUserId) {
          users.add(UserProfile.fromDocument(doc));
        }
      }
      
      setState(() {
        _allUsers = users;
        _filteredUsers = List.from(users);
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      
      if (_searchQuery.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.displayName.toLowerCase().contains(_searchQuery) ||
                 user.username.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Message',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Select a user to start a conversation',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 16),
          TextField(
            autofocus: true,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _filterUsers,
          ),
          SizedBox(height: 16),
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : _filteredUsers.isEmpty
                  ? _buildEmptyList()
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[800],
                            backgroundImage: user.avatarFileId != null
                                ? _getAvatarImage(user.avatarFileId!)
                                : null,
                            child: user.avatarFileId == null
                                ? Text(user.displayName[0].toUpperCase())
                                : null,
                          ),
                          title: Text(
                            user.displayName,
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '@${user.username}',
                            style: TextStyle(color: Colors.grey),
                          ),
                          onTap: () {
                            widget.onUserSelected(user);
                            Navigator.pop(context); // Close the sheet immediately after selection
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 48,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No users found'
                : 'No users matching "${_searchQuery}"',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 16,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarImage(String fileId) {
    try {
      return NetworkImage(AppwriteService.getFilePreview(fileId));
    } catch (e) {
      print('Error loading avatar: $e');
      return null;
    }
  }
}