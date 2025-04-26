import 'package:flutter/material.dart';
import 'package:appwrite/models.dart';
import 'package:musicgram4/widgets/chat/message_bubble.dart';
import 'package:musicgram4/services/chat_service.dart';

class MessageList extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final ChatService chatService;

  const MessageList({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.chatService,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  List<Document> _messages = [];
  bool _isLoading = false;
  bool _hasMoreMessages = true;
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _scrollController.addListener(_scrollListener);
    
    // Mark conversation as read when opened
    widget.chatService.markConversationAsRead(
      widget.conversationId, 
      widget.currentUserId
    );
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMoreMessages) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _isLoading = true;
    });

    final messages = await widget.chatService.getConversationMessages(
      widget.conversationId,
      limit: 20,
    );

    setState(() {
      _messages = messages;
      _isLoading = false;
      if (messages.isNotEmpty) {
        _lastMessageId = messages.last.$id;
      }
      _hasMoreMessages = messages.length >= 20;
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_lastMessageId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    final messages = await widget.chatService.getConversationMessages(
      widget.conversationId,
      limit: 20,
      lastId: _lastMessageId,
    );

    setState(() {
      _messages = [..._messages, ...messages];
      _isLoading = false;
      if (messages.isNotEmpty) {
        _lastMessageId = messages.last.$id;
      }
      _hasMoreMessages = messages.length >= 20;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true, // Show newest messages at the bottom
          itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _isLoading 
                      ? const CircularProgressIndicator() 
                      : TextButton(
                          onPressed: _loadMoreMessages,
                          child: const Text('Load more messages'),
                        ),
                ),
              );
            }
            
            final message = _messages[index];
            final isCurrentUser = message.data['sender_id'] == widget.currentUserId;
            
            return MessageBubble(
              message: message,
              isCurrentUser: isCurrentUser,
              currentUserId: widget.currentUserId,
            );
          },
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}