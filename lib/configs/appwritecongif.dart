class AppConfig {
  // Appwrite Configuration
  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = '67ebee1b003c16ce8f88'; // Replace with your Appwrite project ID
  static const String databaseId = 'your-database-id'; // Replace with your database ID
  static const String collectionId = 'your-collection-id'; // Replace with your collection ID
  
  // Storage
  static const String storageId = '6801f6e4000bfae65308'; // For storing user files/music

  // Authentication
  static const String userCollectionId = 'users';
  
  // Platform-specific settings
  static const String iosBundleId = 'com.example.musicgram4';
  static const String androidPackageName = 'com.example.musicgram4';
}