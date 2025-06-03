import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:musicgram4/services/appwrite_service.dart' as apt;
import 'package:musicgram4/services/chat_service.dart';
import 'package:musicgram4/social/screens/chat_screen.dart';
import 'package:musicgram4/database/social_database_service.dart';
 // Import the new message screen


class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService _chatService = ChatService(
    databases: apt.AppwriteService.databases,
    realtime: Realtime(apt.AppwriteService.client),
    account: apt.AppwriteService.account,
    storage: apt.AppwriteService.storage,
  );
  
  final SocialDatabaseService _socialService = SocialDatabaseService(databases: apt.AppwriteService.databases, storage: apt.AppwriteService.storage, account: apt.AppwriteService.account,

  );
  
  String? _currentUserId;
  List<Document> _conversations = [];
  Map<String, Document> _userProfiles = {};
  bool _isLoading = true;
  
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();
  RealtimeSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }
  
  @override
  void dispose() {
    _subscription?.close();
    _searchController.dispose();
    super.dispose();
  }
  
  void _setupRealtimeUpdates() {
    _subscription?.close();
    
    _subscription = _chatService.realtime.subscribe([
      'databases.${apt.AppConfig.databaseId}.collections.${apt.AppConfig.chatchat_conversations}.documents'
    ]);
    
    _subscription!.stream.listen((response) {
      if (response.events.contains('databases.*.collections.*.documents.*.update')) {
        final updatedConversation = Document.fromMap(response.payload);
        
        // Check if this conversation involves the current user
        final isParticipant1 = updatedConversation.data['participant1_id'] == _currentUserId;
        final isParticipant2 = updatedConversation.data['participant2_id'] == _currentUserId;
        
        if (isParticipant1 || isParticipant2) {
          // Update the conversation in our list
          setState(() {
            final index = _conversations.indexWhere((c) => c.$id == updatedConversation.$id);
            if (index >= 0) {
              _conversations[index] = updatedConversation;
              // Resort the conversations
              _conversations.sort((a, b) {
                final aTime = DateTime.parse(a.data['last_message_time']);
                final bTime = DateTime.parse(b.data['last_message_time']);
                return bTime.compareTo(aTime);
              });
            } else {
              // This is a new conversation
              _conversations.add(updatedConversation);
              _conversations.sort((a, b) {
                final aTime = DateTime.parse(a.data['last_message_time']);
                final bTime = DateTime.parse(b.data['last_message_time']);
                return bTime.compareTo(aTime);
              });
            }
          });
        }
      }
    });
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await apt.AppwriteService.account.get();
      setState(() {
        _currentUserId = user.$id;
      });
      _loadConversations();
      _setupRealtimeUpdates();
    } catch (e) {
      print('Error loading current user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadConversations() async {
    if (_currentUserId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final conversations = await _chatService.getUserConversations(_currentUserId!);
      
      // Sort by most recent message
      conversations.sort((a, b) {
        final aTime = DateTime.parse(a.data['last_message_time']);
        final bTime = DateTime.parse(b.data['last_message_time']);
        return bTime.compareTo(aTime); // Descending - newest first
      });
      
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
      
      // Load user profiles for all conversations
      for (var conversation in conversations) {
        final otherUserId = conversation.data['participant1_id'] == _currentUserId
            ? conversation.data['participant2_id']
            : conversation.data['participant1_id'];
        
        _loadUserProfile(otherUserId);
      }
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadUserProfile(String userId) async {
    try {
      final profile = await _socialService.getUserProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _userProfiles[userId] = profile;
        });
      }
    } catch (e) {
      print('Error loading user profile for $userId: $e');
    }
  }
  
  String _getOtherUserId(Document conversation) {
    return conversation.data['participant1_id'] == _currentUserId
        ? conversation.data['participant2_id']
        : conversation.data['participant1_id'];
  }
  
  String _getOtherUserName(String userId) {
    final profile = _userProfiles[userId];
    if (profile != null) {
      return profile.data['username'] ?? 'User';
    }
    return 'User';
  }
  
  String? _getOtherUserAvatar(String userId) {
    final profile = _userProfiles[userId];
    if (profile != null) {
      return profile.data['avatar_url'];
    }
    return null;
  }
  
  int _getUnreadCount(Document conversation) {
    final String unreadField = conversation.data['participant1_id'] == _currentUserId
        ? 'unread_count_p1'
        : 'unread_count_p2';
    
    return conversation.data[unreadField] ?? 0;
  }
  
  void _navigateToChat(Document conversation) {
    final otherUserId = conversation.data['participant1_id'] == _currentUserId 
        ? conversation.data['participant2_id'] 
        : conversation.data['participant1_id'];
        
    // Fetch the user details from your user profile service
    _socialService.getUserProfile(otherUserId).then((userProfile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversation.$id,
            otherUserId: otherUserId,
            otherUserName: userProfile?.data['username'] ?? 'User',
            otherUserAvatar: userProfile?.data['avatar_url'],
          ),
        ),
      );
    }).catchError((e) {
      print("Error navigating to chat: $e");
      // Fallback if user profile can't be loaded
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversation.$id,
            otherUserId: otherUserId,
            otherUserName: 'User',
            otherUserAvatar: null,
          ),
        ),
      );
    });
  }
  
  Widget _buildConversationItem(Document conversation) {
    final otherUserId = _getOtherUserId(conversation);
    final otherUserName = _getOtherUserName(otherUserId);
    final otherUserAvatar = _getOtherUserAvatar(otherUserId);
    final lastMessage = conversation.data['last_message'] ?? '';
    final lastMessageTime = DateTime.parse(conversation.data['last_message_time']);
    final unreadCount = _getUnreadCount(conversation);
    
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: otherUserAvatar != null ? NetworkImage(otherUserAvatar) : null,
        backgroundColor: Colors.grey[300],
        child: otherUserAvatar == null
            ? Text(
                otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                style: TextStyle(color: Colors.black54, fontSize: 18),
              )
            : null,
      ),
      title: Text(
        otherUserName,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        lastMessage,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
          color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeago.format(lastMessageTime, locale: 'en_short'),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          if (unreadCount > 0)
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () => _navigateToChat(conversation),
    );
  }
  
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: _performSearch,
      ),
    );
  }
  
  List<Document> get _filteredConversations {
    if (_searchQuery.isEmpty) {
      return _conversations;
    }
    
    return _conversations.where((conversation) {
      final otherUserId = _getOtherUserId(conversation);
      final otherUserName = _getOtherUserName(otherUserId).toLowerCase();
      final lastMessage = (conversation.data['last_message'] ?? '').toLowerCase();
      
      return otherUserName.contains(_searchQuery) || 
             lastMessage.contains(_searchQuery);
    }).toList();
  }
  
  // Replace _showNewMessageScreen with this
  void _showUserSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _UserSelectionSheet(
              currentUserId: _currentUserId!,
              socialService: _socialService,
              scrollController: scrollController,
              onUserSelected: (userId, userName, userAvatar) {
                Navigator.pop(context);
                _createNewConversation(userId, userName, userAvatar);
              },
            );
          },
        );
      },
    );
  }

  // Implement creating a new conversation
  Future<void> _createNewConversation(
    String userId, 
    String userName, 
    String? userAvatar
  ) async {
    try {
      // First check if a conversation already exists
      final existingConversations = await _chatService.getUserConversations(_currentUserId!);
      
      for (var conversation in existingConversations) {
        final otherUserId = _getOtherUserId(conversation);
        if (otherUserId == userId) {
          // Conversation already exists, just navigate to it
          _navigateToChat(conversation);
          return;
        }
      }
      
      // Create a new conversation
      final newConversation = await _chatService.getOrCreateConversation(
        _currentUserId!, 
        userId,
        user1Name: 'Me', // You would want to get the current user's name
        user2Name: userName,
      );
      
      // Navigate to the new conversation
      _navigateToChat(newConversation);
    } catch (e) {
      print('Error creating new conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create conversation')),
      );
    }
  }
  
  // Add these helper methods
  Future<bool> _confirmDelete(Document conversation) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Conversation'),
        content: Text('Are you sure you want to delete this conversation?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _confirmArchive(Document conversation) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive Conversation'),
        content: Text('Are you sure you want to archive this conversation?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Archive'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
  }

    void _deleteConversation(Document conversation) async {
      try {
        // Implement actual deletion in your ChatService
        // await _chatService.deleteConversation(conversation.$id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Add conversation back to the list
                setState(() {
                  _conversations.add(conversation);
                  _conversations.sort((a, b) {
                    final aTime = DateTime.parse(a.data['last_message_time']);
                    final bTime = DateTime.parse(b.data['last_message_time']);
                    return bTime.compareTo(aTime);
                  });
                });
              },
            ),
          ),
        );
      } catch (e) {
        print('Error deleting conversation: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete conversation')));
      }
    }
    
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Messages',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 1,
          actions: [
            IconButton(
              icon: Icon(Icons.add_comment),
              onPressed: _showUserSelectionDialog,
              tooltip: 'New Message',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                  : _filteredConversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'No conversations yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _showUserSelectionDialog,
                                child: Text('Start a new chat'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredConversations.length,
                          separatorBuilder: (context, index) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            return Dismissible(
                              key: Key(_filteredConversations[index].$id),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: 16),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) => _confirmDelete(_filteredConversations[index]),
                              onDismissed: (direction) {
                                setState(() {
                                  _deleteConversation(_filteredConversations[index]);
                                  _filteredConversations.removeAt(index);
                                });
                              },
                              child: _buildConversationItem(_filteredConversations[index]),
                            );
                          },
                        ),
            ),
          ],
        ),
      );
    }
  }

