import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

/// Configuration for Appwrite services
class AppConfig {
  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = '67ebee1b003c16ce8f88'; // Replace with your project ID
  static const String databaseId = '68065f990028fd7ab9f6'; // Replace with your database ID

    // Collection IDs
  static const String userProfilesCollection = '68065fc1000215395c66';
  static const String socialConnectionsCollection = 'social_connections';
  static const String invitationsCollection = 'invitations';
  static const String pairedSessionsCollection = 'paired_sessions';
  static const String userActivitiesCollection = 'user_activities';
  static const String songsCollection = 'songs'; // If you have a songs collection
  // static const String albumsCollection = 'albums'; // If you have an albums collection
  // Add any other collections you've created
  
  // Storage
  static const String storageId = '6801f6e4000bfae65308';
  static const String profilePicturesBucket = 'profile_pictures';
// Add these constants to your AppConfig class

static const String chatchat_conversations = 'chat_conversations';
static const String chatMessagesCollection = 'chat_messages';
  
  // Authentication
  static const String userCollectionId = 'users';
  
  // Platform-specific settings
  static const String iosBundleId = 'com.example.musicgram4';
  static const String androidPackageName = 'com.example.musicgram4';
}

/// Service class to manage Appwrite services
class AppwriteService {
  // Appwrite service instances
  static late final Client client;
  static late final Account account;
  static late final Databases databases;
  static late final Storage storage;
  
  // Current user info
  static String? currentUserId;
  static models.User? currentUser;
  
  // Authentication state notifications
  static final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  
  // Add an initialization flag
  static bool isInitialized = false;
  
  /// Initialize all Appwrite services
  static Future<void> initialize() async {
    if (isInitialized) return;
    
    try {
      // Initialize client
      client = Client()
        .setEndpoint(AppConfig.endpoint)
        .setProject(AppConfig.projectId)
        .setSelfSigned(); // Remove in production
      
      // Initialize services
      account = Account(client);
      databases = Databases(client);
      storage = Storage(client);
      
      // Try to get current session
      await getCurrentUser();
      
      isInitialized = true;
    } catch (e) {
      print('Failed to initialize AppwriteService: $e');
      rethrow;
    }
  }
  
  /// Get the currently logged in user (if any)
  static Future<void> getCurrentUser() async {
    try {
      currentUser = await account.get();
      currentUserId = currentUser?.$id;
      isAuthenticated.value = currentUserId != null;
    } catch (e) {
      // No active session
      currentUser = null;
      currentUserId = null;
      isAuthenticated.value = false;
    }
  }
  
  /// Sign in with email and password
  static Future<models.Session> signIn({
    required String email,
    required String password,
  }) async {
    final session = await account.createEmailPasswordSession(
      email: email,
      password: password,
    );
    
    await getCurrentUser();
    return session;
  }
  
  /// Sign up with email and password
  static Future<models.User> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final user = await account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
    
    return user;
  }
  
  /// Create a user profile after signup
  static Future<void> createUserProfile({
    required String userId,
    required String username,
    required String displayName,
    String? bio,
  }) async {
    await databases.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: '68065fc1000215395c66',
      documentId: userId,
      data: {
        'user_id': userId,
        'username': username,
        'display_name': displayName,
        'bio': bio ?? '',
        'avatar_file_id': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'followers_count': 0,
        'following_count': 0,
      },
    );
  }
  
  /// Sign out the current user
  static Future<void> signOut() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } finally {
      currentUser = null;
      currentUserId = null;
      isAuthenticated.value = false;
    }
  }
  
  /// Upload a profile image
  static Future<String> uploadProfileImage(dynamic file, String userId) async {
    final result = await storage.createFile(
      bucketId: 'profile_pictures',
      fileId: ID.unique(),
      file: file,
    );
    
    return result.$id;
  }
  
  /// Get a file preview URL
  static String getFilePreview(String fileId, {int width = 400, int height = 400}) {
    return storage.getFilePreview(
      bucketId: 'profile_pictures',
      fileId: fileId,
      width: width,
      height: height,
    ).toString();
  }

  // static String getFilePreview(String fileId) {
  //   return 'https://cloud.appwrite.io/v1/storage/buckets/profile_pictures/files/$fileId/preview?project=${AppConfig.projectId}';
  // }
}