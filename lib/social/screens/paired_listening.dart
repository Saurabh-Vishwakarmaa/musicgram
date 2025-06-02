import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/services/appwrite_service.dart' as service;
import 'package:musicgram4/services/audio_player_service.dart';
import 'package:musicgram4/social/models/paired_session.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:musicgram4/screens/homie.dart';
import 'package:musicgram4/social/screens/song_selection_screen.dart'; // Import the Album class from homie.dart
import 'package:musicgram4/screens/homie.dart' as homie;

class PairedListeningScreen extends StatefulWidget {
  final String? sessionId;
  final String? guestUserId;
  final String? guestUsername;
  final String? conversationId;
  
  const PairedListeningScreen({
    Key? key,
    this.sessionId,
    this.guestUserId,
    this.guestUsername,
    this.conversationId,
  }) : super(key: key);

  @override
  State<PairedListeningScreen> createState() => _PairedListeningScreenState();
}

class _PairedListeningScreenState extends State<PairedListeningScreen> {
  late SocialDatabaseService _socialService;
  final AudioPlayerService _audioService = AudioPlayerService();
  
  String? _currentUserId;
  String? _currentUsername;
  String? _sessionId;
  PairedSession? _session;
  bool _isHost = false;
  bool _isLoading = true;
  bool _isPlaying = false;
  String? _currentSongName;
  String? _currentSongUrl;
  String? _currentImageUrl;
  double _playbackPosition = 0.0;
  double _songDuration = 0.0;
  
