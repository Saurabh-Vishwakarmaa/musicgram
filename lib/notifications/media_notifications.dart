import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../screens/homie.dart';  // For Album model

// Action IDs for notification controls
const String actionPlay = 'play';
const String actionPause = 'pause';
const String actionNext = 'next';
const String actionPrev = 'previous';
const String actionStop = 'stop';

class MediaNotificationService {
  double getVolume() {
    // Return a default volume value or fetch the current volume from the player
    return 1.0; // Replace with actual logic if needed
  }
  // Singleton implementation
  static final MediaNotificationService _instance = MediaNotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();
  
  // Callbacks
  VoidCallback? onPlayPause;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  VoidCallback? onStop;
  ValueChanged<Duration>? onPositionChanged;
  ValueChanged<Duration?>? onDurationChanged;
  
  // Current state
  bool _isPlaying = false;
  Album? _currentAlbum;
  bool _isInitialized = false;
  
  // Add this property to your class
  Timer? _notificationTimer;
  
  factory MediaNotificationService() {
    return _instance;
  }
  
  MediaNotificationService._internal();
  
  AudioPlayer get player => _player;
  bool get isPlaying => _isPlaying;
  Album? get currentAlbum => _currentAlbum;
  bool get isInitialized => _isInitialized;
  
  // Make sure your init method looks like this:
  bool _initializingNotifications = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    // Prevent multiple initializations running at once
    if (_initializingNotifications) return;
    _initializingNotifications = true;
    
    try {
      // Initialize the audio player
      await _setupAudioSession();
      
      // Initialize notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onSelectNotification,
      );
      
      // Set up the notification channel
      await _setupNotificationActions();
      
      // Request permissions separately
      await _requestNotificationPermissions();
      
