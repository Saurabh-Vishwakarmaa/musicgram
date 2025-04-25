import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/services/appwrite_service.dart' as apt;
import 'package:musicgram4/services/chat_service.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:musicgram4/social/screens/paired_listening.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;


class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;
  late SocialDatabaseService _socialService;
  String? _currentUserId;
  UserProfile? _otherUserProfile;
  List<Document> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeSubscription? _subscription;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  
  Timer? _markAsReadTimer;
  Document? _conversation;
  bool _isPairedListening = false;
  String? _pairedSessionId;

  @override
  void initState() {
    super.initState();

    _chatService = ChatService(
      databases: apt.AppwriteService.databases,
      realtime: Realtime(apt.AppwriteService.client),
      account: apt.AppwriteService.account,
    );

    _socialService = SocialDatabaseService(
      databases: apt.AppwriteService.databases,
      storage: apt.AppwriteService.storage,
      account: apt.AppwriteService.account,
    );

    _initialize();
  }

  @override
  void dispose() {
    _subscription?.close();
    _markAsReadTimer?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final user = await apt.AppwriteService.account.get();
      _currentUserId = user.$id;

      await Future.wait([
        _loadConversation(),
        _loadOtherUserProfile(),
        _loadMessages(),
      ]);

      _subscribeToMessages();
      _markConversationAsRead();
    } catch (e) {
      print('Error initializing chat: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConversation() async {
    try {
      _conversation = await apt.AppwriteService.databases.getDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: 'chat_conversations',
        documentId: widget.conversationId,
      );

      // Check if there's an active paired listening session
      _pairedSessionId = _conversation!.data['shared_session_id'];
      if (_pairedSessionId != null) {
        // Check if session is still active
        try {
          final session = await apt.AppwriteService.databases.getDocument(
            databaseId: apt.AppConfig.databaseId,
            collectionId: '68065fc1000215395c66',
            documentId: _pairedSessionId!,
          );
          _isPairedListening = session.data['status'] == 'active';
        } catch (e) {
          _isPairedListening = false;
          _pairedSessionId = null;
        }
      }
    } catch (e) {
      print('Error loading conversation: $e');
    }
  }

  Future<void> _loadOtherUserProfile() async {
    try {
      final userDoc = await _socialService.getUserProfile(widget.otherUserId);
      setState(() {
        _otherUserProfile = UserProfile.fromDocument(userDoc);
      });
    } catch (e) {
      print('Error loading other user profile: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getConversationMessages(
        widget.conversationId,
        limit: 50,
      );
      
      setState(() {
        _messages = messages.reversed.toList(); // Display in chronological order
      });
      
      // Scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  void _subscribeToMessages() {
    _subscription = _chatService.subscribeToMessages(
      widget.conversationId,
      (newMessage) {
        setState(() {
          _messages.add(newMessage);
        });
        
        // If message is from other user, mark as read
        if (newMessage.data['sender_id'] != _currentUserId) {
          _markConversationAsRead();
        }
        
        // Scroll to bottom when new message arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );
  }

  void _markConversationAsRead() {
    if (_currentUserId == null) return;
    
    // Cancel existing timer if any
    _markAsReadTimer?.cancel();
    
    // Set a small delay to avoid too many API calls when messages come rapidly
    _markAsReadTimer = Timer(Duration(seconds: 1), () async {
      await _chatService.markConversationAsRead(
        widget.conversationId,
        _currentUserId!,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;
    
    final text = _textController.text;
    _textController.clear();
    
    try {
      setState(() {
        _isSending = true;
      });
      
      // Create the message in chat_messages collection
      await apt.AppwriteService.databases.createDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatMessagesCollection, // Use the message collection constant
        documentId: ID.unique(),
        data: {
          'conversation_id': widget.conversationId,
          'sender_id': _currentUserId,
          'message': text,
          'timestamp': DateTime.now().toIso8601String(), // This is the required field
          'is_read': false, // Using is_read (not read)
          'type': 'text', // Required type field
          'media_id': null, // Optional
          'song_id': null, // Optional
        },
      );
      
      // Update conversation metadata in chat_conversations collection
      await apt.AppwriteService.databases.updateDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations, // Use the conversations collection constant
        documentId: widget.conversationId,
        data: {
          'last_message': text,
          'last_message_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _startPairedListening() async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PairedListeningScreen(
            guestUserId: widget.otherUserId,
            guestUsername: widget.otherUserName,
          ),
        ),
      );
    } catch (e) {
      print('Error starting paired listening: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start paired listening')),
      );
    }
  }

  void _showShareOptions() {
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
                'Share with ${widget.otherUserName}',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              _buildShareOption(
                icon: Icons.music_note,
                title: 'Share a Song',
                subtitle: 'Send a song recommendation',
                onTap: () {
                  Navigator.pop(context);
                  // Implement song selection
                },
              ),
              Divider(color: Colors.grey[800]),
              _buildShareOption(
                icon: Icons.headphones,
                title: 'Start Paired Listening',
                subtitle: 'Listen to music together in real-time',
                onTap: () {
                  Navigator.pop(context);
                  _startPairedListening();
                },
              ),
              Divider(color: Colors.grey[800]),
              _buildShareOption(
                icon: Icons.photo,
                title: 'Send Image',
                subtitle: 'Share an image from your gallery',
                onTap: () {
                  Navigator.pop(context);
                  // Implement image selection
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: _otherUserProfile?.avatarFileId != null
                  ? CachedNetworkImageProvider(
                     apt.AppwriteService.getFilePreview(_otherUserProfile!.avatarFileId!),
                    )
                  : null,
              child: _otherUserProfile?.avatarFileId == null
                  ? Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: GoogleFonts.firaSansCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_isPairedListening)
                  Text(
                    'Listening together',
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isPairedListening)
            IconButton(
              icon: Icon(Icons.headphones, color: Colors.greenAccent),
              onPressed: () {
                // Navigate to active paired session
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PairedListeningScreen(
                      sessionId: _pairedSessionId,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show chat options
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyChatState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message.data['sender_id'] == _currentUserId;
                            final messageType = message.data['type'] ?? 'text';
                            
                            return _buildMessageBubble(
                              message: message,
                              isMe: isMe,
                              messageType: messageType,
                            );
                          },
                        ),
                ),
                
                // Input area
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: SafeArea(
                    child: Row(
                      children: [
                        // Attach button
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                          onPressed: _showShareOptions,
                        ),
                        // Text field
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: GoogleFonts.firaSansCondensed(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              filled: true,
                              fillColor: Colors.grey[850],
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        SizedBox(width: 8),
                        // Send button
                        GestureDetector(
                          onTap: _isSending ? null : _sendMessage,
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.greenAccent,
                            ),
                            child: _isSending
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[900],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: Colors.greenAccent,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Start a conversation',
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
              'Say hello to ${widget.otherUserName} or share a song',
              textAlign: TextAlign.center,
              style: GoogleFonts.firaSansCondensed(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startPairedListening,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: Icon(Icons.headphones),
            label: Text('Start Paired Listening'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required Document message,
    required bool isMe,
    required String messageType,
  }) {
    final content = message.data['message'] as String;
    final time = timeago.format(
      DateTime.parse(message.data['timestamp']),
      locale: 'en_short',
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: isMe ? 64 : 0,
          right: isMe ? 0 : 64,
        ),
        padding: messageType == 'song'
            ? EdgeInsets.all(4)
            : EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe 
              ? Colors.greenAccent.withOpacity(0.9)
              : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
            bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (messageType == 'song')
              _buildSongPreview(message, isMe)
            else if (messageType == 'image')
              _buildImagePreview(message.data['media_id'], isMe)
            else
              Text(
                content,
                style: GoogleFonts.firaSansCondensed(
                  color: isMe ? Colors.black : Colors.white,
                  fontSize: 16,
                ),
              ),
            SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.black.withOpacity(0.7) : Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongPreview(Document message, bool isMe) {
    final songId = message.data['song_id'];
    final content = message.data['message'] as String;
    
    // Extract song and artist from message
    String songName = 'Unknown Song';
    String artistName = 'Unknown Artist';
    
    if (content.contains('Check out this song: ')) {
      final parts = content.replaceFirst('Check out this song: ', '').split(' by ');
      if (parts.length >= 2) {
        songName = parts[0];
        artistName = parts[1];
      }
    }
    
    return InkWell(
      onTap: () {
        // Implement playing the song
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.music_note, color: isMe ? Colors.black : Colors.white),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    songName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.black : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    artistName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? Colors.black.withOpacity(0.7) : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.play_circle_fill,
                color: isMe ? Colors.black : Colors.greenAccent,
              ),
              onPressed: () {
                // Implement playing the song
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(String? mediaId, bool isMe) {
    if (mediaId == null) {
      return Container(
        width: 200,
        height: 150,
        color: Colors.grey[850],
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.grey[700]),
        ),
      );
    }
    
    return Container(
      width: 200,
      constraints: BoxConstraints(maxHeight: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: apt.AppwriteService.getFilePreview(mediaId),
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[850],
            child: Center(
              child: CircularProgressIndicator(
                color: isMe ? Colors.black : Colors.greenAccent,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[850],
            child: Center(
              child: Icon(Icons.broken_image, color: Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }
}