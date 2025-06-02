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
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await apt.AppwriteService.account.get();
      setState(() {
        _currentUserId = user.$id;
      });
      _loadConversations();
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
    final otherUserId = _getOtherUserId(conversation);
    final otherUserName = _getOtherUserName(otherUserId);
    final otherUserAvatar = _getOtherUserAvatar(otherUserId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.$id,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserAvatar: otherUserAvatar,
        ),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      _loadConversations();
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _conversations.isEmpty
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
                      SizedBox(height: 8),
                      Text(
                        'Start a chat with someone to see it here',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: Colors.greenAccent,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildConversationItem(_conversations[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to new message screen
        },
        child: Icon(Icons.chat, color: Colors.white),
        backgroundColor: Colors.greenAccent,
      ),
    );
  }
}