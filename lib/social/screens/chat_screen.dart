import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/social/widgets/chatbubble.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:musicgram4/services/appwrite_service.dart' as apt;
import 'package:musicgram4/services/chat_service.dart';

import 'package:flutter/services.dart';

// Search delegate for chat messages
class ChatSearchDelegate extends SearchDelegate<Document> {
  final List<Document> messages;
  final Function(Document) onMessageSelected;
  
  ChatSearchDelegate({required this.messages, required this.onMessageSelected});
  
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }
  
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, messages.isNotEmpty ? messages.first : Document(data: {}, $id: '', $collectionId: '', $databaseId: '', $createdAt: '', $updatedAt: '', $permissions: []));
      },
    );
  }
  
  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }
  
  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }
  
  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return Center(
        child: Text('Type to search messages', style: GoogleFonts.poppins()),
      );
    }
    
    final results = messages.where((message) => 
      message.data['message'].toString().toLowerCase().contains(query.toLowerCase())
    ).toList();
    
    if (results.isEmpty) {
      return Center(
        child: Text('No messages found', style: GoogleFonts.poppins()),
      );
    }
    
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final message = results[index];
        final DateTime timestamp = DateTime.parse(message.data['timestamp']);
        
        return ListTile(
          title: Text(
            message.data['message'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(),
          ),
          subtitle: Text(
            timeago.format(timestamp),
            style: TextStyle(fontSize: 12),
          ),
          onTap: () {
            onMessageSelected(message);
            close(context, message);
          },
        );
      },
    );
  }
}

