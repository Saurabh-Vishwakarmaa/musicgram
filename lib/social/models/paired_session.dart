import 'package:appwrite/models.dart';

class PairedSession {
  final String id;
  final String hostUserId;
  final String hostUsername;
  final String? guestUserId;
  final String? guestUsername;
  final String status; // 'waiting', 'active', 'ended'
  final String songId; // Required field
  final String? currentSongName;
  final String? currentArtistName;
  final String? currentSongUrl;
  final String? imageUrl;
  final double? playbackPosition;
  final bool isPlaying;
  final DateTime createdAt;
  final DateTime? endedAt;

  PairedSession({
    required this.id,
    required this.hostUserId,
    required this.hostUsername,
    this.guestUserId,
    this.guestUsername,
    required this.status,
    required this.songId, // Make this required
    this.currentSongName,
    this.currentArtistName,
    this.currentSongUrl,
    this.imageUrl,
    this.playbackPosition,
    required this.isPlaying,
    required this.createdAt,
    this.endedAt,
  });

  factory PairedSession.fromDocument(Document document) {
    return PairedSession(
      id: document.$id,
      hostUserId: document.data['host_user_id'],
      hostUsername: document.data['host_username'],
      guestUserId: document.data['guest_user_id'],
      guestUsername: document.data['guest_username'],
      status: document.data['status'] ?? 'waiting',
      songId: document.data['song_id'] ?? 'default_song', // Provide a default
      currentSongName: document.data['current_song_name'],
      currentArtistName: document.data['current_artist_name'],
      currentSongUrl: document.data['current_song_url'],
      imageUrl: document.data['image_url'],
      playbackPosition: document.data['current_position']?.toDouble(),
      isPlaying: document.data['is_playing'] ?? false,
      createdAt: document.data['created_at'] != null 
          ? DateTime.parse(document.data['created_at']) 
          : DateTime.now(),
      endedAt: document.data['ended_at'] != null 
          ? DateTime.parse(document.data['ended_at']) 
          : null,
    );
  }
}