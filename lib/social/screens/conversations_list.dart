import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' hide Row;
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:musicgram4/services/appwrite_service.dart' as apt;
import 'package:musicgram4/services/chat_service.dart';
import 'package:musicgram4/social/screens/chat_screen.dart';
import 'package:flutter/services.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService(
    databases: apt.AppwriteService.databases,
    realtime: Realtime(apt.AppwriteService.client),
    account: apt.AppwriteService.account,
    storage: apt.AppwriteService.storage,
  );
  
  final SocialDatabaseService _socialService = SocialDatabaseService(
    databases: apt.AppwriteService.databases,
    storage: apt.AppwriteService.storage,
    account: apt.AppwriteService.account,
  );
  
  String? _currentUserId;
  List<Document> _conversations = [];
  Map<String, Document> _userProfiles = {};
  bool _isLoading = true;
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  RealtimeSubscription? _subscription;
  
  // Animation controller for list items
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _loadCurrentUser();
  }
  
  @override
  void dispose() {
    _subscription?.close();
    _searchController.dispose();
    _animationController.dispose();
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
      
      // Play animation when conversations load
      _animationController.forward();
      
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
        
    // Trigger haptic feedback
    HapticFeedback.lightImpact();
    
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
  
  Widget _buildConversationItem(Document conversation, int index) {
    final otherUserId = _getOtherUserId(conversation);
    final otherUserName = _getOtherUserName(otherUserId);
    final otherUserAvatar = _getOtherUserAvatar(otherUserId);
    final lastMessage = conversation.data['last_message'] ?? '';
    final lastMessageTime = DateTime.parse(conversation.data['last_message_time']);
    final unreadCount = _getUnreadCount(conversation);
    
    // Staggered animation delay based on index
    final Animation<double> animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          (index / _filteredConversations.length) * 0.5,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );
    
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.05, 0),
          end: Offset.zero,
        ).animate(animation),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: unreadCount > 0 ? Colors.greenAccent.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToChat(conversation),
              splashColor: Colors.greenAccent.withOpacity(0.1),
              highlightColor: Colors.greenAccent.withOpacity(0.05),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  children: [
                    _buildAvatar(otherUserName, otherUserAvatar, unreadCount > 0),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  otherUserName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeago.format(lastMessageTime, locale: 'en_short'),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                                  color: unreadCount > 0 ? Colors.greenAccent[700] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                                    color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAvatar(String name, String? avatarUrl, bool hasUnread) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey[200],
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
        ),
        if (hasUnread)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
  
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }
  
  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          filled: true,
          fillColor: Colors.white,
        ),
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black87,
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
  
  void _showUserSelectionDialog() {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _UserSelectionSheet(
                currentUserId: _currentUserId!,
                socialService: _socialService,
                scrollController: scrollController,
                onUserSelected: (userId, userName, userAvatar) {
                  Navigator.pop(context);
                  _createNewConversation(userId, userName, userAvatar);
                },
              ),
            );
          },
        );
      },
    );
  }

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
  
  Future<bool> _confirmDelete(Document conversation) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Conversation',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this conversation?',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(),
            ),
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
          content: Text(
            'Conversation deleted',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.blueGrey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(10),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.greenAccent,
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
        SnackBar(
          content: Text('Failed to delete conversation'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Colors.greenAccent[700],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No conversations yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start chatting with friends about music',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _showUserSelectionDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline),
                SizedBox(width: 8),
                Text(
                  'Start a new chat',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading conversations...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
    
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: Colors.greenAccent[700],
                  size: 22,
                ),
              ),
              onPressed: _showUserSelectionDialog,
              tooltip: 'New Message',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredConversations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _filteredConversations.length,
                        padding: EdgeInsets.only(top: 8, bottom: 20),
                        itemBuilder: (context, index) {
                          return Dismissible(
                            key: Key(_filteredConversations[index].$id),
                            background: Container(
                              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[400],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 24),
                              child: Icon(Icons.delete_outline, color: Colors.white, size: 28),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) => _confirmDelete(_filteredConversations[index]),
                            onDismissed: (direction) {
                              setState(() {
                                _deleteConversation(_filteredConversations[index]);
                                _filteredConversations.removeAt(index);
                              });
                            },
                            child: _buildConversationItem(_filteredConversations[index], index),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _filteredConversations.isEmpty && !_isLoading ? 
        FloatingActionButton(
          onPressed: _showUserSelectionDialog,
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black87,
          elevation: 3,
          child: Icon(Icons.chat_bubble_outline),
        ) : null,
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
        // Sheet handle
        Container(
          margin: EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Sheet header
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Message',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: Colors.grey[700]),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for people...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                  ),
                  onChanged: _performSearch,
                ),
              ),
            ],
          ),
        ),
        
        // User list
        Expanded(
          child: _isLoading
              ? Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      strokeWidth: 3,
                    ),
                  ),
                )
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final username = user.data['username'] ?? 'User';
                        final avatarUrl = user.data['avatar_url'];
                        
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => widget.onUserSelected(
                                user.$id, 
                                username, 
                                avatarUrl,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                      backgroundColor: Colors.grey[200],
                                      child: avatarUrl == null
                                          ? Text(
                                              username.isNotEmpty ? username[0].toUpperCase() : '?',
                                              style: GoogleFonts.poppins(
                                                color: Colors.black54,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            username,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          if (user.data['name'] != null)
                                            Text(
                                              user.data['name'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      color: Colors.greenAccent[700],
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}