extension DocumentExt on Document {
  Document copyWith({Map<String, dynamic>? data}) {
    return Document(
      $id: this.$id,
      $collectionId: this.$collectionId,
      $databaseId: this.$databaseId,
      $createdAt: this.$createdAt,
      $updatedAt: this.$updatedAt,
      $permissions: this.$permissions,
      data: data ?? this.data,
    );
  }
}

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
  
  final ChatService _chatService = ChatService(
    databases: apt.AppwriteService.databases,
    realtime: Realtime(apt.AppwriteService.client),
    account: apt.AppwriteService.account,
    storage:apt.AppwriteService.storage,
  );

  // Track processed message IDs to avoid duplicates
  Set<String> _processedMessageIds = {};
  
  String? _currentUserId;
  List<Document> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  bool _isOtherUserTyping = false;
  bool _isRealtimeConnected = false;
  
  RealtimeSubscription? _subscription;
  Timer? _typingTimer;
  Timer? _markAsReadTimer;

  Document? _replyingTo;

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
      
      // Then set up real-time subscription
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

  Future<void> _loadMessages() async {
    if (_currentUserId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Use the chatService to get messages
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
    _subscription?.close();
    
    print('Setting up real-time subscription for ${widget.conversationId}');
    
    _subscription = _chatService.subscribeToMessages(
      widget.conversationId,
      (Document newMessage) {
        print('Received new message via realtime: ${newMessage.data['message']}');
        
        if (!mounted) return;
        
        // CRITICAL FIX: Don't process messages I've sent myself
        // Only process messages from the other user
        if (newMessage.data['sender_id'] == _currentUserId) {
          print('Ignoring my own message from realtime: ${newMessage.$id}');
          return;
        }
        
        // Better duplicate check using our tracked IDs
        if (_processedMessageIds.contains(newMessage.$id)) {
          print('Skipping duplicate message: ${newMessage.$id}');
          return;
        }
        
        // Add to processed set
        _processedMessageIds.add(newMessage.$id);
        
        // Update UI with new message from other user
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
        
        // Mark as read
        _markConversationAsRead();
      },
    );
  }

  void _markConversationAsRead() {
    if (_currentUserId == null) return;
    
    _markAsReadTimer?.cancel();
    _markAsReadTimer = Timer(Duration(milliseconds: 500), () {
      _chatService.markConversationAsRead(widget.conversationId, _currentUserId!);
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    
    _textController.clear();
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Stop typing indicator
      if (_isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        // You would implement typing indicator functionality here
      }
      
      // Send the message
      final newMessage = await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUserId!,
        text: text,
      );
      
      // Track this message ID to prevent duplicates
      _processedMessageIds.add(newMessage.$id);
      
      // Update UI
      setState(() {
        _messages.add(newMessage);
        _isSending = false;
        
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
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _isSending = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleTypingIndicator(String text) {
    if (_currentUserId == null) return;
    
    // Only send typing indicator if we weren't already typing
    if (!_isTyping && text.isNotEmpty) {
      _isTyping = true;
      _chatService.updateTypingStatus(
        conversationId: widget.conversationId, 

        userId: _currentUserId!,

        isTyping: true
        
      );
    }
    
    // Reset the timer to track when user stops typing
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        _chatService.updateTypingStatus(
          conversationId: widget.conversationId, 
          userId: _currentUserId!, 
          isTyping: false
        );
      }
    });
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    }
    
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[500]),
            SizedBox(height: 4),
            Text(
              'Start a conversation',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    // Use a key to force ListView rebuild when messages change
    return ListView.builder(
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
          
          if (currentDate.year != prevDate.year || 
              currentDate.month != prevDate.month || 
              currentDate.day != prevDate.day) {
            showDateHeader = true;
          }
        }
        
        return Column(
          children: [
            if (showDateHeader)
              _buildDateHeader(message),
            
            ChatBubble(
              message: message.data['message'],
              isMe: isMe,
              timestamp: DateTime.parse(message.data['timestamp']),
              isRead: message.data['is_read'] ?? false,
              messageType: messageType,
              onLongPress: () {
                _showMessageOptions(message);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(Document message) {
    final DateTime date = DateTime.parse(message.data['timestamp']);
    final DateTime now = DateTime.now();
    
    String headerText;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      headerText = 'Today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      headerText = 'Yesterday';
    } else {
      headerText = '${date.day}/${date.month}/${date.year}';
    }
    
    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 12),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            headerText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_replyingTo != null) _buildReplyPreview(),
            
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: Colors.grey[700]),
                  onPressed: () {
                    _showAttachmentOptions();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _handleTypingIndicator,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: _textController.text.trim().isEmpty 
                        ? Colors.grey[400] 
                        : Colors.greenAccent,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
 showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.audiotrack, color: Colors.orange),
            title: Text('Audio', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _pickAudio();
            },
          ),
          ListTile(
            leading: Icon(Icons.insert_drive_file, color: Colors.green),
            title: Text('Document', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _pickDocument();
            },
          ),
        ],
      ),
    ),
  );
}

  // Future<void> _pickImage(ImageSource source) async {
  //   try {
  //     final picker = ImagePicker();
  //     final pickedFile = await picker.pickImage(
  //       source: source,
  //       imageQuality: 70,
  //     );
      
  //     if (pickedFile != null) {
  //       setState(() {
  //         _isSending = true;
  //       });
        
  //       // Upload file to storage
  //       final file = await apt.AppwriteService.storage.createFile(
  //         bucketId: 'chat_media',
  //         fileId: ID.unique(),
  //         file: InputFile.fromPath(
  //           path: pickedFile.path,
  //           filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
  //         ),
  //       );
        
  //       // Create preview URL
  //       final fileUrl = apt.AppwriteService.storage.getFileView(
  //         bucketId: 'chat_media',
  //         fileId: file.$id,
  //       );
        
  //       // Send message with image
  //       final newMessage = await _chatService.sendMessage(
  //         conversationId: widget.conversationId,
  //         senderId: _currentUserId!,
  //         text: '',
  //         type: 'image',
  //         fileUrl: fileUrl.toString()
  //       );
        
  //       // Track this message ID to prevent duplicates
  //       _processedMessageIds.add(newMessage.$id);
        
  //       // Update UI
  //       setState(() {
  //         _messages.add(newMessage);
  //         _isSending = false;
          
  //         // Sort messages by timestamp
  //         _messages.sort((a, b) {
  //           final aTime = DateTime.parse(a.data['timestamp']);
  //           final bTime = DateTime.parse(b.data['timestamp']);
  //           return aTime.compareTo(bTime);
  //         });
  //       });
        
  //       // Scroll to bottom
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         if (_scrollController.hasClients) {
  //           _scrollController.animateTo(
  //             _scrollController.position.maxScrollExtent,
  //             duration: Duration(milliseconds: 300),
  //             curve: Curves.easeOut,
  //           );
  //         }
  //       });
  //     }
  //   } catch (e) {
  //     print('Error picking image: $e');
  //     setState(() {
  //       _isSending = false;
  //     });
  //   }
  // }

  Future<void> _pickAudio() async {
  // Note: To implement this, you'll need to add the file_picker package:
  // file_picker: ^5.2.0+1
  
  // Uncomment after adding the package:
  // try {
  //   FilePickerResult? result = await FilePicker.platform.pickFiles(
  //     type: FileType.audio,
  //   );
  //
  //   if (result != null && result.files.single.path != null) {
  //     setState(() {
  //       _isSending = true;
  //     });
  //
  //     // Upload to storage
  //     final file = await apt.AppwriteService.storage.createFile(
  //       bucketId: 'chat_media',
  //       fileId: ID.unique(),
  //       file: InputFile.fromPath(
  //         path: result.files.single.path!,
  //         filename: result.files.single.name,
  //       ),
  //     );
  //
  //     // Get file URL
  //     final fileUrl = apt.AppwriteService.storage.getFileView(
  //       bucketId: 'chat_media',
  //       fileId: file.$id,
  //     );
  //
  //     // Send message with audio
  //     final newMessage = await _chatService.sendMessage(
  //       conversationId: widget.conversationId,
  //       senderId: _currentUserId!,
  //       text: '🎵 Audio',
  //       type: 'audio',
  //       fileUrl: fileUrl,
  //     );
  //
  //     // Update UI
  //     _processedMessageIds.add(newMessage.$id);
  //     setState(() {
  //       _messages.add(newMessage);
  //       _isSending = false;
  //     });
  //
  //     _scrollToBottom();
  //   }
  // } catch (e) {
  //   print('Error picking audio: $e');
  //   setState(() {
  //     _isSending = false;
  //   });
  //   _showErrorSnackbar('Failed to send audio. Please try again.');
  // }
  
  // For now, show a placeholder message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Audio picker not implemented yet')),
  );
}

