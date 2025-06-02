import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/services/appwrite_service.dart' as apt;

class ChatService {
  final Databases databases;
  final Realtime realtime;
  final Account account;
  
  // Use the actual collection names from your Appwrite dashboard
  static const String _chat_conversations = 'chat_conversations';
  static const String _messagesCollection = 'chat_messages';
  
  ChatService({
    required this.databases,
    required this.realtime,
    required this.account, required Storage storage,
  });
  
  Future<Document> getOrCreateConversation(
    String currentUserId, 
    String otherUserId,
    {required String user1Name, required String user2Name}
  ) async {
    try {
      // Try to find existing conversation with these users
      var result = await databases.listDocuments(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        queries: [
          Query.equal('participant1_id', currentUserId),
          Query.equal('participant2_id', otherUserId),
        ],
      );

      // If no conversation found, try the reverse user order
      if (result.documents.isEmpty) {
        result = await databases.listDocuments(
          databaseId: apt.AppConfig.databaseId,
          collectionId: apt.AppConfig.chatchat_conversations,
          queries: [
            Query.equal('participant1_id', otherUserId),
            Query.equal('participant2_id', currentUserId),
          ],
        );
      }

      // If existing conversation found, return it
      if (result.documents.isNotEmpty) {
        return result.documents.first;
      }

      // Create new conversation
      return await databases.createDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: ID.unique(),
        data: {
          'participant1_id': currentUserId,
          'participant2_id': otherUserId,
          'last_message': '',
          'last_message_time': DateTime.now().toIso8601String(),
          'unread_count_p1': 0,
          'unread_count_p2': 0,
          'last_seen_p1': DateTime.now().toIso8601String(),
          'last_seen_p2': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error creating conversation: $e');
      throw e;
    }
  }
  
  Future<List<Document>> getUserConversations(String userId) async {
    try {
      // Get conversations where user is participant1
      final participant1Result = await databases.listDocuments(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        queries: [
          Query.equal('participant1_id', userId),
        ],
      );
      
      // Get conversations where user is participant2
      final participant2Result = await databases.listDocuments(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        queries: [
          Query.equal('participant2_id', userId),
        ],
      );
      
      // Combine results
      List<Document> allConversations = [
        ...participant1Result.documents,
        ...participant2Result.documents,
      ];
      
      return allConversations;
    } catch (e) {
      print('Error getting user conversations: $e');
      return [];
    }
  }
  
  Future<List<Document>> getConversationMessages(String conversationId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId:apt.AppConfig.chatMessagesCollection,
        queries: [
          Query.equal('conversation_id', conversationId),
        ],
      );
      return response.documents;
    } catch (e) {
      print('Error getting conversation messages: $e');
      return [];
    }
  }
  
  Future<Document> sendMessage({
  required String conversationId,
  required String senderId,
  required String text,
}) async {
  try {
    print('ChatService: Sending message to conversation $conversationId: $text');
    
    // Create message in chat_messages collection
    final result = await databases.createDocument(
      databaseId: apt.AppConfig.databaseId,
      collectionId: apt.AppConfig.chatMessagesCollection,
      documentId: ID.unique(),
      data: {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': text,
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': false,
        'type': 'text',
        'media_id': null,
        'song_id': null,
      },
    );
    
    print('ChatService: Message created with ID: ${result.$id}');
    
    // Update conversation's last message info
    try {
      final conversation = await databases.getDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: conversationId,
      );
      
      // Find out if sender is participant1 or participant2
      final String senderId1 = conversation.data['participant1_id'];
      final String senderId2 = conversation.data['participant2_id'];
      final String recipientUnreadField = senderId == senderId1 ? 'unread_count_p2' : 'unread_count_p1';
      final int currentUnread = conversation.data[recipientUnreadField] ?? 0;
      
      // Update conversation with ONLY fields that exist in your schema
      await databases.updateDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: conversationId,
        data: {
          'last_message': text,
          'last_message_time': DateTime.now().toIso8601String(),
          recipientUnreadField: currentUnread + 1,
        },
      );
    } catch (e) {
      print('Error updating conversation last message: $e');
      // Continue even if this fails - the message was still sent
    }
    
    return result;
  } catch (e) {
    print('ChatService: Error sending message: $e');
    throw e;
  }
}
  
