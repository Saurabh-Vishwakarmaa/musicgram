import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/services/appwrite_service.dart';
import 'package:musicgram4/services/chat_service.dart';
import 'package:musicgram4/social/components/new_message_sheet.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:musicgram4/social/screens/chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:musicgram4/services/appwrite_service.dart' as apt;

class ConversationsList extends StatefulWidget {
  const ConversationsList({Key? key}) : super(key: key);

  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList> {
  late ChatService _chatService;
  late SocialDatabaseService _socialService;
  String? _currentUserId;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  RealtimeSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();

    _chatService = ChatService(
      databases: AppwriteService.databases,
      realtime: Realtime(AppwriteService.client),
      account: AppwriteService.account,
    );

    _socialService = SocialDatabaseService(
      databases: AppwriteService.databases,
      storage: AppwriteService.storage,
      account: AppwriteService.account,
    );

    _initialize();
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final user = await AppwriteService.account.get();
      _currentUserId = user.$id;
      
      await _loadConversations();
      _subscribeToConversations();
    } catch (e) {
      print('Error initializing conversations list: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConversations() async {
    if (_currentUserId == null) return;
    
    try {
      final conversationDocs = await _chatService.getUserConversations(_currentUserId!);
      
      List<Map<String, dynamic>> conversations = [];
      
      for (var doc in conversationDocs) {
        final String participant1Id = doc.data['participant1_id'];
        final String participant2Id = doc.data['participant2_id'];
        
        // Determine other user ID and unread count for current user
        final bool isParticipant1 = _currentUserId == participant1Id;
        final String otherUserId = isParticipant1 ? participant2Id : participant1Id;
        final String unreadCountField = isParticipant1 ? 'unread_count_p1' : 'unread_count_p2';
        final int unreadCount = doc.data[unreadCountField] ?? 0;
        
        String otherUserName = "User";
        String? avatar;
        
        // Get more details about the other user if possible
        try {
          final userDoc = await _socialService.getUserProfile(otherUserId);
          UserProfile userProfile = UserProfile.fromDocument(userDoc);
          
          otherUserName = userProfile.displayName;
          if (userProfile.avatarFileId != null) {
            avatar = userProfile.avatarFileId;
          }
        } catch (e) {
          print('Could not get other user profile: $e');
        }
        
        conversations.add({
          'id': doc.$id,
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'lastMessage': doc.data['last_message'] ?? '',
          'lastMessageTime': DateTime.parse(doc.data['last_message_time'] ?? DateTime.now().toIso8601String()),
          'unreadCount': unreadCount,
          'isLastMessageFromMe': doc.data['last_message_sender_id'] == _currentUserId,
          'avatar': avatar,
          'hasSharedSession': doc.data['shared_session_id'] != null,
        });
      }
      
      // Sort by last message time (newest first)
      conversations.sort((a, b) => b['lastMessageTime'].compareTo(a['lastMessageTime']));
      
      setState(() {
        _conversations = conversations;
      });
    } catch (e) {
      print('Error loading conversations: $e');
    }
  }

  void _subscribeToConversations() {
    _subscription = Realtime(AppwriteService.client).subscribe([
      'databases.${apt.AppConfig.databaseId}.collections.chat_conversations.documents'
    ]);
    
    _subscription!.stream.listen((response) {
      if (response.events.contains('databases.*.collections.*.documents.*.update') ||
          response.events.contains('databases.*.collections.*.documents.*.create')) {
        _loadConversations();
      }
    });
  }

  void _openChat(Map<String, dynamic> conversation) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation['id'],
          otherUserId: conversation['otherUserId'],
          otherUserName: conversation['otherUserName'],
        ),
      ),
    ).then((_) {
      // Refresh conversations after returning from chat
      _loadConversations();
    });
  }

  void _startNewConversation() {
    _showContactsSheet();
  }

  // Fix the _showContactsSheet method

void _showContactsSheet() {
  // Capture the BuildContext before any async operations
  final BuildContext currentContext = context;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(currentContext);
  
  showModalBottomSheet(
    context: currentContext,
    isScrollControlled: true,
    backgroundColor: Colors.grey[900],
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: NewMessageBottomSheet(
          onUserSelected: (UserProfile user) async {
            // Close the sheet first - this is important to prevent the context issues
            Navigator.pop(context);
            
            if (_currentUserId == null) return;
            
            // Set a flag to track if component is still mounted
            bool isStillMounted = true;
            
            // Set loading state
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            } else {
              isStillMounted = false;
              return;
            }
            
            try {
              // Create or get conversation
              final conversation = await _chatService.getOrCreateConversation(
                _currentUserId!,
                user.userId,
                user1Name: '', 
                user2Name: user.displayName,
              );
              
              // Only proceed if still mounted
              if (!mounted) {
                isStillMounted = false;
                return;
              }
              
              // Open the chat screen
              Navigator.push(
                currentContext, // Use the captured context
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    conversationId: conversation.$id,
                    otherUserId: user.userId,
                    otherUserName: user.displayName,
                  ),
                ),
              ).then((_) {
                // Only refresh if still mounted
                if (mounted) {
                  _loadConversations();
                }
              });
            } catch (e) {
              print('Error starting conversation: $e');
              
              // Only show error if still mounted - and use the previously captured messenger
              if (isStillMounted && mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to start conversation'))
                );
              }
            } finally {
              // Only update state if still mounted
              if (isStillMounted && mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          },
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Messages',
                        style: GoogleFonts.firaSansCondensed(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.greenAccent),
                        onPressed: _startNewConversation,
                        tooltip: 'New Message',
                      ),
                    ],
                  ),
                ),
                
                // Conversations list
                Expanded(
                  child: _conversations.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = _conversations[index];
                            return _buildConversationTile(conversation);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    return InkWell(
      onTap: () => _openChat(conversation),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[900]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: conversation['avatar'] != null 
                      ? NetworkImage(AppwriteService.getFilePreview(conversation['avatar']))
                      : null,
                  child: conversation['avatar'] == null
                      ? Text(
                          conversation['otherUserName'][0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (conversation['hasSharedSession'])
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Icon(
                        Icons.headphones,
                        size: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12),
            
            // Message preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation['otherUserName'],
                          style: GoogleFonts.firaSansCondensed(
                            fontSize: 16,
                            fontWeight: conversation['unreadCount'] > 0 ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeago.format(conversation['lastMessageTime'], locale: 'en_short'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation['isLastMessageFromMe'])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      Expanded(
                        child: Text(
                          conversation['lastMessage'] == '' 
                              ? 'Start a conversation' 
                              : conversation['lastMessage'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: conversation['unreadCount'] > 0 ? FontWeight.bold : FontWeight.normal,
                            color: conversation['unreadCount'] > 0 ? Colors.white : Colors.grey[400],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation['unreadCount'] > 0)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation['unreadCount']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[700],
          ),
          SizedBox(height: 24),
          Text(
            'No conversations yet',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start a new conversation with a friend',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 16,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startNewConversation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text('New Message'),
          ),
        ],
      ),
    );
  }
}