Future<void> _pickDocument() async {
  // Note: Uses the same file_picker package mentioned above
  
  // Uncomment after adding the package:
  // try {
  //   FilePickerResult? result = await FilePicker.platform.pickFiles();
  //
  //   if (result != null && result.files.single.path != null) {
  //     setState(() {
  //       _isSending = true;
  //     });
  //
  //     // Upload to storage
  //     final file = await apt.AppwriteService.storage.createFile(
  //       bucketId: 'chat_media',
  //       fileId: ID.unique(),
  //       file: InputFile.fromPath(
  //         path: result.files.single.path!,
  //         filename: result.files.single.name,
  //       ),
  //     );
  //
  //     // Get file URL
  //     final fileUrl = apt.AppwriteService.storage.getFileView(
  //       bucketId: 'chat_media',
  //       fileId: file.$id,
  //     );
  //
  //     // Send message with document
  //     final newMessage = await _chatService.sendMessage(
  //       conversationId: widget.conversationId,
  //       senderId: _currentUserId!,
  //       text: '📄 Document: ${result.files.single.name}',
  //       type: 'document',
  //       fileUrl: fileUrl,
  //     );
  //
  //     // Update UI
  //     _processedMessageIds.add(newMessage.$id);
  //     setState(() {
  //       _messages.add(newMessage);
  //       _isSending = false;
  //     });
  //   }
  // } catch (e) {
  //   print('Error picking document: $e');
  //   setState(() {
  //     _isSending = false;
  //   });
  //   _showErrorSnackbar('Failed to send document. Please try again.');
  // }
  
  // For now, show a placeholder message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Document picker not implemented yet')),
  );
}

void _showSearchView() {
  showSearch(
    context: context,
    delegate: ChatSearchDelegate(
      messages: _messages,
      onMessageSelected: (Document message) {
        // Find the message in the list and scroll to it
        final index = _messages.indexWhere((m) => m.$id == message.$id);
        if (index >= 0 && _scrollController.hasClients) {
          _scrollController.animateTo(
            index * 70.0, // Approximate height of each message
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          if (widget.otherUserAvatar != null)
            CircleAvatar(
              backgroundImage: NetworkImage(widget.otherUserAvatar!),
              radius: 16,
            ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.otherUserName,
                  style: GoogleFonts.poppins(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isOtherUserTyping)
                  Text(
                    'typing...',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: _showSearchView,
        ),
        IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: _showChatOptions,
        ),
      ],
    ),
    body: Column(
      children: [
        // Show connection status indicator
        if (!_isRealtimeConnected)
          Container(
            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 16),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange[800]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Connecting to chat service...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Messages list
        Expanded(child: _buildMessagesList()),
        
        // Message input with reply preview
        _buildMessageInput(),
      ],
    ),
  );
}

void _showChatOptions() {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.search),
            title: Text('Search in conversation', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _showSearchView();
            },
          ),
          ListTile(
            leading: Icon(Icons.image),
            title: Text('Media, files and links', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _showMediaGallery();
            },
          ),
          ListTile(
            leading: Icon(Icons.block, color: Colors.red),
            title: Text('Block user', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _showBlockUserConfirmation();
            },
          ),
          ListTile(
            leading: Icon(Icons.report_outlined, color: Colors.orange),
            title: Text('Report', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Report functionality not implemented yet')),
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildReplyPreview() {
  if (_replyingTo == null) return SizedBox.shrink();
  
  final isMe = _replyingTo!.data['sender_id'] == _currentUserId;
  final name = isMe ? 'You' : widget.otherUserName;
  
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: Colors.grey[100],
    child: Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reply to $name',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.greenAccent[700],
                ),
              ),
              SizedBox(height: 2),
              Text(
                _replyingTo!.data['message'],
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 16),
          onPressed: _cancelReply,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
      ],
    ),
  );
}

