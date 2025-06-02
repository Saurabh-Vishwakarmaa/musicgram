// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:appwrite/models.dart';
// import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// import 'package:musicgram4/social/models/user_profile.dart';

// class CacheManager {
//   static final CacheManager _instance = CacheManager._internal();
//   factory CacheManager() => _instance;
//   CacheManager._internal();
  
//   // In-memory cache for current session
//   final Map<String, dynamic> _memoryCache = {};
  
//   // Cache duration
//   static const Duration _userProfileCacheDuration = Duration(minutes: 15);
//   static const Duration _userListCacheDuration = Duration(minutes: 10);
//   static const Duration _activityCacheDuration = Duration(minutes: 5);
  
//   // Cached image manager
//   final imageCache = DefaultCacheManager();
  
//   // Keys for different types of data
//   static String userProfileKey(String userId) => 'user_profile_$userId';
//   static String userListKey(String query) => 'user_list_${query.isEmpty ? 'all' : query}';
//   static String followingKey(String userId) => 'following_$userId';
//   static String followersKey(String userId) => 'followers_$userId';
//   static String activityKey(String userId) => 'activity_$userId';
  
//   // Cache a user profile
//   Future<void> cacheUserProfile(UserProfile profile) async {
//     // In-memory cache
//     final key = userProfileKey(profile.userId);
//     _memoryCache[key] = {
//       'data': profile,
//       'timestamp': DateTime.now().millisecondsSinceEpoch
//     };
    
//     // Persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(key, jsonEncode(profile.toJson()));
    
//     // Cache expiration
//     await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
//   }
  
//   // Get cached user profile
//   Future<UserProfile?> getCachedUserProfile(String userId) async {
//     final key = userProfileKey(userId);
    
//     // Check memory cache first
//     if (_memoryCache.containsKey(key)) {
//       final cachedData = _memoryCache[key];
//       final timestamp = cachedData['timestamp'] as int;
//       if (DateTime.now().millisecondsSinceEpoch - timestamp < _userProfileCacheDuration.inMilliseconds) {
//         return cachedData['data'] as UserProfile;
//       }
//     }
    
//     // Check persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     final jsonData = prefs.getString(key);
//     final timestamp = prefs.getInt('${key}_timestamp') ?? 0;
    
//     if (jsonData != null && 
//         (DateTime.now().millisecondsSinceEpoch - timestamp < _userProfileCacheDuration.inMilliseconds)) {
//       try {
//         final profile = UserProfile.fromJson(jsonDecode(jsonData));
        
//         // Update memory cache
//         _memoryCache[key] = {
//           'data': profile,
//           'timestamp': timestamp
//         };
        
//         return profile;
//       } catch (e) {
//         print('Error parsing cached user profile: $e');
//       }
//     }
    
//     return null;
//   }
  
//   // Cache list of users
//   Future<void> cacheUserList(String query, List<UserProfile> users) async {
//     final key = userListKey(query);
    
//     // In-memory cache
//     _memoryCache[key] = {
//       'data': users,
//       'timestamp': DateTime.now().millisecondsSinceEpoch
//     };
    
//     // Persistent cache - store just the user IDs to save space
//     final userIds = users.map((user) => user.userId).toList();
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(key, jsonEncode(userIds));
//     await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
    
//     // Also cache individual user profiles
//     for (final user in users) {
//       await cacheUserProfile(user);
//     }
//   }
  
//   // Get cached user list
//   Future<List<UserProfile>?> getCachedUserList(String query) async {
//     final key = userListKey(query);
    
//     // Check memory cache first
//     if (_memoryCache.containsKey(key)) {
//       final cachedData = _memoryCache[key];
//       final timestamp = cachedData['timestamp'] as int;
//       if (DateTime.now().millisecondsSinceEpoch - timestamp < _userListCacheDuration.inMilliseconds) {
//         return cachedData['data'] as List<UserProfile>;
//       }
//     }
    
//     // Check persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     final jsonData = prefs.getString(key);
//     final timestamp = prefs.getInt('${key}_timestamp') ?? 0;
    
