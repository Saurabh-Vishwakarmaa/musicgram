import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:musicgram4/screens/homie.dart';


class AudioPlayerService {
  // Singleton implementation
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();
  
  // Audio player
  final AudioPlayer _player = AudioPlayer();
  
  // Notification plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // State variables
  bool _isInitialized = false;
  bool _isPlaying = false;
  Album? _currentAlbum;
  
  // Notification IDs
  static const int NOTIFICATION_ID = 888;
  
  // Notification channel
  static const String CHANNEL_ID = 'audio_playback_channel';
  static const String CHANNEL_NAME = 'Audio Playback';
  static const String CHANNEL_DESCRIPTION = 'Controls for audio playback';
  
  // Callbacks
  VoidCallback? onPlayPause;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  VoidCallback? onComplete;
  Function(Duration)? onPositionChanged;
  Function(Duration?)? onDurationChanged;
  
  // Getters
  AudioPlayer get player => _player;
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
  Album? get currentAlbum => _currentAlbum;
  double get volume => _player.volume;
  
  // Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;
    
    // Configure audio session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    // Setup player callbacks
    _setupPlayerCallbacks();
    
    // Initialize notifications
    await _initNotifications();
    
    _isInitialized = true;
  }
  
  
  // Initialize notifications
  Future<void> _initNotifications() async {
    // Android settings
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    // Initialize
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Simple notification click handling
        print("Notification clicked: ${details.actionId}");
      },
    );
    
    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        CHANNEL_ID,
        CHANNEL_NAME,
        description: CHANNEL_DESCRIPTION,
        importance: Importance.low,
      );
      
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }
  
  // Setup player callbacks
  void _setupPlayerCallbacks() {
    // Listen for position changes
    _player.positionStream.listen((position) {
      if (onPositionChanged != null) {
        onPositionChanged!(position);
      }
    });
    
    // Listen for duration changes
    _player.durationStream.listen((duration) {
      if (onDurationChanged != null) {
        onDurationChanged!(duration);
      }
    });
    
    // Listen for player state changes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (onComplete != null) {
          onComplete!();
        }
      }
    });
  }
  
  // Play a song
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
      
      // Show notification
      await _showNotification(album);
      
      if (onPlayPause != null) {
        onPlayPause!();
      }
    } catch (e) {
      print("Error playing song: $e");
    }
  }
  
  // Play
  Future<void> play() async {
    if (!_isInitialized) await init();
    
    if (_currentAlbum != null) {
      await _player.play();
      _isPlaying = true;
      
      await _showNotification(_currentAlbum!);
      
      if (onPlayPause != null) {
        onPlayPause!();
      }
    }
  }
  
  // Pause
  Future<void> pause() async {
    if (!_isInitialized) await init();
    
    await _player.pause();
    _isPlaying = false;
    
    if (_currentAlbum != null) {
      await _showNotification(_currentAlbum!);
    }
    
    if (onPlayPause != null) {
      onPlayPause!();
      
    }
  }
  
  // Stop
  Future<void> stop() async {
    if (!_isInitialized) await init();
    
    await _player.stop();
    _isPlaying = false;
    
    // Cancel notification
    await _notificationsPlugin.cancel(NOTIFICATION_ID);
    
    _currentAlbum = null;
  }
  
  // Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }
  
  // Set volume
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }
  
  // Show notification
  Future<void> _showNotification(Album album) async {
    // Basic notification without custom icons to avoid resource issues
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      CHANNEL_ID,
      CHANNEL_NAME,
      channelDescription: CHANNEL_DESCRIPTION,
      ongoing: true,
      playSound: false,
      importance: Importance.low,
      priority: Priority.low,
    );
    
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: false,
      presentBadge: false,
      presentAlert: false,
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      await _notificationsPlugin.show(
        NOTIFICATION_ID,
        album.name,
        'Now Playing',
        notificationDetails,
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }
  
  // Dispose
  void dispose() {
    _player.dispose();
    _notificationsPlugin.cancel(NOTIFICATION_ID);
  }
}