void _cancelReply() {
  setState(() {
    _replyingTo = null;
  });
}

void _replyToMessage(Document message) {
  setState(() {
    _replyingTo = message;
    _focusNode.requestFocus();
  });
}

void _showEditMessageDialog(Document message) {
  final TextEditingController editController = TextEditingController(
    text: message.data['message'],
  );
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Edit Message', style: GoogleFonts.poppins()),
      content: TextField(
        controller: editController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Edit your message',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('Save'),
          onPressed: () async {
            final newText = editController.text.trim();
            if (newText.isEmpty || newText == message.data['message']) {
              Navigator.pop(context);
              return;
            }
            
            Navigator.pop(context);
            
            try {
              // Update the message in the database
              await _chatService.updateMessage(
                messageId: message.$id,
                newText: newText,
                edited: true,
              );
              
              // Update local message list
              setState(() {
                final index = _messages.indexWhere((m) => m.$id == message.$id);
                if (index >= 0) {
                  _messages[index] = _messages[index].copyWith(
                    data: {
                      ..._messages[index].data,
                      'message': newText,
                      'edited': true,
                    },
                  );
                }
              });
            } catch (e) {
              print('Error editing message: $e');
              _showErrorSnackbar('Failed to edit message. Please try again.');
            }
          },
        ),
      ],
    ),
  );
}

void _confirmDeleteMessage(Document message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete Message?', style: GoogleFonts.poppins()),
      content: Text(
        'This message will be deleted for everyone. This action cannot be undone.',
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('Delete', style: TextStyle(color: Colors.red)),
          onPressed: () async {
            Navigator.pop(context);
            
            try {
              await _chatService.deleteMessage(
                messageId: message.$id,
                conversationId: widget.conversationId,
              );
              
              // Update local message list
              setState(() {
                _messages.removeWhere((m) => m.$id == message.$id);
              });
            } catch (e) {
              print('Error deleting message: $e');
              _showErrorSnackbar('Failed to delete message. Please try again.');
            }
          },
        ),
      ],
    ),
  );
}

void _showErrorSnackbar(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}

void _scrollToBottom() {
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

void _showMediaGallery() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      // Filter only media messages
      final mediaMessages = _messages.where((m) => 
        m.data['type'] == 'image' || m.data['type'] == 'video'
      ).toList();
      
      if (mediaMessages.isEmpty) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No media in this conversation',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      }
      
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Media Gallery',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: mediaMessages.length,
                itemBuilder: (context, index) {
                  final message = mediaMessages[index];
                  final fileUrl = message.data['file_url'];
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      // Show full-screen image viewer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              backgroundColor: Colors.black,
                              iconTheme: IconThemeData(color: Colors.white),
                            ),
                            backgroundColor: Colors.black,
                            body: Center(
                              child: InteractiveViewer(
                                child: Image.network(
                                  fileUrl,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(fileUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showBlockUserConfirmation() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block ${widget.otherUserName}?', style: GoogleFonts.poppins()),
      content: Text(
        'Blocking this user will prevent them from messaging you. They won\'t be able to see your profile or posts.',
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('Block', style: TextStyle(color: Colors.red)),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Block functionality not implemented yet')),
            );
            // In a real implementation, you would call a method to block the user
            // and then navigate back to the conversations list
          },
        ),
      ],
    ),
  );
}

Future<void> _saveMedia(Document message) async {
  try {
    final String fileUrl = message.data['file_url'];
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image saving functionality not implemented yet')),
    );
    
    // In a real implementation, you would download and save the image
    // using packages like image_gallery_saver and http
  } catch (e) {
    print('Error saving media: $e');
    _showErrorSnackbar('Failed to save image. Please try again.');
  }
}

void _showMessageOptions(Document message) {
  final bool isMe = message.data['sender_id'] == _currentUserId;
  
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Copy Message', style: GoogleFonts.poppins()),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.data['message']));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message copied to clipboard')),
                );
              },
            ),
            if (isMe && message.data['type'] == 'text')
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Message', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _showEditMessageDialog(message);
                },
              ),
            if (isMe)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Delete Message', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(message);
                },
              ),
            ListTile(
              leading: Icon(Icons.reply),
              title: Text('Reply', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(message);
              },
            ),
            if (message.data['type'] == 'image')
              ListTile(
                leading: Icon(Icons.download),
                title: Text('Save Image', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _saveMedia(message);
                },
              ),
          ],
        ),
      );
    },
  );
}
}