//     if (jsonData != null && 
//         (DateTime.now().millisecondsSinceEpoch - timestamp < _userListCacheDuration.inMilliseconds)) {
//       try {
//         final userIds = List<String>.from(jsonDecode(jsonData));
//         final users = <UserProfile>[];
        
//         for (final userId in userIds) {
//           final profile = await getCachedUserProfile(userId);
//           if (profile != null) {
//             users.add(profile);
//           }
//         }
        
//         if (users.length == userIds.length) {
//           // All profiles recovered from cache
//           _memoryCache[key] = {
//             'data': users,
//             'timestamp': timestamp
//           };
          
//           return users;
//         }
//       } catch (e) {
//         print('Error retrieving cached user list: $e');
//       }
//     }
    
//     return null;
//   }
  
//   // Cache following/follower lists
//   Future<void> cacheConnections(String userId, List<String> connectionIds, bool isFollowers) async {
//     final key = isFollowers ? followersKey(userId) : followingKey(userId);
    
//     // In-memory cache
//     _memoryCache[key] = {
//       'data': connectionIds,
//       'timestamp': DateTime.now().millisecondsSinceEpoch
//     };
    
//     // Persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(key, jsonEncode(connectionIds));
//     await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
//   }
  
//   // Get cached connections
//   Future<List<String>?> getCachedConnections(String userId, bool isFollowers) async {
//     final key = isFollowers ? followersKey(userId) : followingKey(userId);
    
//     // Check memory cache first
//     if (_memoryCache.containsKey(key)) {
//       final cachedData = _memoryCache[key];
//       final timestamp = cachedData['timestamp'] as int;
//       if (DateTime.now().millisecondsSinceEpoch - timestamp < _userProfileCacheDuration.inMilliseconds) {
//         return cachedData['data'] as List<String>;
//       }
//     }
    
//     // Check persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     final jsonData = prefs.getString(key);
//     final timestamp = prefs.getInt('${key}_timestamp') ?? 0;
    
//     if (jsonData != null && 
//         (DateTime.now().millisecondsSinceEpoch - timestamp < _userProfileCacheDuration.inMilliseconds)) {
//       try {
//         return List<String>.from(jsonDecode(jsonData));
//       } catch (e) {
//         print('Error retrieving cached connections: $e');
//       }
//     }
    
//     return null;
//   }
  
//   // Cache image URL (to avoid hitting Appwrite storage for preview URLs)
//   Future<String> getCachedImageUrl(String fileId) async {
//     final key = 'image_url_$fileId';
    
//     // Check memory cache first
//     if (_memoryCache.containsKey(key)) {
//       return _memoryCache[key]['data'] as String;
//     }
    
//     // Check persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     final cachedUrl = prefs.getString(key);
    
//     if (cachedUrl != null) {
//       // Update memory cache
//       _memoryCache[key] = {
//         'data': cachedUrl,
//         'timestamp': DateTime.now().millisecondsSinceEpoch
//       };
//       return cachedUrl;
//     }
    
//     // If not cached, generate URL and cache it
//     final url = 'https://cloud.appwrite.io/v1/storage/buckets/profile_pictures/files/$fileId/view?project=${AppwriteService.projectId}';
    
//     // Cache in memory
//     _memoryCache[key] = {
//       'data': url,
//       'timestamp': DateTime.now().millisecondsSinceEpoch
//     };
    
//     // Cache in persistent storage
//     await prefs.setString(key, url);
    
//     return url;
//   }
  
//   // Clear all caches
//   Future<void> clearAllCaches() async {
//     // Clear memory cache
//     _memoryCache.clear();
    
//     // Clear persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
    
//     // Clear image cache
//     await imageCache.emptyCache();
//   }
  
//   // Invalidate specific cache
//   Future<void> invalidateCache(String key) async {
//     // Remove from memory cache
//     _memoryCache.remove(key);
    
//     // Remove from persistent cache
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(key);
//     await prefs.remove('${key}_timestamp');
//   }
// }