  Timer? _syncTimer;
  Timer? _pollingTimer;
  RealtimeSubscription? _sessionSubscription;
  
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  
  @override
  void initState() {
    super.initState();
    
    _socialService = SocialDatabaseService(
      databases: databases,
      storage: storage,
      account: account
    );
    
    _audioService.init();
    
    // Set up audio service callbacks
    _audioService.onPlayPause = () {
      setState(() {
        _isPlaying = _audioService.isPlaying;
      });
      
      if (_session != null && _isHost) {
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
      if (duration != null && mounted) {
        setState(() {
          _songDuration = duration.inSeconds.toDouble();
        });
      }
    };
    
    _initSession();
  }
  
  @override
  void dispose() {
    _syncTimer?.cancel();
    _pollingTimer?.cancel();
    _sessionSubscription?.close();
    _audioService.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  Future<void> _initSession() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user
      final user = await account.get();
      _currentUserId = user.$id;
      
      // Get user profile to get the username
      final userProfiles = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.userProfilesCollection,
        queries: [Query.equal('user_id', _currentUserId!)],
      );
      
      if (userProfiles.documents.isNotEmpty) {
        _currentUsername = userProfiles.documents.first.data['display_name'];
      } else {
        _currentUsername = 'User';
      }
      
      if (widget.sessionId != null) {
        // Joining an existing session
        _sessionId = widget.sessionId;
        await _fetchSession();
        
        _isHost = _session?.hostUserId == _currentUserId;
        
        if (!_isHost && _session?.status == 'waiting') {
          // Join as guest
          await _socialService.updateDocument(
            collectionId: 'paired_sessions',
            documentId: _sessionId!,
            data: {
              'guest_user_id': _currentUserId,
              'guest_username': _currentUsername,
              'status': 'active',
            }
          );
          await _fetchSession();
        }
      } else if (widget.guestUserId != null && widget.guestUsername != null) {
        // Creating a new session to invite a specific user
        _isHost = true;
        
        final session = await _socialService.createDocument(
          collectionId: 'paired_sessions',
          data: {
            'host_user_id': _currentUserId!,
            'host_username': _currentUsername!,
            'guest_user_id': widget.guestUserId,
            'guest_username': widget.guestUsername,
            'status': 'waiting',
            'song_id': 'default_song', // Always provide a default song ID
            'current_song_name': null,
            'current_artist_name': null,
            'current_song_url': null,
            'image_url': null,
            'current_position': 0,
            'is_playing': false,
            'created_at': DateTime.now().toIso8601String(),
            'ended_at': null,
          },
        );
        
        _sessionId = session.$id;
        
        // If this session is tied to a conversation, update the conversation
        if (widget.conversationId != null) {
          await databases.updateDocument(
            databaseId: AppConfig.databaseId,
            collectionId: 'chat_conversations',
            documentId: widget.conversationId!,
            data: {
              'shared_session_id': _sessionId,
            },
          );
        }
        
        await _fetchSession();
      } else {
        // Creating a new open session
        _isHost = true;
        
        final session = await _socialService.createDocument(
          collectionId: 'paired_sessions',
          data: {
            'host_user_id': _currentUserId!,
            'host_username': _currentUsername!,
            'guest_user_id': null,
            'guest_username': null,
            'status': 'waiting',
            'song_id': 'default_song', // Always provide a default song ID
            'current_song_name': null,
            'current_artist_name': null,
            'current_song_url': null,
            'image_url': null,
            'current_position': 0,
            'is_playing': false,
            'created_at': DateTime.now().toIso8601String(),
            'ended_at': null,
          },
        );
        
        _sessionId = session.$id;
        await _fetchSession();
      }
      
      // Set up realtime subscription
      _setupRealtimeSubscription();
      
      // Start periodic updates
      _startPolling();
      
      // If host and no song selected yet, prompt to select a song
      if (_isHost && _currentSongUrl == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSelectSongPrompt();
        });
      }
      
    } catch (e) {
      print('Error initializing paired session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing session: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showSelectSongPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Select a song to start listening together'),
        action: SnackBarAction(
          label: 'Select',
          onPressed: _selectSong,
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }
  
  Future<void> _fetchSession() async {
    if (_sessionId == null) return;
    
    try {
      final document = await _socialService.getDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
      );
      
      setState(() {
        _session = PairedSession.fromDocument(document);
        _currentSongName = _session?.currentSongName;
        _currentSongUrl = _session?.currentSongUrl;
        _currentImageUrl = _session?.imageUrl;
        
        if (_session?.playbackPosition != null) {
          _playbackPosition = _session!.playbackPosition!;
        }
        
        _isPlaying = _session?.isPlaying ?? false;
      });
      
      // If we have a song and we're the guest, load it
      if (_currentSongUrl != null && !_isHost) {
        await _loadAndPlaySong(_currentSongUrl!, _isPlaying);
        
        if (_playbackPosition > 0) {
          await _audioService.seek(Duration(seconds: _playbackPosition.toInt()));
        }
      }
    } catch (e) {
      print('Error fetching session: $e');
    }
  }
  
  void _startPolling() {
    // Poll for session updates every 3 seconds (for guest)
    if (!_isHost) {
      _pollingTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
        await _fetchSession();
        
        // Sync audio if needed
        if (_session != null && _session!.currentSongUrl != null) {
          if (_currentSongUrl != _session!.currentSongUrl) {
            await _playSong(
              _session!.currentSongName!,
              _session!.currentSongUrl!,
              _session!.imageUrl
            );
          }
          
          // Sync playback position if it's more than 3 seconds off
          if (_session!.playbackPosition != null) {
            final currentPosition = _playbackPosition.toInt();
            if ((currentPosition - _session!.playbackPosition!).abs() > 3) {
              await _audioService.seek(Duration(seconds: _session!.playbackPosition!.toInt()));
            }
          }
          
          // Sync play/pause state
          if (_isPlaying != _session!.isPlaying) {
            if (_session!.isPlaying) {
              _audioService.play();
            } else {
              _audioService.pause();
            }
            setState(() {
              _isPlaying = _session!.isPlaying;
            });
          }
        }
      });
    } else {
      // For host, periodically update playback position
      _syncTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        if (_isPlaying) {
          _updateSessionPlayback();
        }
      });
    }
  }
  
  Future<void> _updateSessionPlayback() async {
    if (_sessionId == null || !_isHost) return;
    
    try {
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'current_position': _playbackPosition,
          'is_playing': _isPlaying,
        },
      );
    } catch (e) {
      print('Error updating session playback: $e');
    }
  }
  
  Future<void> _playSong(String songName, String songUrl, String? imageUrl) async {
    try {
      setState(() {
        _currentSongName = songName;
        _currentSongUrl = songUrl;
        _currentImageUrl = imageUrl;
      });
      
      // Create an Album object
      final album = homie.Album(
        songName,
        songUrl,
        imageUrl,
      );
      
      await _audioService.playSong(album);
      
      setState(() {
        _isPlaying = true;
      });
      
      if (_isHost && _sessionId != null) {
        // Update the session with the new song
        await _socialService.updateDocument(
          collectionId: 'paired_sessions',
          documentId: _sessionId!,
          data: {
            'song_id': 'song_id', // This should be a real ID if available
            'current_song_name': songName,
            'current_song_url': songUrl,
            'image_url': imageUrl,
            'current_position': 0,
            'is_playing': true,
          },
        );
      }
    } catch (e) {
      print('Error playing song: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing song: $e')),
      );
    }
  }
  
  Future<void> _loadAndPlaySong(String url, bool autoplay) async {
    try {
      // Create an Album object for the audio service
      final album = homie.Album(
        _currentSongName ?? 'Unknown',
        url,
        _currentImageUrl,
      );
      
      await _audioService.playSong(album);
      if (!autoplay) {
        _audioService.pause();
      }
    } catch (e) {
      print('Error loading audio: $e');
    }
  }
  
  void _togglePlayPause() {
    if (_isPlaying) {
      _audioService.pause();
    } else {
      _audioService.play();
    }
    
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    if (_isHost) {
      _updateSessionPlayback();
    }
  }
  
  Future<void> _endSession() async {
    if (_sessionId == null) return;
    
    try {
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
          'is_playing': false,
        },
      );
      
      // If this session was tied to a conversation, remove the link
      if (widget.conversationId != null) {
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: 'chat_conversations',
          documentId: widget.conversationId!,
          data: {
            'shared_session_id': null,
          },
        );
      }
      
      // Stop music playback
      _audioService.stop();
      
      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      print('Error ending session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending session: $e')),
      );
    }
  }
  
  Future<void> _selectSong() async {
    if (!_isHost) return;
    
    try {
      // Open song selection screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SongSelectionScreen(),
          fullscreenDialog: true,
        ),
      );
      
      // Check if a song was selected
      if (result != null && result is homie.Album) {
        // Create album object with the correct fields
        final album = homie.Album(
          result.name,
          result.downloadUrl,
          result.imageUrl,
          id: result.id,
          artist: result.artist,
        );
        
        // Play the selected song
        await _playSongWithAlbum(album);
      }
    } catch (e) {
      print('Error selecting song: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting song: $e')),
      );
    }
  }

  // Handle playing with Album object
  Future<void> _playSongWithAlbum(homie.Album album) async {
    try {
      setState(() {
        _currentSongName = album.name;
        _currentSongUrl = album.downloadUrl;
        _currentImageUrl = album.imageUrl;
      });
      
      // Play using audio service
      await _audioService.playSong(album);
      
      setState(() {
        _isPlaying = true;
      });
      
      // Update session if host
      if (_isHost && _sessionId != null) {
        await _socialService.updateDocument(
          collectionId: 'paired_sessions',  // Make sure to use the correct collection name
          documentId: _sessionId!,
          data: {
            'song_id': album.id,
            'current_song_name': album.name,
            'current_artist_name': album.artist ?? 'Unknown Artist',
            'current_song_url': album.downloadUrl,
            'image_url': album.imageUrl,
            'current_position': 0,
            'is_playing': true,
          },
        );
      }
    } catch (e) {
      print('Error playing song: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing song: $e')),
      );
    }
  }
  
  void _sendMessage() {
    if (_messageController.text.isEmpty) return;
    
    final message = {
      'sender': _currentUsername ?? 'You',
      'text': _messageController.text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    setState(() {
      _messages.add(message);
      _messageController.clear();
    });
    
    // In a real app, you would save this message to your database
  }
  
  String _formatDuration(double seconds) {
    final int mins = (seconds / 60).floor();
    final int secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  void _setupRealtimeSubscription() {
    if (_sessionId == null) return;
    
    try {
      // Make sure to use the AppwriteService for consistency
      final realtime = Realtime(service.AppwriteService.client);
      
      print('Setting up paired_sessions subscription for session: $_sessionId');
      
      final subscription = realtime.subscribe([
        'databases.${AppConfig.databaseId}.collections.paired_sessions.documents.$_sessionId'
      ]);
      
      subscription.stream.listen(
        (response) {
          print('Received listening session update: ${response.events}');
          if (response.events.contains('databases.*.collections.*.documents.*.update')) {
            // Process the update as before
            final updatedDocument = Document.fromMap(response.payload);
            
            if (mounted) {
              setState(() {
                _session = PairedSession.fromDocument(updatedDocument);
                
                // Update song if changed
                if (_session?.currentSongUrl != null && _currentSongUrl != _session!.currentSongUrl) {
                  _currentSongName = _session!.currentSongName;
                  _currentSongUrl = _session!.currentSongUrl;
                  _currentImageUrl = _session!.imageUrl;
                  
                  if (!_isHost) {
                    _loadAndPlaySong(_currentSongUrl!, _session!.isPlaying);
                  }
                }
                
                // Remaining code for syncing playback state
              });
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Paired Listening',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.greenAccent),
            onPressed: _endSession,
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : Column(
            children: [
              // Session info card
              _buildSessionCard(),
              
              // Now playing section
              _buildNowPlayingSection(),
              
              // Chat section
              Expanded(
                child: _buildChatSection(),
              ),
            ],
          ),
    );
  }
  
  Widget _buildSessionCard() {
    final otherUser = _isHost
        ? _session?.guestUsername ?? 'Waiting for partner...'
        : _session?.hostUsername ?? 'Unknown host';
    
    final sessionStatus = _session?.status ?? 'waiting';
    
    return Card(
      margin: EdgeInsets.all(16),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Paired Session',
              style: GoogleFonts.firaSansCondensed(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.purple[700],
                  child: Icon(Icons.person, color: Colors.white),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.compare_arrows,
                    color: sessionStatus == 'active' ? Colors.greenAccent : Colors.grey,
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: sessionStatus == 'active' ? Colors.green[700] : Colors.grey[700],
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              _isHost ? 'With $otherUser' : 'With ${_session?.hostUsername}',
              style: GoogleFonts.firaSansCondensed(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              sessionStatus == 'waiting'
                ? 'Waiting for partner to join...'
                : 'Session active',
              style: GoogleFonts.firaSansCondensed(
                fontSize: 14,
                color: sessionStatus == 'active' ? Colors.greenAccent : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNowPlayingSection() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Album art
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _currentImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.music_note,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.music_note,
                        size: 40,
                        color: Colors.white,
                      ),
                ),
                SizedBox(width: 16),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentSongName ?? 'No song playing',
                        style: GoogleFonts.firaSansCondensed(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Text(
                        _isHost ? 'You are controlling playback' : 'Host is controlling playback',
                        style: GoogleFonts.firaSansCondensed(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Progress bar
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.greenAccent,
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.greenAccent,
                overlayColor: Colors.greenAccent.withOpacity(0.2),
              ),
              child: Slider(
                value: _playbackPosition.clamp(0, _songDuration > 0 ? _songDuration : 1),
                min: 0,
                max: _songDuration > 0 ? _songDuration : 1,
                onChanged: _isHost ? (value) {
                  setState(() {
                    _playbackPosition = value;
                  });
                  _audioService.seek(Duration(seconds: value.toInt()));
                  _updateSessionPlayback();
                } : null,
              ),
            ),
            // Time indicators
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_playbackPosition),
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  Text(
                    _formatDuration(_songDuration),
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isHost) IconButton(
                  icon: Icon(Icons.skip_previous, color: Colors.white, size: 36),
                  onPressed: () {
                    // Previous song functionality
                  },
                ),
                SizedBox(width: 16),
                GestureDetector(
                  onTap: _isHost ? _togglePlayPause : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _isHost ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                if (_isHost) IconButton(
                  icon: Icon(Icons.skip_next, color: Colors.white, size: 36),
                  onPressed: () {
                    // Next song functionality
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_isHost) ElevatedButton.icon(
              onPressed: _selectSong,
              icon: Icon(Icons.queue_music),
              label: Text('Select Song'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatSection() {
    return Card(
      margin: EdgeInsets.all(16),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.chat, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text(
                  'Chat',
                  style: GoogleFonts.firaSansCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey[800], height: 1),
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: GoogleFonts.firaSansCondensed(
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender'] == 'You';
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: isMe ? 50 : 0,
                            right: isMe ? 0 : 50,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.purple[700] : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) Text(
                                message['sender'],
                                style: GoogleFonts.firaSansCondensed(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              Text(
                                message['text'],
                                style: GoogleFonts.firaSansCondensed(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Message input
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.firaSansCondensed(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.firaSansCondensed(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// Using the Album class imported from homie.dart Album(this.name, this.downloadUrl, this.imageUrl);