      _isInitialized = true;
    } catch (e) {
      print("Error initializing media service: $e");
    } finally {
      _initializingNotifications = false;
    }
  }
  
  // Set up notification actions for Android
  Future<void> _setupNotificationActions() async {
    // Create the Android notification channel for media controls
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'musicgram_media_channel',
      'Media Playback Controls',
      description: 'Media playback controls for Musicgram',
      importance: Importance.low,
    );
    
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  // Handle notification action selection
  void _onSelectNotification(NotificationResponse response) {
    final String? actionId = response.actionId;
    
    if (actionId == null) {
      // Notification was tapped, not an action button
      return;
    }
    
    switch (actionId) {
      case actionPlay:
        play();
        break;
      case actionPause:
        pause();
        break;
      case actionNext:
        if (onNext != null) onNext!();
        break;
      case actionPrev:
        if (onPrevious != null) onPrevious!();
        break;
      case actionStop:
        stop();
        if (onStop != null) onStop!();
        break;
    }
  }
  
  // Set up audio session for proper background behavior
  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    // Handle interruptions (calls, alarms, etc)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_player.playing) {
          _player.pause();
        }
      } else {
        if (!_player.playing && event.type == AudioInterruptionType.pause) {
          _player.play();
        }
      }
    });
    
    // Handle becoming noisy (headphones unplugged)
    session.becomingNoisyEventStream.listen((_) {
      if (_player.playing) {
        _player.pause();
      }
    });
  }
  
  // Play a song with notification
  Future<void> playSong(Album album) async {
    if (!_isInitialized) await init();
    
    _currentAlbum = album;
    
    try {
      // First stop current playback
      await _player.stop();
      
      // Set audio source
      await _player.setUrl(album.downloadUrl);
      
      // Start playback
      await _player.play();
      _isPlaying = true;
      
      // Show the notification
      await _showNotification(album, true);
      
      // Start periodic updates
      _startNotificationUpdates();
    } catch (e) {
      print("Error playing song with notification: $e");
    }
  }
  
  // Update the notification with song info and controls
  Future<void> _showNotification(Album album, bool isPlaying) async {
    if (!_isInitialized) await init();
    
    Uint8List? albumArt;
    
    // Download the album art for the notification
    if (album.imageUrl != null) {
      try {
        final response = await http.get(Uri.parse(album.imageUrl!));
        if (response.statusCode == 200) {
          albumArt = response.bodyBytes;
        }
      } catch (e) {
        print("Error downloading album art: $e");
      }
    }
    
    // Android notification settings
    List<AndroidNotificationAction> actions = [
      AndroidNotificationAction(
        actionPrev,
        'Previous',
        icon: DrawableResourceAndroidBitmap('ic_previous'),
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        isPlaying ? actionPause : actionPlay,
        isPlaying ? 'Pause' : 'Play',
        icon: DrawableResourceAndroidBitmap(isPlaying ? 'ic_pause' : 'ic_play'),
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        actionNext,
        'Next',
        icon: DrawableResourceAndroidBitmap('ic_next'),
        showsUserInterface: false,
      ),
    ];
    
    // Calculate progress for display
    int progress = _player.position.inMilliseconds;
    int maxProgress = _player.duration?.inMilliseconds ?? 100;
    
    // Format time for display
    String position = _formatDuration(_player.position);
    String duration = _formatDuration(_player.duration ?? Duration.zero);
    
    // Create styled notification
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'musicgram_media_channel',
      'Media Playback Controls',
      channelDescription: 'Media playback controls for Musicgram',
      playSound: false,
      ongoing: true,
      priority: Priority.low,
      importance: Importance.low,
      color: Color(0xFF1DB954), // Accent color for notification
      colorized: true,
      showWhen: false,
      actions: actions,
      largeIcon: albumArt != null ? ByteArrayAndroidBitmap(albumArt) : null,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      // Replace the styleInformation with BigTextStyleInformation
      styleInformation: BigTextStyleInformation(
        'Now Playing • $position / $duration',
        htmlFormatBigText: true,
        htmlFormatTitle: true,
        
      ),
    );
    
    // iOS notification settings
    DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: false,
      presentBadge: false,
      presentAlert: false,
      interruptionLevel: InterruptionLevel.active,
    );
    
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Create a content text that shows progress
    String contentText = 'Now Playing • $position / $duration';
    
    await _notificationsPlugin.show(
      0, // Notification ID
      album.name,
      contentText,
      notificationDetails,
    );
  }
  
  // Add this method to start periodic updates
  void _startNotificationUpdates() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isPlaying && _currentAlbum != null) {
        _showNotification(_currentAlbum!, _isPlaying);
      } else {
        timer.cancel();
      }
    });
  }
  
  // Basic controls for external usage
  Future<void> play() async {
    if (!_isInitialized) await init();
    
    if (_currentAlbum != null) {
      await _player.play();
      _isPlaying = true;
      await _showNotification(_currentAlbum!, true);
    }
  }
  
  Future<void> pause() async {
    if (!_isInitialized) await init();
    
    await _player.pause();
    _isPlaying = false;
    if (_currentAlbum != null) {
      await _showNotification(_currentAlbum!, false);
    }
  }
  
  Future<void> stop() async {
    if (!_isInitialized) await init();
    
    await _player.stop();
    _isPlaying = false;
    await _notificationsPlugin.cancelAll();
  }
  
  Future<void> seek(Duration position) async {
    if (!_isInitialized) await init();
    await _player.seek(position);
  }
  
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) await init();
    await _player.setVolume(volume);
  }
  
  // Clean up resources
  void dispose() {
    _notificationTimer?.cancel();
    _player.dispose();
    _notificationsPlugin.cancelAll();
  }

  // Move this method inside your MediaNotificationService class
  Future<void> _requestNotificationPermissions() async {
    // Only handle on Android 13+ (SDK 33+)
    if (!Platform.isAndroid) return;
    
    print("Attempting to request notification permissions...");
    try {
      final plugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (plugin == null) {
        print("Could not resolve Android plugin implementation");
        return;
      }
      
      // Use a simpler approach to request permissions
      final result = await plugin.requestNotificationsPermission();
      print("Permission request result: $result");
    } catch (e, stackTrace) {
      print("Error requesting permissions: $e");
      print("Stack trace: $stackTrace");
    }
  }
}

// Helper method to format duration for display
String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final String minutes = twoDigits(duration.inMinutes.remainder(60));
  final String seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}