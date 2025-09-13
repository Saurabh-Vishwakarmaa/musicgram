import 'dart:async';
import 'dart:convert';
import 'package:appwrite/models.dart' hide Row;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:appwrite/appwrite.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/screens/homie.dart' as homie;
import 'package:musicgram4/services/appwrite_service.dart';
import 'package:musicgram4/services/audio_player_service.dart';
import 'package:musicgram4/services/appwrite_service.dart' as service;
import 'package:musicgram4/configs/appwritecongif.dart' as config;
import 'package:musicgram4/social/screens/song_selection_screen.dart';
import 'package:flutter/services.dart';

class PairedListeningScreen extends StatefulWidget {
  final String sessionId;
  final bool isHost;
  final String? guestUsername;
  final String? hostUsername;

  const PairedListeningScreen({
    Key? key,
    required this.sessionId,
    required this.isHost,
    this.guestUsername,
    this.hostUsername,
  }) : super(key: key);

  @override
  _PairedListeningScreenState createState() => _PairedListeningScreenState();
}

class _PairedListeningScreenState extends State<PairedListeningScreen> {
  // Core services
  final SocialDatabaseService _socialService = SocialDatabaseService(
    databases: databases,
    storage: storage,
    account: account,
  );
  final AudioPlayerService _audioService = AudioPlayerService();
  
  // Session management
  String? _sessionId;
  Map<String, dynamic>? _session;
  RealtimeSubscription? _sessionSubscription;
  bool _isHost = false;
  bool _isLoading = true;
  
  // My audio playback state (independent)
  String? _currentSongName;
  String? _currentSongUrl;
  String? _currentImageUrl;
  String? _currentArtist;
  bool _isPlaying = false;
  double _playbackPosition = 0.0;
  double _songDuration = 0.0;
  
  // Partner's playback state (display only)
  bool _partnerIsPlaying = false;
  double _partnerPlaybackPosition = 0.0;
  
  // User info
  String? _currentUserId;
  String? _currentUsername;
  String? _partnerUsername;
  
  // Session code
  String? _sessionCode;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _isHost = widget.isHost;
    _initializeScreen();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    _sessionSubscription?.close();
    _audioService.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user
      final account = await service.AppwriteService.account.get();
      _currentUserId = account.$id;
      _currentUsername = account.name;

      // Initialize audio service
      _audioService.init();
      _setupAudioListeners();

      // Load session data
      await _loadSession();

