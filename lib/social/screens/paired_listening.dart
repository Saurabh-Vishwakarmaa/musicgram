import 'dart:async';
import 'dart:convert';
import 'package:appwrite/models.dart';
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
  
  // Audio playback state
  String? _currentSongName;
  String? _currentSongUrl;
  String? _currentImageUrl;
  String? _currentArtist;
  bool _isPlaying = false;
  double _playbackPosition = 0.0;
  double _songDuration = 0.0;
  
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
        } else {
          _partnerUsername = document.data['host_username'];
        }
        
        // Load current song if exists
        final songId = document.data['song_id'];
        if (songId != null && songId.toString().isNotEmpty) {
          _currentSongUrl = songId;
          _currentSongName = document.data['current_song_name'];
          _currentArtist = document.data['current_artist_name'];
          _currentImageUrl = document.data['album_art_url'];
          _isPlaying = document.data['is_playing'] ?? false;
          _playbackPosition = (document.data['playbackPosition'] ?? 0.0).toDouble();
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
        _updateSessionPlayback();
      }
    };

    _audioService.onPositionChanged = (position) {
      if (mounted) {
        setState(() {
          _playbackPosition = position.inSeconds.toDouble();
        });
      }
    };

    _audioService.onDurationChanged = (duration) {
      if (mounted) {
        setState(() {
          _songDuration = duration!.inSeconds.toDouble();
        });
      }
    };

    _audioService.onComplete = () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = 0.0;
        });
        _updateSessionPlayback();
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
      } else {
        _partnerUsername = updatedDocument.data['host_username'];
      }
      
      // Update current song from session
      final songId = updatedDocument.data['song_id'];
      if (songId != null && songId.toString().isNotEmpty && songId != _currentSongUrl) {
        _currentSongUrl = songId;
        _currentSongName = updatedDocument.data['current_song_name'];
        _currentArtist = updatedDocument.data['current_artist_name'];
        _currentImageUrl = updatedDocument.data['album_art_url'];
        
        // Auto-load song for partner
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
      
      // Update playback state
      final isPlaying = updatedDocument.data['is_playing'] ?? false;
      final position = (updatedDocument.data['playbackPosition'] ?? 0.0).toDouble();
      
      if (_isPlaying != isPlaying) {
        _isPlaying = isPlaying;
        if (isPlaying) {
          _audioService.play();
        } else {
          _audioService.pause();
        }
      }
      
      // Update position if significant difference
      if ((_playbackPosition - position).abs() > 3.0) {
        _playbackPosition = position;
        _audioService.seek(Duration(seconds: position.toInt()));
      }
    });
  }

  Future<void> _updateSessionPlayback() async {
    if (_sessionId == null) return;
    
    try {
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'current_position': _playbackPosition.toInt(),
          'playbackPosition': _playbackPosition,
          'is_playing': _isPlaying,
          'last_sync_time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error updating session playback: $e');
    }
  }

  // NEW: Song Selection Logic
  Future<void> _selectSong() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.greenAccent),
                SizedBox(height: 16),
                Text(
                  'Loading your music...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Get user's music library
      final userMusic = await _socialService.listDocuments(
        collectionId: 'musics',
        queries: [
          Query.equal('user_id', _currentUserId!),
          Query.orderDesc('\$createdAt'),
        ],
      );

      // Close loading
      Navigator.pop(context);

      if (userMusic.documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No songs found in your library. Upload some music first!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show song selection dialog
      final selectedSong = await _showSongSelectionDialog(userMusic.documents);
      
      if (selectedSong != null) {
        await _playSong(selectedSong);
      }
    } catch (e) {
      // Close loading if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print('Error selecting song: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading music library: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Song Selection Dialog
  Future<homie.Album?> _showSongSelectionDialog(List<Document> songs) async {
    return await showDialog<homie.Album>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.queue_music, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'Select Song',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final data = song.data;
              
              return Card(
                color: Colors.grey[800],
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: data['image_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['image_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.music_note,
                                  color: Colors.greenAccent,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.music_note,
                            color: Colors.greenAccent,
                          ),
                  ),
                  title: Text(
                    data['name'] ?? 'Unknown Song',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    data['artist'] ?? 'Unknown Artist',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.play_circle_outline,
                    color: Colors.greenAccent,
                  ),
                  onTap: () {
                    final album = homie.Album(
                      data['name'] ?? 'Unknown Song',
                      data['download_url'] ?? '',
                      data['image_url'],
                      artist: data['artist'] ?? 'Unknown Artist',
                    );
                    Navigator.pop(context, album);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _playSong(homie.Album album) async {
    try {
      setState(() {
        _currentSongName = album.name;
        _currentSongUrl = album.downloadUrl;
        _currentImageUrl = album.imageUrl;
        _currentArtist = album.artist;
      });
      
      await _audioService.stop();
      await _audioService.playSong(album);
      
      setState(() {
        _isPlaying = false;
        _playbackPosition = 0.0;
      });
      
      // Update session with new song info
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'song_id': album.downloadUrl,
          'current_song_name': album.name,
          'current_artist_name': album.artist ?? 'Unknown Artist',
          'album_art_url': album.imageUrl,
          'current_position': 0,
          'playbackPosition': 0.0,
          'is_playing': false,
          'last_sync_time': DateTime.now().toIso8601String(),
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 Song loaded: ${album.name}'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error playing song: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing song: $e'),
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
      
      await _audioService.stop();
      await _audioService.playSong(album);
      
      setState(() {
        _isPlaying = false;
        _playbackPosition = 0.0;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 Partner changed song: ${album.name}'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error loading song: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioService.pause();
      } else {
        await _audioService.play();
      }
      
      setState(() {
        _isPlaying = !_isPlaying;
      });
      
      // Update session immediately
      await _updateSessionPlayback();
    } catch (e) {
      print('Error toggling playback: $e');
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
                'Currently Playing',
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
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withOpacity(0.2),
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.greenAccent,
                  ),
                  iconSize: 48,
                  onPressed: _togglePlayPause,
                ),
              ),
              SizedBox(width: 20),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withOpacity(0.2),
                ),
                child: IconButton(
                  icon: Icon(Icons.queue_music, color: Colors.greenAccent),
                  iconSize: 32,
                  onPressed: _selectSong,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Progress slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.greenAccent,
              inactiveTrackColor: Colors.grey[700],
              thumbColor: Colors.greenAccent,
              overlayColor: Colors.greenAccent.withOpacity(0.2),
            ),
            child: Slider(
              value: _playbackPosition.clamp(0, _songDuration),
              min: 0,
              max: _songDuration > 0 ? _songDuration : 1,
              onChanged: (value) {
                setState(() {
                  _playbackPosition = value;
                });
                _audioService.seek(Duration(seconds: value.toInt()));
                // Update session with new position
                _updateSessionPlayback();
              },
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
                              _currentSongName ?? 'No song playing',
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
                          _isPlaying ? Icons.play_arrow : Icons.pause,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Both users share the same music session. Changes made by either user will be reflected for both.',
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