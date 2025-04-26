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
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List<Document> _messages = [];
  String? _currentUserId;
  bool _isLoading = true;
  bool _isSending = false;
  Document? _conversation;
  
  RealtimeSubscription? _subscription;
  Timer? _markAsReadTimer;
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _isRealtimeConnected = false;
  
  final ChatService _chatService = ChatService(
    databases: apt.AppwriteService.databases,
    realtime: Realtime(apt.AppwriteService.client),
    account: apt.AppwriteService.account,
  );

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }
  
  @override
  void dispose() {
    _subscription?.close();
    _markAsReadTimer?.cancel();
    _typingTimer?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await apt.AppwriteService.account.get();
      setState(() {
        _currentUserId = user.$id;
      });
      
      // Load messages first
      await _loadMessages();
      
      // Then set up real-time subscription - THIS IS CRITICAL
      _setupRealTimeListener();
      
      // Mark messages as read
      _markConversationAsRead();
    } catch (e) {
      print('Error loading current user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadConversation() async {
    try {
      _conversation = await apt.AppwriteService.databases.getDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: widget.conversationId,
      );
    } catch (e) {
      print('Error loading conversation: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (_currentUserId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Use the chatService to get messages instead of direct database calls
      final messages = await _chatService.getConversationMessages(widget.conversationId);
      
      setState(() {
        // Sort messages by timestamp to ensure correct order
        _messages = messages..sort((a, b) {
          final aTime = DateTime.parse(a.data['timestamp']);
          final bTime = DateTime.parse(b.data['timestamp']);
          return aTime.compareTo(bTime); // Ascending order - oldest first
        });
        _isLoading = false;
      });
      
      // Scroll to bottom
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add this method to set up the real-time subscription
  void _setupRealTimeListener() {
    // Close any existing subscription
    _subscription?.close();
    
    print('Setting up real-time subscription for ${widget.conversationId}');
    
    // Use the updated subscribeToMessages method
    _subscription = _chatService.subscribeToMessages(
      widget.conversationId,
      (Document newMessage) {
        print('Received new message via realtime: ${newMessage.data['message']}');
        
        if (!mounted) return;
        
        // Check for duplicates
        final exists = _messages.any((msg) => msg.$id == newMessage.$id);
        
        if (!exists) {
          setState(() {
            _messages.add(newMessage);
            
            // Sort messages by timestamp
            _messages.sort((a, b) {
              final aTime = DateTime.parse(a.data['timestamp']);
              final bTime = DateTime.parse(b.data['timestamp']);
              return aTime.compareTo(bTime);
            });
          });
          
          // Scroll to bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
          
          // Mark as read if from other user
          if (newMessage.data['sender_id'] == widget.otherUserId) {
            _markConversationAsRead();
          }
        }
      },
    );
  }

  void _markConversationAsRead() {
    _markAsReadTimer?.cancel();
    _markAsReadTimer = Timer(Duration(seconds: 1), () async {
      await _chatService.markConversationAsRead(
        widget.conversationId,
        _currentUserId!,
      );
    });
  }

  void _handleTyping(String text) {
    _typingTimer?.cancel();
    
    if (text.isNotEmpty && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
      
      // Send typing indicator to the other user
      _chatService.updateTypingStatus(widget.conversationId, _currentUserId!, true);
    }
    
    _typingTimer = Timer(Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() {
          _isTyping = false;
        });
        
        // Stop typing indicator
        _chatService.updateTypingStatus(widget.conversationId, _currentUserId!, false);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    
    // Clear text field immediately for better UX
    _textController.clear();
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Stop typing indicator
      if (_isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        _chatService.updateTypingStatus(widget.conversationId, _currentUserId!, false);
      }
      
      // Send the message
      final newMessage = await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUserId!,
        text: text,
      );
      
      // IMPORTANT: Update local state immediately without waiting for subscription
      // This creates instant feedback
      if (mounted) {
        setState(() {
          // Add sent message to list
          _messages.add(newMessage);
          
          // Sort messages by timestamp
          _messages.sort((a, b) {
            DateTime aTime = DateTime.parse(a.data['timestamp']);
            DateTime bTime = DateTime.parse(b.data['timestamp']);
            return aTime.compareTo(bTime);
          });
        });
        
        // Scroll to bottom to show new message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
             CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty
                ? CachedNetworkImageProvider(
                    apt.AppwriteService.getFilePreview(widget.otherUserAvatar!),
                    errorListener: (err) {
                      print('Failed to load avatar image');
                    },
                  )
                : null,
              child: widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty
                ? Text(
                    widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  )
                : null,
            ),
            Text(widget.otherUserName),
            SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRealtimeConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        // title: Row(
        //   children: [
        //     CircleAvatar(
        //       radius: 16,
        //       backgroundColor: Colors.grey[800],
        //       backgroundImage: widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty
        //         ? CachedNetworkImageProvider(
        //             apt.AppwriteService.getFilePreview(widget.otherUserAvatar!),
        //             errorListener: (err) {
        //               print('Failed to load avatar image');
        //             },
        //           )
        //         : null,
        //       child: widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty
        //         ? Text(
        //             widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
        //             style: TextStyle(fontSize: 14, color: Colors.white),
        //           )
        //         : null,
        //     ),
        //     SizedBox(width: 8),
        //     Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(
        //           widget.otherUserName,
        //           style: GoogleFonts.poppins(
        //             fontSize: 16,
        //             fontWeight: FontWeight.w500,
        //           ),
        //         ),
        //         Text(
        //           'Online', // You can replace this with actual online status
        //           style: TextStyle(fontSize: 12, color: Colors.greenAccent),
        //         ),
        //       ],
        //     ),
        //   ],
        // ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.grey[900],
                builder: (context) => _buildOptionsSheet(),
              );
            },
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                   
                  ),
                  child: _buildMessagesList(),
                ),
              ),
              _buildInputArea(),
            ],
          ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      // Add this key to force proper rebuilding when messages change
      key: ValueKey<int>(_messages.length),
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final bool isMe = message.data['sender_id'] == _currentUserId;
        final String messageType = message.data['type'] ?? 'text';
        
        // Check if we should show date header
        bool showDateHeader = false;
        if (index == 0) {
          showDateHeader = true;
        } else {
          final DateTime currentDate = DateTime.parse(message.data['timestamp']);
          final DateTime prevDate = DateTime.parse(_messages[index - 1].data['timestamp']);
          if (!_isSameDay(currentDate, prevDate)) {
            showDateHeader = true;
          }
        }
        
        return Column(
          children: [
            if (showDateHeader)
              _buildDateHeader(DateTime.parse(message.data['timestamp'])),
            _buildMessageBubble(
              message: message,
              isMe: isMe,
              messageType: messageType,
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildDateHeader(DateTime date) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[800]!.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatHeaderDate(date),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }
  
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  Widget _buildMessageBubble({
    required Document message,
    required bool isMe,
    required String messageType,
  }) {
    final content = message.data['message'] as String;
    final time = DateFormat('HH:mm').format(DateTime.parse(message.data['timestamp']));
    final isRead = message.data['is_read'] == true;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: messageType == 'text'
            ? EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : EdgeInsets.all(8),
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (messageType == 'text')
              Text(
                content,
                style: GoogleFonts.poppins(
                  color: isMe ? Colors.black : Colors.white,
                  fontSize: 15,
                ),
              )
            else if (messageType == 'song')
              _buildSongPreview(message)
            else if (messageType == 'image')
              _buildImagePreview(message.data['media_id']),
              
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.black.withOpacity(0.7) : Colors.grey[400],
                  ),
                ),
                if (isMe)
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 12,
                      color: isRead ? Colors.blue : Colors.black.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSongPreview(Document message) {
    // Implement song preview card - will depend on your Song data structure
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, color: Colors.white),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Song preview', // Replace with actual song title
              style: TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImagePreview(String? mediaId) {
    if (mediaId == null || mediaId.isEmpty) return SizedBox();
    
    return Container(
      height: 180,
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: apt.AppwriteService.getFilePreview(mediaId),
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: Icon(Icons.broken_image, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.greenAccent),
            onPressed: () {
              // Show attachment options
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.grey[900],
                builder: (context) => _buildAttachmentSheet(),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: TextStyle(color: Colors.white),
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _handleTyping,
            ),
          ),
          SizedBox(width: 8),
          _isSending
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.greenAccent,
                ),
              )
            : IconButton(
                icon: Icon(Icons.send, color: Colors.greenAccent),
                onPressed: _sendMessage,
              ),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentSheet() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share content',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentOption(
                icon: Icons.image,
                label: 'Image',
                onTap: () {
                  Navigator.pop(context);
                  // Implement image picking
                },
              ),
              _buildAttachmentOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  // Implement camera capture
                },
              ),
              _buildAttachmentOption(
                icon: Icons.music_note,
                label: 'Song',
                onTap: () {
                  Navigator.pop(context);
                  // Implement song sharing
                },
              ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.greenAccent, size: 28),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionsSheet() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOptionTile(
            icon: Icons.delete,
            title: 'Delete conversation',
            subtitle: 'This will delete all messages',
            onTap: () {
              // Implement delete conversation
              Navigator.pop(context);
              _showDeleteConfirmation();
            },
            isDestructive: true,
          ),
          _buildOptionTile(
            icon: Icons.block,
            title: 'Block user',
            subtitle: 'Stop receiving messages',
            onTap: () {
              // Implement block user
              Navigator.pop(context);
            },
            isDestructive: true,
          ),
          _buildOptionTile(
            icon: Icons.volume_off,
            title: 'Mute notifications',
            subtitle: 'Stop receiving alerts',
            onTap: () {
              // Implement mute
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }
  
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Delete conversation',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              Navigator.pop(context);
              // Implement delete conversation logic
              // Then navigate back to conversations list
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}