// Fix the updateTypingStatus method to use named parameters
Future<void> updateTypingStatus({
  required String conversationId, 
  required String userId, 
  required bool isTyping
}) async {
  try {
    // Fix the syntax error in the data field
    await databases.updateDocument(
      databaseId: apt.AppConfig.databaseId,
      collectionId: apt.AppConfig.chatchat_conversations,
      documentId: conversationId,
      data: {
        'typing_user_id': isTyping ? userId : null,
      },
    );
  } catch (e) {
    print('Error updating typing status: $e');
  }
}  
  Future<void> markConversationAsRead(String conversationId, String userId) async {
    try {
      final conversation = await databases.getDocument(
        databaseId: AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: conversationId,
      );
      
      final isParticipant1 = conversation.data['participant1_id'] == userId;
      final unreadField = isParticipant1 ? 'unread_count_p1' : 'unread_count_p2';
      
      await databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId:apt.AppConfig.chatchat_conversations,
        documentId: conversationId,
        data: {
          unreadField: 0,
        },
      );
      
      // Mark all messages as read
      final messages = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: apt.AppConfig.chatMessagesCollection,
        queries: [
          Query.equal('conversation_id', conversationId),
          Query.notEqual('sender_id', userId),
          Query.equal('is_read', false),
        ],
      );
      
      for (final message in messages.documents) {
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: apt.AppConfig.chatMessagesCollection,
          documentId: message.$id,
          data: {
            'is_read': true,
          },
        );
      }
    } catch (e) {
      print('Error marking conversation as read: $e');
    }
  }
  
  RealtimeSubscription subscribeToMessages(String conversationId, Function(Document) onMessage) {
    final subscription = realtime.subscribe([
      'databases.${AppConfig.databaseId}.collections.${apt.AppConfig.chatMessagesCollection}.documents'
    ]);

    subscription.stream.listen((response) {
      if (response.events.contains('databases.*.collections.*.documents.*.create')) {
        final document = Document.fromMap(response.payload);
        
        // Only process messages for this conversation
        if (document.data['conversation_id'] == conversationId) {
          onMessage(document);
        }
      }
    });

    return subscription;
  }
  
  Future<void> updateMessage({
    required String messageId,
    required String newText,
    required bool edited,
  }) async {
    try {
      await databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: apt.AppConfig.chatMessagesCollection,
        documentId: messageId,
        data: {
          'message': newText,
          'edited': edited,
          'edit_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error updating message: $e');
      throw e;
    }
  }
  
  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      // Delete the message
      await databases.deleteDocument(
        databaseId: AppConfig.databaseId,
        collectionId: apt.AppConfig.chatMessagesCollection,
        documentId: messageId,
      );
      
      // Get the latest message in the conversation after deletion
      final messages = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: apt.AppConfig.chatMessagesCollection,
        queries: [
          Query.equal('conversation_id', conversationId),
          Query.orderDesc('timestamp'),
          Query.limit(1),
        ],
      );
      
      // Update the conversation with the new last message
      if (messages.documents.isNotEmpty) {
        final lastMessage = messages.documents.first;
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: apt.AppConfig.chatchat_conversations,
          documentId: conversationId,
          data: {
            'last_message': lastMessage.data['message'],
            'last_message_time': lastMessage.data['timestamp'],
            'last_message_sender': lastMessage.data['sender_id'],
          },
        );
      } else {
        // No messages left, update with empty data
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: apt.AppConfig.chatchat_conversations,
          documentId: conversationId,
          data: {
            'last_message': '',
            'last_message_time': DateTime.now().toIso8601String(),
            'last_message_sender': '',
          },
        );
      }
    } catch (e) {
      print('Error deleting message: $e');
      throw e;
    }
  }
  
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // Get conversations where user is a participant
      final conversations = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        queries: [
          Query.equal('participant1_id', userId),
          Query.equal('participant2_id', userId),
        ],
      );
      
      int totalUnreadCount = 0;
      
      // Sum up unread counts from all conversations
      for (final conversation in conversations.documents) {
        final isParticipant1 = conversation.data['participant1_id'] == userId;
        final unreadField = isParticipant1 ? 'unread_count_p1' : 'unread_count_p2';
        totalUnreadCount += (conversation.data[unreadField] as int? ?? 0);
      }
      
      return totalUnreadCount;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }
}