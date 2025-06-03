import 'package:appwrite/models.dart';

// Define enum for session status to match Appwrite schema
enum SessionStatus {
  waiting,
  active,
  ended,
  paused
}

// Helper extension to convert between string and enum
extension SessionStatusExtension on SessionStatus {
  String get value {
    switch (this) {
      case SessionStatus.waiting: return 'waiting';
      case SessionStatus.active: return 'active';
      case SessionStatus.ended: return 'ended';
      case SessionStatus.paused: return 'paused';
      default: return 'waiting';
    }
  }
  
  static SessionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'waiting': return SessionStatus.waiting;
      case 'active': return SessionStatus.active;
      case 'ended': return SessionStatus.ended;
      case 'paused': return SessionStatus.paused;
      default: return SessionStatus.waiting;
    }
  }
}

class PairedSession {
  final String id;
  final String hostUserId;
  final String hostUsername;
  final String guestUserId;
  final String? guestUsername;
  final SessionStatus status;  // Changed to enum type
  final String songId;
  final String? currentSongName;
  final String? currentArtistName;
  final String? currentSongUrl;
  final String? imageUrl;
  final double? playbackPosition;
  final bool isPlaying;
  final DateTime createdAt;
  final DateTime? endedAt;
  final DateTime lastSyncTime;
  final bool chatEnabled;
  final int? currentPosition;   // Added for schema match
  final String? hostAvatarId;   // Added for schema match
  final String? sessionName;    // Added for schema match
  
  PairedSession({
    required this.id,
    required this.hostUserId,
    required this.hostUsername,
    required this.guestUserId,
    this.guestUsername,
    required this.status,
    required this.songId,
    this.currentSongName,
    this.currentArtistName,
    this.currentSongUrl,
    this.imageUrl,
    this.playbackPosition,
    required this.isPlaying,
    required this.createdAt,
    this.endedAt,
    required this.lastSyncTime,
    required this.chatEnabled,
    this.currentPosition,
    this.hostAvatarId,
    this.sessionName,
  });
  
  factory PairedSession.fromDocument(Document document) {
    return PairedSession(
      id: document.$id,
      hostUserId: document.data['host_user_id'],
      hostUsername: document.data['host_username'],
      guestUserId: document.data['guest_user_id'],
      guestUsername: document.data['guest_username'],
      status: SessionStatusExtension.fromString(document.data['status']),  // Convert string to enum
      songId: document.data['song_id'],
      currentSongName: document.data['current_song_name'],
      currentArtistName: document.data['current_artist_name'],
      currentSongUrl: document.data['current_song_url'],
      imageUrl: document.data['album_art_url'],  // Changed to use album_art_url directly
      playbackPosition: document.data['playbackPosition'] != null ? 
          double.tryParse(document.data['playbackPosition'].toString()) : null,
      currentPosition: document.data['current_position'],
      isPlaying: document.data['is_playing'] ?? false,
      createdAt: DateTime.parse(document.data['created_at']),
      endedAt: document.data['ended_at'] != null ? 
          DateTime.parse(document.data['ended_at']) : null,
      lastSyncTime: DateTime.parse(document.data['last_sync_time']),
      chatEnabled: document.data['chat_enabled'] ?? false,
      hostAvatarId: document.data['host_avatar_id'],
      sessionName: document.data['session_name'],
    );
  }
}