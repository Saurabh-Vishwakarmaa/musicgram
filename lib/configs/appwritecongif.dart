class AppConfig {
  // Appwrite Configuration
  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = '67ebee1b003c16ce8f88';
  static const String databaseId = '68065f990028fd7ab9f6';
  
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
  
  // Authentication
  static const String userCollectionId = 'users';
  
  // Platform-specific settings
  static const String iosBundleId = 'com.example.musicgram4';
  static const String androidPackageName = 'com.example.musicgram4';
}