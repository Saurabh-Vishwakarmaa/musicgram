import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:http/http.dart';
import 'package:musicgram4/configs/appwritecongif.dart';

import '../models/user.dart'; // You'll need to create this model

class SocialDatabaseService {
  final Databases _databases;
  final Storage _storage;
  final Account _account;
  
  // Collection IDs - match exactly with what's in Appwrite
  static const String _profilesCollection = '68065fc1000215395c66'; // Your user_profiles collection ID
  static const String _connectionsCollection = 'social_connections';
  static const String _invitationsCollection = 'invitations';
  static const String _pairedSessionsCollection = 'paired_sessions';
  static const String _activitiesCollection = 'user_activities';
  
  SocialDatabaseService({
    required Databases databases,
    required Storage storage,
    required Account account,
  }) : _databases = databases,
       _storage = storage,
       _account = account;
  
  // USER PROFILE OPERATIONS
  
  /// Creates a new user profile
  Future<Document> createUserProfile({
    required String userId,
    required String username,
    required String displayName,
    String? bio,
    String? avatarFileId,
  }) async {
    print('Calling createUserProfile with databaseId: ${AppConfig.databaseId}, collectionId: $_profilesCollection');
    return await _databases.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: _profilesCollection,
      documentId: userId, // Use userId as the document ID for easy lookup
      data: {
        'user_id': userId,
        'username': username,
        'display_name': displayName,
        'bio': bio ?? '',
        'avatar_file_id': avatarFileId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'followers_count': 0,
        'following_count': 0,
      },
    );
  }
  
  /// Updates an existing user profile
  Future<Document> updateUserProfile({
    required String userId,
    String? username,
    String? displayName,
    String? bio,
    String? avatarFileId,
    int? followersCount,
    int? followingCount,
  }) async {
    print('Calling updateUserProfile with databaseId: ${AppConfig.databaseId}, collectionId: $_profilesCollection');
    Map<String, dynamic> data = {
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (username != null) data['username'] = username;
    if (displayName != null) data['display_name'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (avatarFileId != null) data['avatar_file_id'] = avatarFileId;
    if (followersCount != null) data['followers_count'] = followersCount;
    if (followingCount != null) data['following_count'] = followingCount;
    
    return await _databases.updateDocument(
      databaseId: AppConfig.databaseId,
      collectionId: _profilesCollection,
      documentId: userId,
      data: data,
    );
  }
  
  /// Get a user profile by user ID
  Future<Document> getUserProfile(String userId) async {
    print('Calling getUserProfile with databaseId: ${AppConfig.databaseId}, collectionId: $_profilesCollection');
    
    try {
      return await _databases.getDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _profilesCollection,
        documentId: userId,  // Assumes document ID = user ID
      );
    } catch (e) {
      print('Error in getUserProfile: $e');
      rethrow;
    }
  }
  
  /// Search for users by username or display name
  Future<List<Document>> searchUsers(String query) async {
    print('Calling searchUsers with databaseId: ${AppConfig.databaseId}, collectionId: $_profilesCollection');
    final result = await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: _profilesCollection,
      queries: [
        Query.search('username', query),
        Query.search('display_name', query),
      ],
    );
    
    return result.documents;
  }
  
  /// Upload a profile image
  Future<File> uploadProfileImage(MultipartFile file, String userId) async {
    return await _storage.createFile(
      bucketId: 'profile_pictures', // Ensure this bucket exists in Appwrite
      fileId: ID.unique(),
      file: InputFile.fromBytes(
        bytes: await file.finalize().toBytes(),
        filename: file.filename ?? 'profile_image.jpg',
      ),
    );
  }

  /// Check if a username is already taken by another user
  Future<bool> isUsernameTaken(String username, String currentUserId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: _profilesCollection,
        queries: [
          Query.equal('username', username),
          Query.notEqual('user_id', currentUserId),
        ],
      );
      
      return result.documents.isNotEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false; // Default to false if there's an error
    }
  }

  // SOCIAL CONNECTION OPERATIONS
  
  /// Follow a user
  Future<Document> followUser({
    required String followerId,
    required String followeeId,
  }) async {
    // First create the connection
    final connection = await _databases.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: _connectionsCollection,
      documentId: ID.unique(),
      data: {
        'follower_id': followerId,
        'followee_id': followeeId,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
    
    // Then update the follower count for the followee (the person being followed)
    try {
      final followeeProfile = await getUserProfile(followeeId);
      final currentFollowersCount = followeeProfile.data['followers_count'] as int? ?? 0;
      
      await _databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _profilesCollection,
        documentId: followeeId,
        data: {
          'followers_count': currentFollowersCount + 1,
        },
      );
      
      // Update following count for the follower
      final followerProfile = await getUserProfile(followerId);
      final currentFollowingCount = followerProfile.data['following_count'] as int? ?? 0;
      
      await _databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _profilesCollection,
        documentId: followerId,
        data: {
          'following_count': currentFollowingCount + 1,
        },
      );
      
      print('Updated follower and following counts successfully');
      
    } catch (e) {
      print('Error updating follower counts: $e');
      // Continue since the connection was made
    }
    
    return connection;
  }

  /// Unfollow a user
  Future<void> unfollowUser({
    required String followerId,
    required String followeeId,
  }) async {
    // Find and delete the connection first
    final connections = await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: _connectionsCollection,
      queries: [
        Query.equal('follower_id', followerId),
        Query.equal('followee_id', followeeId),
      ],
    );
    
    if (connections.documents.isNotEmpty) {
      // Delete the connection
      await _databases.deleteDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _connectionsCollection,
        documentId: connections.documents.first.$id,
      );
      
      // Update follower count for the followee
      try {
        final followeeProfile = await getUserProfile(followeeId);
        final currentFollowersCount = followeeProfile.data['followers_count'] as int? ?? 0;
        
        await _databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: _profilesCollection,
          documentId: followeeId,
          data: {
            'followers_count': max(0, currentFollowersCount - 1),
          },
        );
        
        // Update following count for the follower
        final followerProfile = await getUserProfile(followerId);
        final currentFollowingCount = followerProfile.data['following_count'] as int? ?? 0;
        
        await _databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: _profilesCollection,
          documentId: followerId,
          data: {
            'following_count': max(0, currentFollowingCount - 1),
          },
        );
        
        print('Updated follower and following counts successfully');
        
      } catch (e) {
        print('Error updating follower counts: $e');
        // Continue since the connection was deleted
      }
    }
  }
  
  /// Update follower and following counts for both users
  Future<void> _updateFollowCounts(
    String followerId, 
    String followeeId, 
    {bool isUnfollow = false}
  ) async {
    print('Calling _updateFollowCounts with databaseId: ${AppConfig.databaseId}, collectionId: $_profilesCollection');
    // Get current follower profile
    final followerProfile = await getUserProfile(followerId);
    
    // Get current followee profile
    final followeeProfile = await getUserProfile(followeeId);
    
    // Update follower's following count
    int followingCount = followerProfile.data['following_count'] ?? 0;
    followingCount = isUnfollow ? followingCount - 1 : followingCount + 1;
    followingCount = followingCount < 0 ? 0 : followingCount;
    
    // Update followee's followers count
    int followersCount = followeeProfile.data['followers_count'] ?? 0;
    followersCount = isUnfollow ? followersCount - 1 : followersCount + 1;
    followersCount = followersCount < 0 ? 0 : followersCount;
    
    // Update both profiles
    await updateUserProfile(
      userId: followerId,
      username: null,
      displayName: null,
      bio: null,
      avatarFileId: null,
    );
    
    await updateUserProfile(
      userId: followeeId,
      username: null,
      displayName: null,
      bio: null,
      avatarFileId: null,
    );
  }
  
  /// Get a user's followers
  Future<List<Document>> getFollowers(String userId) async {
    print('Calling getFollowers with databaseId: ${AppConfig.databaseId}, collectionId: $_connectionsCollection');
    final result = await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: _connectionsCollection,
      queries: [Query.equal('followee_id', userId)],
    );
    
    return result.documents;
  }
  
  /// Get users that a user is following
  Future<List<Document>> getFollowing(String userId) async {
    print('Calling getFollowing with databaseId: ${AppConfig.databaseId}, collectionId: $_connectionsCollection');
    final result = await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: _connectionsCollection,
      queries: [Query.equal('follower_id', userId)],
    );
    
    return result.documents;
  }
  
  // PAIRED LISTENING OPERATIONS
  
  /// Create a paired listening session
  Future<Document> createPairedSession({
    required String hostUserId,
    required String guestUserId,
    required String songId,
  }) async {
    print('Calling createPairedSession with databaseId: ${AppConfig.databaseId}, collectionId: $_pairedSessionsCollection');
    return await _databases.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: _pairedSessionsCollection,
      documentId: ID.unique(),
      data: {
        'host_user_id': hostUserId,
        'guest_user_id': guestUserId,
        'song_id': songId,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'ended_at': null,
      },
    );
  }
  
  /// End a paired listening session
  Future<Document> endPairedSession(String sessionId) async {
    print('Calling endPairedSession with databaseId: ${AppConfig.databaseId}, collectionId: $_pairedSessionsCollection');
    return await _databases.updateDocument(
      databaseId: AppConfig.databaseId,
      collectionId: _pairedSessionsCollection,
      documentId: sessionId,
      data: {
        'status': 'ended',
        'ended_at': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Get active paired sessions for a user
  Future<List<Document>> getActivePairedSessions(String userId) async {
    print('Calling getActivePairedSessions with databaseId: ${AppConfig.databaseId}, collectionId: $_pairedSessionsCollection');
    final result = await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: _pairedSessionsCollection,
      queries: [
        Query.equal('status', 'active'),
        Query.equal('host_user_id', userId),
        Query.equal('guest_user_id', userId),
      ],
    );
    
    return result.documents;
  }
  
  // INVITATION OPERATIONS
  
  /// Send an invitation to join the platform
  Future<Document> sendInvitation({
    required String senderId,
    required String recipientEmail,
    String? personalMessage,
  }) async {
    print('Calling sendInvitation with databaseId: ${AppConfig.databaseId}, collectionId: $_invitationsCollection');
    return await _databases.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: _invitationsCollection,
      documentId: ID.unique(),
      data: {
        'sender_id': senderId,
        'recipient_email': recipientEmail,
        'personal_message': personalMessage ?? '',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
        'accepted_at': null,
      },
    );
  }
  
  /// Update invitation status when accepted
  Future<Document> acceptInvitation(String invitationId, String newUserId) async {
    print('Calling acceptInvitation with databaseId: ${AppConfig.databaseId}, collectionId: $_invitationsCollection');
    return await _databases.updateDocument(
      databaseId: AppConfig.databaseId,
      collectionId: _invitationsCollection,
      documentId: invitationId,
      data: {
        'status': 'accepted',
        'new_user_id': newUserId,
        'accepted_at': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Get all invitations sent by a user
  Future<List<Document>> getSentInvitations(String userId) async {
    print('Calling getSentInvitations with databaseId: ${AppConfig.databaseId}, collectionId: $_invitationsCollection');
    final result = await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: _invitationsCollection,
      queries: [Query.equal('sender_id', userId)],
    );
    
    return result.documents;
  }

  Future<List<Document>> getUserActivities(String userId) async {
    print('Calling getUserActivities with databaseId: ${AppConfig.databaseId}, collectionId: $_activitiesCollection');
    // Temporary workaround
    return [];
    
    /* Comment out until fixed:
    try {
      final result = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: _activitiesCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('created_at'),
          Query.limit(20),
        ],
      );
      return result.documents;
    } catch (e) {
      print('Error fetching user activities: $e');
      return [];
    }
    */
  }

  /// Increment followers count for a user
  Future<void> _incrementFollowersCount(String userId) async {
    final profile = await getUserProfile(userId);
    final currentCount = profile.data['followers_count'] as int? ?? 0;
    
    await updateUserProfile(
      userId: userId,
      followersCount: currentCount + 1,
    );
  }

  /// Decrement followers count for a user
  Future<void> _decrementFollowersCount(String userId) async {
    final profile = await getUserProfile(userId);
    final currentCount = profile.data['followers_count'] as int? ?? 0;
    await updateUserProfile(
      userId: userId,
      followersCount: max(0, currentCount - 1),
    );
    
  }

  /// Increment following count for a user
  Future<void> _incrementFollowingCount(String userId) async {
    final profile = await getUserProfile(userId);
    final currentCount = profile.data['following_count'] as int? ?? 0;
    
    await updateUserProfile(
      userId: userId,
      followingCount: currentCount + 1,
    );
  }

  /// Decrement following count for a user
  Future<void> _decrementFollowingCount(String userId) async {
    final profile = await getUserProfile(userId);
    final currentCount = profile.data['following_count'] as int? ?? 0;
    await updateUserProfile(
      userId: userId,
      followingCount: max(0, currentCount - 1),
    );
    
  }

  /// Check if one user follows another
  Future<bool> isFollowing({
    required String followerId,
    required String followeeId,
  }) async {
    final result = await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: _connectionsCollection,
      queries: [
        Query.equal('follower_id', followerId),
        Query.equal('followee_id', followeeId),
      ],
    );
    
    return result.documents.isNotEmpty;
  }

  /// Get all users
  Future<List<Document>> getAllUsers({int limit = 50}) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: _profilesCollection,
        queries: [
          Query.limit(limit),
        ],
      );
      
      return result.documents;
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Create a new waiting paired listening session
  Future<Document> createWaitingPairedSession(String hostUserId, String hostUsername) async {
    try {
      final session = await _databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _pairedSessionsCollection,
        documentId: ID.unique(),
        data: {
          'host_user_id': hostUserId,
          'host_username': hostUsername,
          'guest_user_id': null,
          'guest_username': null,
          'status': 'waiting',
          'current_song_id': null,
          'current_song_name': null,
          'current_song_url': null,
          'image_url': null,
          'playback_position': 0,
          'is_playing': false,
          'created_at': DateTime.now().toIso8601String(),
          'ended_at': null,
        },
      );
      
      return session;
    } catch (e) {
      print('Error creating paired session: $e');
      throw e;
    }
  }

  // Join an existing paired session
  Future<Document> joinPairedSession(String sessionId, String guestUserId, String guestUsername) async {
    try {
      final session = await _databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _pairedSessionsCollection,
        documentId: sessionId,
        data: {
          'guest_user_id': guestUserId,
          'guest_username': guestUsername,
          'status': 'active',
        },
      );
      
      return session;
    } catch (e) {
      print('Error joining paired session: $e');
      throw e;
    }
  }

  // Update the current song in a paired session
  Future<Document> updatePairedSessionSong(
    String sessionId, 
    String songId, 
    String songName, 
    String songUrl,
    String? imageUrl,
  ) async {
    try {
      final session = await _databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _pairedSessionsCollection,
        documentId: sessionId,
        data: {
          'current_song_id': songId,
          'current_song_name': songName,
          'current_song_url': songUrl,
          'image_url': imageUrl,
          'playback_position': 0,
          'is_playing': true,
        },
      );
      
      return session;
    } catch (e) {
      print('Error updating paired session song: $e');
      throw e;
    }
  }

  // Update playback status in a paired session
  Future<Document> updatePairedSessionPlayback(
    String sessionId, 
    double position, 
    bool isPlaying,
  ) async {
    try {
      final session = await _databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _pairedSessionsCollection,
        documentId: sessionId,
        data: {
          'playback_position': position,
          'is_playing': isPlaying,
        },
      );
      
      return session;
    } catch (e) {
      print('Error updating paired session playback: $e');
      throw e;
    }
  }

  // Get a specific paired session by ID
  Future<Document?> getPairedSession(String sessionId) async {
    try {
      final document = await _databases.getDocument(
        databaseId: AppConfig.databaseId,
        collectionId: _pairedSessionsCollection,
        documentId: sessionId,
      );
      
      return document;
    } catch (e) {
      print('Error getting paired session: $e');
      return null;
    }
  }

  // Create document in any collection
  Future<Document> createDocument({
    required String collectionId,
    required Map<String, dynamic> data,
  }) async {
    return await _databases.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: collectionId,
      documentId: ID.unique(),
      data: data,
    );
  }

  // Get document from any collection
  Future<Document> getDocument({
    required String collectionId,
    required String documentId,
  }) async {
    return await _databases.getDocument(
      databaseId: AppConfig.databaseId,
      collectionId: collectionId,
      documentId: documentId,
    );
  }

  // Update document in any collection
  Future<Document> updateDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    return await _databases.updateDocument(
      databaseId: AppConfig.databaseId,
      collectionId: collectionId,
      documentId: documentId,
      data: data,
    );
  }

  // Add this method to your SocialDatabaseService class

  Future<DocumentList> listDocuments({
    required String collectionId,
    List<String>? queries,
  }) async {
    return await _databases.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: collectionId,
      queries: queries,
    );
  }
}