      // Setup realtime subscriptions
      _setupRealtimeSubscription();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing screen: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSession() async {
    try {
      final document = await _socialService.getDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
      );
      
      setState(() {
        _session = document.data;
        _sessionCode = document.data['session_name'];
        
        // Set partner info based on database fields
        if (_isHost) {
          _partnerUsername = document.data['guest_username'];
          // Load partner's playback state
          _partnerIsPlaying = document.data['guest_is_playing'] ?? false;
          _partnerPlaybackPosition = (document.data['guest_playback_position'] ?? 0.0).toDouble();
        } else {
          _partnerUsername = document.data['host_username'];
          // Load partner's playback state
          _partnerIsPlaying = document.data['isPlaying'] ?? false;
          _partnerPlaybackPosition = (document.data['playback_position'] ?? 0.0).toDouble();
        }
        
        // Load current song if exists (shared between users)
        final songId = document.data['song_id'];
        if (songId != null && songId.toString().isNotEmpty) {
          _currentSongUrl = songId;
          _currentSongName = document.data['current_song_name'];
          _currentArtist = document.data['current_artist_name'];
          _currentImageUrl = document.data['album_art_url'];
          
          // Load my own playback state
          if (_isHost) {
            _isPlaying = document.data['isPlaying'] ?? false;
            _playbackPosition = (document.data['playback_position'] ?? 0.0).toDouble();
          } else {
            _isPlaying = document.data['is_playing'] ?? false;
            _playbackPosition = (document.data['playback_position'] ?? 0.0).toDouble();
          }
          
          // Load the song if it exists
          if (_currentSongUrl != null && _currentSongName != null) {
            final album = homie.Album(
              _currentSongName!,
              _currentSongUrl!,
              _currentImageUrl,
              artist: _currentArtist,
            );
            _loadSongSilently(album);
          }
        }
      });
    } catch (e) {
      print('Error loading session: $e');
      throw e;
    }
  }

  void _setupAudioListeners() {
    _audioService.onPlayPause = () {
      if (mounted) {
        setState(() {
          _isPlaying = _audioService.isPlaying;
        });
        // Update only my playback state
        _updateMyPlaybackState();
      }
    };

    _audioService.onPositionChanged = (position) {
      if (mounted) {
        setState(() {
          _playbackPosition = position.inSeconds.toDouble();
        });
        // Update my position periodically (every 5 seconds to reduce API calls)
        if (_playbackPosition % 5 == 0) {
          _updateMyPlaybackState();
        }
      }
    };

    _audioService.onDurationChanged = (duration) {
      if (mounted && duration != null) {
        setState(() {
          _songDuration = duration.inSeconds.toDouble();
        });
      }
    };

    _audioService.onComplete = () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = 0.0;
        });
        _updateMyPlaybackState();
      }
    };
  }

  void _setupRealtimeSubscription() {
    if (_sessionId == null) return;
    
    try {
      final realtime = Realtime(service.AppwriteService.client);
      
      _sessionSubscription = realtime.subscribe([
        'databases.${config.AppConfig.databaseId}.collections.paired_sessions.documents.$_sessionId'
      ]);
      
      _sessionSubscription!.stream.listen(
        (response) {
          print('Received session update: ${response.events}');
          if (response.events.contains('databases.*.collections.*.documents.*.update')) {
            final updatedDocument = Document.fromMap(response.payload);
            print('Document updated: ${updatedDocument.data}');
            
            if (mounted) {
              _handleSessionUpdate(updatedDocument);
            }
          }
        },
        onError: (error) {
          print('Realtime subscription error: $error');
        },
      );
    } catch (e) {
      print('Error setting up realtime subscription: $e');
    }
  }

  void _handleSessionUpdate(Document updatedDocument) {
    setState(() {
      _session = updatedDocument.data;
      
      // Update partner info
      if (_isHost) {
        _partnerUsername = updatedDocument.data['guest_username'];
        // Update partner's playback state
        _partnerIsPlaying = updatedDocument.data['guest_is_playing'] ?? false;
        _partnerPlaybackPosition = (updatedDocument.data['guest_playback_position'] ?? 0.0).toDouble();
      } else {
        _partnerUsername = updatedDocument.data['host_username'];
        // Update partner's playback state
        _partnerIsPlaying = updatedDocument.data['isPlaying'] ?? false;
        _partnerPlaybackPosition = (updatedDocument.data['host_playback_position'] ?? 0.0).toDouble();
      }
      
      // Update current song from session (shared data)
      final songId = updatedDocument.data['song_id'];
      if (songId != null && songId.toString().isNotEmpty && songId != _currentSongUrl) {
        _currentSongUrl = songId;
        _currentSongName = updatedDocument.data['current_song_name'];
        _currentArtist = updatedDocument.data['current_artist_name'];
        _currentImageUrl = updatedDocument.data['album_art_url'];
        
        // Auto-load song for partner (but don't auto-play)
        if (_currentSongUrl != null && _currentSongName != null) {
          final album = homie.Album(
            _currentSongName!,
            _currentSongUrl!,
            _currentImageUrl,
            artist: _currentArtist,
          );
          _loadSong(album);
        }
      }
    });
  }

  // UPDATED: Only update my playback state
  Future<void> _updateMyPlaybackState() async {
    if (_sessionId == null) return;
    
    try {
      final updateData = <String, dynamic>{
        'last_sync_time': DateTime.now().toIso8601String(),
      };
      
      // Update my specific playback state
      if (_isHost) {
        updateData['is_playing'] = _isPlaying;
        updateData['playback_position'] = _playbackPosition;
      } else {
        updateData['is_playing'] = _isPlaying;
        updateData['playback_position'] = _playbackPosition;
      }
      
      print('Updating my playback state: $updateData');
      
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: updateData,
      );
    } catch (e) {
      print('Error updating my playback state: $e');
    }
  }

  // Song Selection Logic (only updates shared song data)
  Future<void> _selectSong() async {
    try {
      HapticFeedback.lightImpact();
      
      // Get partner user ID from session
      String? partnerUserId;
      if (_session != null) {
        partnerUserId = _isHost 
            ? _session!['guest_user_id'] 
            : _session!['host_user_id'];
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SongSelectionScreen(
            sessionId: _sessionId,
            currentUserId: _currentUserId,
            partnerUserId: partnerUserId,
          ),
        ),
      );
      
      if (result != null && result is homie.Album) {
        await _playSong(result);
      }
    } catch (e) {
      print('Error in song selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting song'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // UPDATED: Only update shared song data, not playback state
  Future<void> _playSong(homie.Album album) async {
    try {
      setState(() {
        _currentSongName = album.name;
        _currentSongUrl = album.downloadUrl;
        _currentImageUrl = album.imageUrl;
        _currentArtist = album.artist;
        _isPlaying = false;
        _playbackPosition = 0.0;
      });
      
      // Stop current song first
      await _audioService.stop();
      
      // Load and prepare the new song
      await _audioService.playSong(album);
      
      // Pause immediately after loading
      await _audioService.pause();
      
      // Update session with new song info (shared data only)
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'song_id': album.downloadUrl,
          'current_song_name': album.name,
          'current_artist_name': album.artist ?? 'Unknown Artist',
          'album_art_url': album.imageUrl,
          'last_sync_time': DateTime.now().toIso8601String(),
        },
      );
      
      // Reset both users' playback states
      final resetData = <String, dynamic>{
        'isPlaying': false,
        'host_playback_position': 0.0,
        'guest_is_playing': false,
        'guest_playback_position': 0.0,
      };
      
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: resetData,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 Song shared: ${album.name}'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error playing song: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading song: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSong(homie.Album album) async {
    try {
      setState(() {
        _currentSongName = album.name;
        _currentSongUrl = album.downloadUrl;
        _currentImageUrl = album.imageUrl;
        _currentArtist = album.artist;
      });
      
      // Stop current song first
      await _audioService.stop();
      
      // Load and prepare the new song
      await _audioService.playSong(album);
      
      // Pause immediately after loading
      await _audioService.pause();
      
      setState(() {
        _isPlaying = false;
        _playbackPosition = 0.0;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 Partner shared: ${album.name}'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error loading song: $e');
    }
  }

  // Silent loading for initial session load
  Future<void> _loadSongSilently(homie.Album album) async {
    try {
      await _audioService.stop();
      await _audioService.playSong(album);
      await _audioService.pause();
      
      setState(() {
        _isPlaying = false;
        _playbackPosition = 0.0;
      });
    } catch (e) {
      print('Error loading song silently: $e');
    }
  }

  // UPDATED: Only control my own playback
  Future<void> _togglePlayPause() async {
    if (_currentSongUrl == null || _currentSongName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a song first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      HapticFeedback.mediumImpact();
      
      if (_isPlaying) {
        await _audioService.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioService.play();
        setState(() {
          _isPlaying = true;
        });
      }
      
      // Update only my playback state
      await _updateMyPlaybackState();
      
      print('My Play/Pause toggled: $_isPlaying');
    } catch (e) {
      print('Error toggling playback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error controlling playback: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _endSession() async {
    try {
      if (_sessionId != null) {
        await _socialService.updateDocument(
          collectionId: 'paired_sessions',
          documentId: _sessionId!,
          data: {
            'status': 'ended',
            'ended_at': DateTime.now().toIso8601String(),
          },
        );
      }
      
      _cleanup();
      Navigator.of(context).pop();
    } catch (e) {
      print('Error ending session: $e');
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            Text(
              _isHost ? 'Hosting Session' : 'Joined Session',
              style: GoogleFonts.poppins(
                color: Colors.greenAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_sessionCode != null)
              Text(
                'Code: $_sessionCode',
                style: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.greenAccent),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.greenAccent),
            onPressed: _endSession,
            tooltip: 'End Session',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading session...',
                    style: GoogleFonts.poppins(
                      color: Colors.greenAccent,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildPartnersSection(),
                  _buildMyMusicSection(),
                  _buildPartnerActivitySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPartnersSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Connected Partners',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person, color: Colors.greenAccent, size: 24),
                      SizedBox(height: 4),
                      Text(
                        'You',
                        style: GoogleFonts.poppins(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentUsername ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // My status indicator
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPlaying ? Colors.greenAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isPlaying ? Icons.play_arrow : Icons.pause,
                              color: _isPlaying ? Colors.greenAccent : Colors.grey,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _isPlaying ? 'Playing' : 'Paused',
                              style: GoogleFonts.poppins(
                                color: _isPlaying ? Colors.greenAccent : Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _partnerUsername != null 
                        ? Colors.greenAccent.withOpacity(0.1)
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _partnerUsername != null 
                          ? Colors.greenAccent.withOpacity(0.3)
                          : Colors.grey[600]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _partnerUsername != null ? Icons.person : Icons.person_outline,
                        color: _partnerUsername != null ? Colors.greenAccent : Colors.grey,
                        size: 24,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Partner',
                        style: GoogleFonts.poppins(
                          color: _partnerUsername != null ? Colors.greenAccent : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _partnerUsername ?? 'Waiting...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // Partner's status indicator
                      if (_partnerUsername != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _partnerIsPlaying ? Colors.greenAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _partnerIsPlaying ? Icons.play_arrow : Icons.pause,
                                color: _partnerIsPlaying ? Colors.greenAccent : Colors.grey,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _partnerIsPlaying ? 'Playing' : 'Paused',
                                style: GoogleFonts.poppins(
                                  color: _partnerIsPlaying ? Colors.greenAccent : Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyMusicSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, color: Colors.greenAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'My Music Player',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Album art
          Center(
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
              ),
              child: _currentImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _currentImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.music_note,
                              size: 48,
                              color: Colors.greenAccent,
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.music_note,
                        size: 48,
                        color: Colors.greenAccent,
                      ),
                    ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Song info
          Center(
            child: Column(
              children: [
                Text(
                  _currentSongName ?? 'No song selected',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currentArtist ?? 'Unknown Artist',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.greenAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
          
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentSongUrl != null 
                        ? Colors.greenAccent 
                        : Colors.grey[600],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ),
              
              SizedBox(width: 20),
              
              // Song selection button
              GestureDetector(
                onTap: _selectSong,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent.withOpacity(0.2),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                  ),
                  child: Icon(
                    Icons.queue_music,
                    color: Colors.greenAccent,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Status text
          Center(
            child: Text(
              _currentSongUrl != null 
                  ? (_isPlaying ? 'Playing independently' : 'Paused - Ready to play') 
                  : 'Select a song to start',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.greenAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          SizedBox(height: 8),
          
          // Progress slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.greenAccent,
              inactiveTrackColor: Colors.grey[700],
              thumbColor: Colors.greenAccent,
              overlayColor: Colors.greenAccent.withOpacity(0.2),
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _playbackPosition.clamp(0, _songDuration),
              min: 0,
              max: _songDuration > 0 ? _songDuration : 1,
              onChanged: _currentSongUrl != null ? (value) {
                setState(() {
                  _playbackPosition = value;
                });
              } : null,
              onChangeEnd: _currentSongUrl != null ? (value) {
                _audioService.seek(Duration(seconds: value.toInt()));
                _updateMyPlaybackState();
              } : null,
            ),
          ),
          
          // Time display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_playbackPosition.toInt()),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.greenAccent,
                ),
              ),
              Text(
                _formatDuration(_songDuration.toInt()),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerActivitySection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.headphones, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                '${_partnerUsername ?? "Partner"}\'s Activity',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          if (_partnerUsername != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentSongName ?? 'No song selected',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _currentArtist ?? 'Unknown Artist',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          _partnerIsPlaying ? Icons.play_arrow : Icons.pause,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Partner's progress bar
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.blue,
                          inactiveTrackColor: Colors.grey[700],
                          thumbColor: Colors.blue,
                          overlayColor: Colors.blue.withOpacity(0.2),
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4),
                        ),
                        child: Slider(
                          value: _partnerPlaybackPosition.clamp(0, _songDuration),
                          min: 0,
                          max: _songDuration > 0 ? _songDuration : 1,
                          onChanged: null, // Read-only
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_partnerPlaybackPosition.toInt()),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            _partnerIsPlaying ? 'Playing' : 'Paused',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  Text(
                    'You both have the same song loaded, but can control playback independently.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[600]!),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Waiting for partner to join...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Share your session code with a friend to start listening together!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}