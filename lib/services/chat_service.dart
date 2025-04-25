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
    required this.account,
  });
  
  // Update the getOrCreateConversation method to match your exact schema

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
          databaseId: AppConfig.databaseId,
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

      // Create new conversation with EXACT fields from your schema
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
  
  // Update the getUserConversations method

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
  
  // Get messages for a conversation
  Future<List<Document>> getConversationMessages(
    String conversationId, {
    int limit = 30,
  }) async {
    try {
      final result = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: _messagesCollection,
        queries: [
          Query.equal('conversation_id', conversationId),
          Query.orderDesc('created_at'),
          Query.limit(limit),
        ],
      );
      
      return result.documents;
    } catch (e) {
      print('Error getting conversation messages: $e');
      return [];
    }
  }
  
  // Update the sendMessage method to match your chat_message schema

  Future<Document> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      // Create message in chat_messages collection with all required fields
      final result = await databases.createDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: _messagesCollection, // Use the class constant
        documentId: ID.unique(),
        data: {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message': text, // Required field
          'timestamp': DateTime.now().toIso8601String(), // Required field
          'is_read': false,
          'type': 'text', // Required field - assuming 'text' as default type
          'media_id': null, // Optional
          'song_id': null, // Optional
        },
      );
      
      // Update the conversation with last message info in chat_conversations collection
      await databases.updateDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: _chat_conversations, // Use the class constant
        documentId: conversationId,
        data: {
          'last_message': text,
          'last_message_time': DateTime.now().toIso8601String(),
          // Update the sender of the last message if needed
          // 'last_message_sender_id': senderId,
        },
      );
      
      return result;
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }
  
  // Mark a conversation as read for a user
  Future<void> markConversationAsRead(String conversationId, String userId) async {
    try {
      final conversation = await databases.getDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _chat_conversations,
        documentId: conversationId,
      );
      
      final String user1Id = conversation.data['user1_id'];
      
      // Determine which unread field to update
      final String unreadCountField = userId == user1Id ? 'unread_count_1' : 'unread_count_2';
      
      await databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _chat_conversations,
        documentId: conversationId,
        data: {
          unreadCountField: 0,
        },
      );
      
      // Also mark all messages as read
      final batch = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: _messagesCollection,
        queries: [
          Query.equal('conversation_id', conversationId),
          Query.notEqual('sender_id', userId),
          Query.equal('is_read', false),
          Query.limit(100),
        ],
      );
      
      // Update each message's read status
      for (var message in batch.documents) {
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: _messagesCollection,
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
  
  // Get unread message count for a user (previously missing method)
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final conversations = await getUserConversations(userId);
      
      int totalUnread = 0;
      for (var conversation in conversations) {
        final String user1Id = conversation.data['user1_id'];
        final String unreadField = userId == user1Id ? 'unread_count_1' : 'unread_count_2';
        totalUnread += conversation.data[unreadField] as int? ?? 0;
      }
      
      return totalUnread;
    } catch (e) {
      print('Error getting total unread messages: $e');
      return 0;
    }
  }
  
  // Subscribe to new messages in a conversation
  RealtimeSubscription subscribeToMessages(
    String conversationId,
    Function(Document) onNewMessage,
  ) {
    final subscription = realtime.subscribe([
      'databases.${AppConfig.databaseId}.collections.${_messagesCollection}.documents'
    ]);
    
    subscription.stream.listen((response) {
      if (response.events.contains('databases.*.collections.*.documents.*.create')) {
        final document = Document.fromMap(response.payload);
        if (document.data['conversation_id'] == conversationId) {
          onNewMessage(document);
        }
      }
    });
    
    return subscription;
  }
  
  // Link a paired listening session to a conversation
  Future<void> linkPairedSession(String conversationId, String sessionId) async {
    try {
      await databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _chat_conversations,
        documentId: conversationId,
        data: {
          'shared_session_id': sessionId,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error linking paired session: $e');
    }
  }
  
  // Remove paired session link from conversation
  Future<void> unlinkPairedSession(String conversationId) async {
    try {
      await databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _chat_conversations,
        documentId: conversationId,
        data: {
          'shared_session_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error unlinking paired session: $e');
    }
  }
}