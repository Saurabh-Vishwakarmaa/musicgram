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

  // Add this method to your ChatService class
  Future<void> updateTypingStatus(String conversationId, String userId, bool isTyping) async {
    try {
      // Update the typing status in the conversation document
      // You might need to adjust this based on your database schema
      await databases.updateDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: conversationId,
        data: {
          isTyping ? 'typing_user_id' : 'typing_user_id': isTyping ? userId : null,
        },
      );
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }
  
  // Get messages for a conversation
  Future<List<Document>> getConversationMessages(
    String conversationId, {
    int limit = 30,
    String? lastId, // For pagination
  }) async {
    try {
      List<String> queries = [
        Query.equal('conversation_id', conversationId),
        Query.orderAsc('timestamp'), // Use ascending order for chronological display
        Query.limit(limit),
      ];
      
      // Add cursor pagination if lastId is provided
      if (lastId != null) {
        queries.add(Query.cursorAfter(lastId));
      }
      
      final result = await databases.listDocuments(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatMessagesCollection,
        queries: queries,
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
      
      // IMPORTANT: Also update the conversation's last message info
      // This helps with displaying conversation previews
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
        
        // Update conversation with last message details and increment unread count
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
  
  // Mark a conversation as read for a user
  Future<void> markConversationAsRead(String conversationId, String userId) async {
    try {
      final conversation = await databases.getDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: conversationId,
      );
      
      // Check if the conversation uses participant1_id/participant2_id or user1_id/user2_id
      final bool hasParticipant1Field = conversation.data.containsKey('participant1_id');
      
      // Determine which fields to use based on schema
      final String user1IdField = hasParticipant1Field ? 'participant1_id' : 'user1_id';
      final String user2IdField = hasParticipant1Field ? 'participant2_id' : 'user2_id';
      final String unreadCount1Field = hasParticipant1Field ? 'unread_count_p1' : 'unread_count_1';
      final String unreadCount2Field = hasParticipant1Field ? 'unread_count_p2' : 'unread_count_2';
      
      // Check which participant this user is
      final bool isFirstUser = conversation.data[user1IdField] == userId;
      final String unreadCountField = isFirstUser ? unreadCount1Field : unreadCount2Field;
      
      print('Marking conversation $conversationId as read for user $userId (field: $unreadCountField)');
      
      // Update the unread counter
      await databases.updateDocument(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatchat_conversations,
        documentId: conversationId,
        data: {
          unreadCountField: 0,
        },
      );
      
      // Mark all messages from the other user as read
      final batch = await databases.listDocuments(
        databaseId: apt.AppConfig.databaseId,
        collectionId: apt.AppConfig.chatMessagesCollection,
        queries: [
          Query.equal('conversation_id', conversationId),
          Query.notEqual('sender_id', userId),
          Query.equal('is_read', false),
          Query.limit(100),
        ],
      );
      
      print('Marking ${batch.documents.length} messages as read');
      
      // Update each message's read status
      for (var message in batch.documents) {
        await databases.updateDocument(
          databaseId: apt.AppConfig.databaseId,
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
  
   // Replace your current subscribeToMessages method with this improved version
  RealtimeSubscription subscribeToMessages(
    String conversationId,
    Function(Document) onNewMessage,
  ) {
    final subscription = realtime.subscribe([
      'databases.${apt.AppConfig.databaseId}.collections.${apt.AppConfig.chatMessagesCollection}.documents'
    ]);
    
    subscription.stream.listen((response) {
      if (response.events.contains('databases.*.collections.*.documents.*.create')) {
        // This is the key fix: Use Document.fromMap instead of creating document manually
        try {
          final document = Document.fromMap(response.payload);
          
          // Check if this message belongs to our conversation
          if (document.data['conversation_id'] == conversationId) {
            // Call the callback with the new document
            onNewMessage(document);
          }
        } catch (e) {
          print('Error parsing real-time document: $e');
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