class _UserSelectionSheet extends StatefulWidget {
  final String currentUserId;
  final SocialDatabaseService socialService;
  final ScrollController scrollController;
  final Function(String, String, String?) onUserSelected;

  const _UserSelectionSheet({
    Key? key,
    required this.currentUserId,
    required this.socialService,
    required this.scrollController,
    required this.onUserSelected,
  }) : super(key: key);

  @override
  _UserSelectionSheetState createState() => _UserSelectionSheetState();
}

class _UserSelectionSheetState extends State<_UserSelectionSheet> {
  List<Document> _users = [];
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
    try {
      // Modify this to use your actual method to fetch users
      // This is just an example - your implementation may be different
      final users = await widget.socialService.getAllUsers();
      
      setState(() {
        // Filter out the current user
        _users = users.where((user) => user.$id != widget.currentUserId).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Document> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    
    return _users.where((user) {
      final username = (user.data['username'] ?? '').toLowerCase();
      final name = (user.data['name'] ?? '').toLowerCase();
      
      return username.contains(_searchQuery) || 
             name.contains(_searchQuery);
    }).toList();
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sheet header
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Message',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for people...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _performSearch,
              ),
            ],
          ),
        ),
        
        // User list
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final username = user.data['username'] ?? 'User';
                        final avatarUrl = user.data['avatar_url'];
                        
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            backgroundColor: Colors.grey[300],
                            child: avatarUrl == null
                                ? Text(
                                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                                    style: TextStyle(color: Colors.black54, fontSize: 18),
                                  )
                                : null,
                          ),
                          title: Text(
                            username,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: user.data['name'] != null
                              ? Text(
                                  user.data['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                )
                              : null,
                          onTap: () => widget.onUserSelected(
                            user.$id, 
                            username, 
                            avatarUrl,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}