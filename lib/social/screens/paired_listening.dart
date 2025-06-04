import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/screens/profile2.dart';
import 'package:musicgram4/services/appwrite_service.dart' as service;
import 'package:musicgram4/services/audio_player_service.dart';
import 'package:musicgram4/social/models/paired_session.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:musicgram4/screens/homie.dart';
import 'package:musicgram4/social/screens/song_selection_screen.dart'; // Import the Album class from homie.dart
import 'package:musicgram4/screens/homie.dart' as homie;
import 'dart:math'; // For Random used in _generatesessionName
import 'package:flutter/services.dart'; // For TextInputFormatter and Clipboard
import 'dart:convert'; // For JSON operations if needed

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
  String? _currentArtist;
  double _playbackPosition = 0.0;
  double _songDuration = 0.0;
  
  Timer? _syncTimer;
  Timer? _pollingTimer;
  RealtimeSubscription? _sessionSubscription;
  
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  
  // Add this to your fields
  String? _currentChatId;

  // Add this method to create a chat for the session
  Future<void> _initializeSessionChat() async {
    if (_sessionId == null) return;
    
    try {
      // Create a chat document linked to this session
      final chatDoc = await _socialService.createDocument(
        collectionId: 'session_chats',
        data: {
          'session_id': _sessionId,
          'created_at': DateTime.now().toIso8601String(),
          'messages': [], // Will store the messages array
        },
      );
      
      _currentChatId = chatDoc.$id;
      
      // Subscribe to chat updates
      _setupChatSubscription();
    } catch (e) {
      print('Error creating session chat: $e');
    }
  }

  // Add chat subscription
  RealtimeSubscription? _chatSubscription;

  void _setupChatSubscription() {
    if (_currentChatId == null) return;
    
    try {
      final realtime = Realtime(service.AppwriteService.client);
      
      _chatSubscription = realtime.subscribe([
        'databases.${AppConfig.databaseId}.collections.session_chats.documents.$_currentChatId'
      ]);
      
      _chatSubscription!.stream.listen(
        (response) {
          print('Received chat update: ${response.events}');
          if (response.events.contains('databases.*.collections.*.documents.*.update')) {
            final chatDoc = Document.fromMap(response.payload);
            final List<dynamic> messagesData = chatDoc.data['messages'] ?? [];
            
            setState(() {
              _messages = messagesData.map((m) => Map<String, dynamic>.from(m)).toList();
            });
          }
        },
        onError: (error) {
          print('Chat subscription error: $error');
        },
      );
    } catch (e) {
      print('Error setting up chat subscription: $e');
    }
  }

  // Update message sending
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _currentChatId == null) return;
    
    final message = {
      'sender_id': _currentUserId,
      'sender_name': _currentUsername ?? 'You',
      'text': _messageController.text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Optimistically update UI
    setState(() {
      _messages.add(message);
      _messageController.clear();
    });
    
    try {
      // Get current messages
      final chatDoc = await _socialService.getDocument(
        collectionId: 'session_chats',
        documentId: _currentChatId!,
      );
      
      List<dynamic> existingMessages = chatDoc.data['messages'] ?? [];
      existingMessages.add(message);
      
      // Update the document with new messages
      await _socialService.updateDocument(
        collectionId: 'session_chats',
        documentId: _currentChatId!,
        data: {
          'messages': existingMessages,
        },
      );
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    }
  }
  
  // Add to _PairedListeningScreenState class fields
  String? _sessionName;

  // Add this method to generate session codes
  String _generateSessionName() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }
  
  @override
  void initState() {
    super.initState();
    
    _socialService = SocialDatabaseService(
      databases: databases,
      storage: storage,
      account: account
    );
    
    // Add explicit debugging to trace audio issues
    print('Initializing audio service for paired listening');
    _audioService.init();
    
    // You're using onPlayPause, but your AudioPlayerService 
    // might have separate onPlay and onPause callbacks
    _audioService.onPlayPause = () {
      print('AudioService onPlayPause callback fired');
      // This function should check the current state, not just set it
      setState(() {
        _isPlaying = _audioService.isPlaying;
      });
      if (_isHost) _updateSessionPlayback();
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
    
    // Use the correct callback name for song completion
    _audioService.onComplete = () {
      // Just stop playing when song ends - no queue handling
      setState(() {
        _isPlaying = false;
      });
      
      if (_isHost) {
        _updateSessionPlayback();
      }
    };
    
    _initSession();
  }
  
  void _showSessionCodeDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Session Code',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Text(
                'Give this code to your friend so they can join your listening session:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[300],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _sessionName ?? 'ERROR',
                      style: GoogleFonts.robotoMono(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _sessionName ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Code copied to clipboard'),
                      backgroundColor: Colors.greenAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text(
                      'Copy Code',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Continue',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
  
  // Core part of the _initSession() method for PairedListeningScreen
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
      
      if (!_isHost && _session?.status == SessionStatus.waiting) {
        // Join as guest
        await _socialService.updateDocument(
          collectionId: 'paired_sessions',
          documentId: _sessionId!,
          data: {
            'guest_user_id': _currentUserId,
            'guest_username': _currentUsername,
            'status': SessionStatus.active.value,
          },
        );
        await _fetchSession();
      }
      
      // Try to set up chat, but don't fail if collection doesn't exist
      try {
        // Check if session already has a chat
        final sessionChats = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: 'session_chats',
          queries: [Query.equal('session_id', _sessionId!)],
        );
        
        if (sessionChats.documents.isNotEmpty) {
          _currentChatId = sessionChats.documents.first.$id;
          
          // Load existing messages
          final messages = sessionChats.documents.first.data['messages'] ?? [];
          setState(() {
            _messages = List<Map<String, dynamic>>.from(messages);
          });
          
          // Set up chat subscription
          _setupChatSubscription();
        } else if (_isHost) {
          // Create a new chat if host
          await _initializeSessionChat();
        }
      } catch (e) {
        print('Chat functionality unavailable: $e');
        // Continue without chat functionality
      }
    } else {
      // Creating a new open session
      _isHost = true;
      
      try {
        // Generate a unique session code
        _sessionName = _generateSessionName();
        
        // Add to session creation data
        final session = await _socialService.createDocument(
          collectionId: 'paired_sessions',
          data: {
            'host_user_id': _currentUserId!,
            'host_username': _currentUsername!,
            'guest_user_id': 'pending',
            'guest_username': 'Waiting for partner...',
            'status': SessionStatus.waiting.value,
            'song_id': 'default_song',
            'current_position': 0,
            'is_playing': false,
            'created_at': DateTime.now().toIso8601String(),
            'last_sync_time': DateTime.now().toIso8601String(),
            'chat_enabled': true,
            'host_avatar_id': null,
            'session_name': _sessionName,  // Use this as the code
          },
        );
        
        _sessionId = session.$id;
        
        // Try to initialize chat, but don't fail if it doesn't work
        try {
          await _initializeSessionChat();
        } catch (e) {
          print('Chat functionality unavailable: $e');
          // Continue without chat functionality
        }
        
        // Show the code to the host
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSessionCodeDialog();
        });
        
        await _fetchSession();
      } catch (e) {
        print('Error creating open session: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating session: $e')),
        );
      }
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
  
  // Update _fetchSession to better handle song loading for guests
  Future<void> _fetchSession() async {
    if (_sessionId == null) return;
    
    try {
      final document = await _socialService.getDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
      );
      
      print('Fetched session data: ${document.data}');
      
      setState(() {
        _session = PairedSession.fromDocument(document);
        _currentSongName = _session?.currentSongName;
        _currentArtist = _session?.currentArtistName;
        _currentImageUrl = _session?.imageUrl;
        _currentSongUrl = _session?.currentSongUrl ?? document.data['current_song_url'];
        
        if (_session?.playbackPosition != null) {
          _playbackPosition = _session!.playbackPosition!;
        }
        
        _isPlaying = _session?.isPlaying ?? false;
      });
      
      // If we have a song and we're the guest, load it
      if (_currentSongUrl != null && !_isHost) {
        print('Guest is loading song: $_currentSongUrl');
        final album = homie.Album(
          _currentSongName ?? 'Unknown Song',
          _currentSongUrl!,
          _currentImageUrl,
          artist: _currentArtist,
        );
        
        await _audioService.stop();
        await _audioService.playSong(album);
        
        if (_isPlaying) {
          await _audioService.play();
        }
        
        if (_playbackPosition > 0) {
          await _audioService.seek(Duration(seconds: _playbackPosition.toInt()));
        }
      }
    } catch (e) {
      print(e);
    }
  }
  
  void _startPolling() {
    // For host, periodically update playback position only
    if (_isHost) {
      _syncTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        if (_isPlaying) {
          _updateSessionPlayback();
        }
      });
    }
    // For guests, add a fallback polling mechanism that only checks 
    // if realtime updates aren't working
    else {
      _pollingTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
        print('GUEST POLL: Checking for updates');
        
        try {
          final document = await _socialService.getDocument(
            collectionId: 'paired_sessions', 
            documentId: _sessionId!,
          );
          
          // Extract song URL from song_id
          final songId = document.data['song_id'];
          final songUrl = (songId != null && songId.toString().startsWith('http')) ? songId : null;
          
          // Only take action if we don't have a song URL but the server does
          if (_currentSongUrl == null && songUrl != null && songUrl != 'default_song') {
            print('GUEST POLL: Found song URL on server but not locally: $songUrl');
            
            final album = homie.Album(
              document.data['current_song_name'] ?? 'Unknown Song',
              songUrl,
              document.data['album_art_url'],
              artist: document.data['current_artist_name'],
            );
            
            await _forceLoadGuestSong(album, document.data['is_playing'] ?? false, 
                                document.data['current_position'] ?? 0);
          }
        } catch (e) {
          print('GUEST POLL: Error: $e');
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
          'current_position': _playbackPosition.toInt(), // Convert to integer
          'is_playing': _isPlaying,
          'last_sync_time': DateTime.now().toIso8601String(),
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
      // CRITICAL FIX: Store the URL in song_id, not just a reference ID
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'song_id': songUrl,  // Store the full URL here
          'current_song_name': songName,
          'current_artist_name': album.artist ?? 'Unknown Artist',
          'album_art_url': imageUrl,  // Store the image URL
          'current_position': 0,
          'is_playing': true,
          'last_sync_time': DateTime.now().toIso8601String(),
        },
      );
      print('Host: Updated session with song URL: $songUrl');
    }
  } catch (e) {
    print('Error playing song: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error playing song: $e')),
    );
  }
}
  
  Future<void> _loadAndPlaySong(String url, String? name, String? artist, String? imageUrl, bool autoPlay) async {
  try {
    // Create an Album object to match how homie.dart handles songs
    final album = homie.Album(
      name ?? 'Unknown Song',
      url,
      imageUrl,
      artist: artist ?? 'Unknown Artist',
    );
    
    await _audioService.playSong(album);
    
    if (autoPlay) {
      _audioService.play();
      setState(() {
        _isPlaying = true;
      });
    } else {
      _audioService.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  } catch (e) {
    print('Error loading song: $e');
  }
}
  
  void _togglePlayPause() {
  print('DEBUG: Toggle play/pause called, current state: $_isPlaying');
  
  if (_currentSongUrl == null) {
    print('DEBUG: No song selected, cannot toggle playback');
    if (_isHost) {
      _selectSong();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Waiting for host to select a song')),
      );
    }
    return;
  }
  
  // Don't allow guests to toggle playback
  if (!_isHost) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Only the host can control playback')),
    );
    return;
  }
  
  // Set state AFTER audio operation succeeds
  if (_isPlaying) {
    print('DEBUG: Pausing playback');
    _audioService.pause().then((_) {
      setState(() {
        _isPlaying = false;
      });
      
      _updateSessionPlayback();
    });
  } else {
    print('DEBUG: Starting playback');
    _audioService.play().then((_) {
      setState(() {
        _isPlaying = true;
      });
      
      _updateSessionPlayback();
    });
  }
}
  
  Future<void> _endSession() async {
    if (_sessionId == null) return;
    
    try {
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'status': SessionStatus.ended.value,
          'ended_at': DateTime.now().toIso8601String(),
          'is_playing': false,
        },
      );
      
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
    print('DEBUG: Opening song selection');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          inSelectionMode: true,
          onSongSelected: (album) {
            print('DEBUG: Song selected in HomePage: ${album.name}, URL: ${album.downloadUrl}');
            Navigator.pop(context, album);
          },
        ),
      ),
    );
    
    if (result != null && result is homie.Album) {
      print('DEBUG: Returned to paired listening with album: ${result.name}');
      print('DEBUG: Album URL: ${result.downloadUrl}');
      await _playSongWithAlbum(result);
    } else {
      print('DEBUG: No song selected or invalid result type: $result');
    }
  } catch (e) {
    print('ERROR in song selection: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error selecting song')),
    );
  }
}

  // Handle playing with Album object
  Future<void> _playSongWithAlbum(homie.Album album) async {
  try {
    print('HOST: Starting to play song: ${album.name}');
    print('HOST: Song URL: ${album.downloadUrl}');
    
    setState(() {
      _currentSongName = album.name;
      _currentSongUrl = album.downloadUrl;
      _currentImageUrl = album.imageUrl;
      _currentArtist = album.artist;
    });
    
    await _audioService.stop();
    await _audioService.playSong(album);
    await _audioService.play();
    
    setState(() {
      _isPlaying = true;
    });
    
    // CRITICAL: Store URL in song_id field and ensure all metadata is present
    if (_isHost && _sessionId != null) {
      print('HOST: Updating database with song URL in song_id field');
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'song_id': album.downloadUrl,  // Store the full URL in song_id
          'current_song_name': album.name,
          'current_artist_name': album.artist ?? 'Unknown Artist',
          'album_art_url': album.imageUrl,
          'current_position': 0,
          'is_playing': true,
          'last_sync_time': DateTime.now().toIso8601String(),
        },
      );
    }
  } catch (e) {
    print('ERROR playing song: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error playing song: $e')),
    );
  }
}
  
  // Add method to add song to queue
  // Future<void> _addToQueue(homie.Album album) async {
  //   setState(() {
  //     _songQueue.add(album);
  //   });
    
  //   // If no song is currently playing, start playing this one
  //   if (_currentQueueIndex == -1 || _songQueue.length == 1) {
  //     await _playNextInQueue();
  //   }
    
  //   // Update session with queue data if host
  //   if (_isHost && _sessionId != null) {
  //     final queueData = _songQueue.map((album) => {
  //       'id': album.id,
  //       'name': album.name,
  //       'download_url': album.downloadUrl,
  //       'image_url': album.imageUrl,
  //       'artist': album.artist,
  //     }).toList();
      
  //     await _socialService.updateDocument(
  //       collectionId: 'paired_sessions',
  //       documentId: _sessionId!,
  //       data: {
  //         'song_queue': queueData,
  //         'current_queue_index': _currentQueueIndex,
  //       },
  //     );
  //   }
  // }

  // Add method to play next song in queue
  // Future<void> _playNextInQueue() async {
  //   if (_songQueue.isEmpty) return;
    
  //   // Move to next song, or loop back to first if at end
  //   _currentQueueIndex = (_currentQueueIndex + 1) % _songQueue.length;
    
  //   // Play the song
  //   final nextSong = _songQueue[_currentQueueIndex];
  //   await _playSongWithAlbum(nextSong);
    
  //   // Update session with current index
  //   if (_isHost && _sessionId != null) {
  //     await _socialService.updateDocument(
  //       collectionId: 'paired_sessions',
  //       documentId: _sessionId!,
  //       data: {
  //         'current_queue_index': _currentQueueIndex,
  //       },
  //     );
  //   }
  // }
  
  // Add method to play previous song in queue
  // Future<void> _playPreviousInQueue() async {
  //   if (_songQueue.isEmpty) return;
    
  //   // Move to previous song, or loop to last if at beginning
  //   _currentQueueIndex = (_currentQueueIndex - 1 + _songQueue.length) % _songQueue.length;
    
  //   // Play the song
  //   final prevSong = _songQueue[_currentQueueIndex];
  //   await _playSongWithAlbum(prevSong);
    
  //   // Update session with current index
  //   if (_isHost && _sessionId != null) {
  //     await _socialService.updateDocument(
  //       collectionId: 'paired_sessions',
  //       documentId: _sessionId!,
  //       data: {
  //         'current_queue_index': _currentQueueIndex,
  //       },
  //     );
  //   }
  // }
  
  void _sendLocalMessage() {
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
  
  // Helper method to format ISO timestamp to human-readable time
String _formatTimestamp(String? timestamp) {
  if (timestamp == null || timestamp.isEmpty) return '';
  
  try {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    
    if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  } catch (e) {
    print('Error formatting timestamp: $e');
    return '';
  }
}
  
  // Update the realtime subscription method to handle song changes better
  void _setupRealtimeSubscription() {
  if (_sessionId == null) return;
  
  try {
    final realtime = Realtime(service.AppwriteService.client);
    
    _sessionSubscription = realtime.subscribe([
      'databases.${AppConfig.databaseId}.collections.paired_sessions.documents.$_sessionId'
    ]);
    
    _sessionSubscription!.stream.listen(
      (response) {
        print('Received session update: ${response.events}');
        if (response.events.contains('databases.*.collections.*.documents.*.update')) {
          final updatedDocument = Document.fromMap(response.payload);
          print('Document updated: ${updatedDocument.data}');
          
          if (mounted) {
            // Guest-specific handling
            if (!_isHost) {
              // Extract song URL from song_id - THIS IS CRITICAL
              final songId = updatedDocument.data['song_id'];
              final songUrl = (songId != null && songId.toString().startsWith('http')) ? songId : null;
              final songName = updatedDocument.data['current_song_name'];
              final artistName = updatedDocument.data['current_artist_name'];
              final imageUrl = updatedDocument.data['album_art_url'];
              final isPlaying = updatedDocument.data['is_playing'] ?? false;
              final position = updatedDocument.data['current_position'] ?? 0;
              
              print('GUEST REALTIME: Received update - songId: $songId');
              print('GUEST REALTIME: songUrl extracted: $songUrl');
              print('GUEST REALTIME: songName: $songName');
              print('GUEST REALTIME: isPlaying: $isPlaying');
              print('GUEST REALTIME: Current local URL: $_currentSongUrl');
              
              // Handle song URL if it exists and is not 'default_song'
              if (songUrl != null && songUrl != 'default_song') {
                print('GUEST REALTIME: Valid song URL detected');
                
                if (_currentSongUrl != songUrl) {
                  print('GUEST REALTIME: New song detected, loading: $songName with URL: $songUrl');
                  
                  // Update state first for UI feedback
                  setState(() {
                    _currentSongUrl = songUrl;
                    _currentSongName = songName;
                    _currentArtist = artistName;
                    _currentImageUrl = imageUrl;
                  });
                  
                  // Create album and play it
                  final album = homie.Album(
                    songName ?? 'Unknown Song',
                    songUrl,
                    imageUrl,
                    artist: artistName,
                  );
                  
                  _forceLoadGuestSong(album, isPlaying, position);
                } 
                // If URL is the same but play state changed
                else if (_isPlaying != isPlaying) {
                  print('GUEST REALTIME: Play state changed to: $isPlaying');
                  
                  if (isPlaying) {
                    _audioService.play();
                  } else {
                    _audioService.pause();
                  }
                  setState(() {
                    _isPlaying = isPlaying;
                  });
                }
                
                // Update position if needed
                if (_playbackPosition.toInt() != position && position > 0) {
                  _audioService.seek(Duration(seconds: position));
                  setState(() {
                    _playbackPosition = position.toDouble();
                  });
                }
              }
            }
            
            // Update the session for both host and guest
            setState(() {
              _session = PairedSession.fromDocument(updatedDocument);
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
  
  Widget _buildStatusCard() {
  final otherUser = _isHost
      ? _session?.guestUsername ?? 'Waiting for partner...'
      : _session?.hostUsername ?? 'Unknown host';
  
  final sessionStatus = _session?.status ?? SessionStatus.waiting;
  final isActive = sessionStatus == SessionStatus.active;
  
  return Container(
    margin: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          // Session status icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? Colors.greenAccent.withOpacity(0.2) : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive ? Icons.people : Icons.hourglass_empty,
              color: isActive ? Colors.greenAccent : Colors.grey,
            ),
          ),
          
          SizedBox(width: 16),
          
          // Session info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.greenAccent : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      isActive ? 'Active Session' : 'Waiting for partner',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  _isHost 
                    ? 'You are hosting for: $otherUser'
                    : 'Connected with: $otherUser',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          
          // Session code for host
          if (_isHost && _sessionName != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.greenAccent, width: 1),
              ),
              child: Row(
                children: [
                  Text(
                    _sessionName!,
                    style: GoogleFonts.robotoMono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _sessionName!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Code copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
  
  @override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Text(
        'Paired Listening',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.close, color: Colors.white),
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
                'Setting up your session...',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              )
            ],
          ),
        )
      : Column(
          children: [
            // Session status card
            _buildStatusCard(),
            
            // Main content area with music player and chat
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    // Tab bar
                    Container(
                      color: Colors.black,
                      child: TabBar(
                        indicatorColor: Colors.greenAccent,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(text: 'Now Playing'),
                          Tab(text: 'Chat'),
                        ],
                      ),
                    ),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Now Playing tab
                          SingleChildScrollView(
                            child: _buildNowPlayingSection(),
                          ),
                          
                          // Chat tab
                          _buildChatSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
  );
}

Widget _buildNowPlayingSection() {
  return Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Album art - clean and simple
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _currentImageUrl != null
            ? Image.network(
                _currentImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderArt();
                },
              )
            : _buildPlaceholderArt(),
        ),
        
        SizedBox(height: 32),
        
        // Song info
        Text(
          _currentSongName ?? 'No song selected',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 6),
        
        Text(
          _currentArtist ?? 'Select a song to start listening',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey[400],
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 32),
        
        // Playback controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Select song button (for host only)
            if (_isHost)
              IconButton(
                icon: Icon(Icons.playlist_add, color: Colors.white, size: 26),
                onPressed: _selectSong,
                tooltip: 'Select Song',
              ),
            
            SizedBox(width: 20),
            
            // Play/Pause button
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _isHost ? Colors.greenAccent : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                  size: 32,
                ),
                onPressed: _isHost ? _togglePlayPause : null,
              ),
            ),
            
            SizedBox(width: 20),
            
            // Session information icon
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white, size: 26),
              onPressed: () {
                // Show session info dialog
                _showSessionInfoDialog();
              },
              tooltip: 'Session Info',
            ),
          ],
        ),
        
        SizedBox(height: 32),
        
        // Progress bar
        Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.greenAccent,
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.white,
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
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  Text(
                    _formatDuration(_songDuration),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Now playing status
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPlaying ? Icons.graphic_eq : Icons.music_note,
                color: _isPlaying ? Colors.greenAccent : Colors.grey,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                _isPlaying ? 'Now Playing' : 'Paused',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _isPlaying ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        
        // Troubleshooting section - only visible to guests
        if (_currentSongUrl != null)
          Container(
            margin: EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Text(
                  'Troubleshooting',
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Song URL: ${_currentSongUrl!.substring(0, min(30, _currentSongUrl!.length))}...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.play_circle),
                  label: Text('Force Direct Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    try {
                      // Create a completely new player instance for testing
                      final testPlayer = AudioPlayer();
                      await testPlayer.setUrl(_currentSongUrl!);
                      await testPlayer.play();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Testing direct playback...'))
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'))
                      );
                      print('Direct playback failed: $e');
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _buildPlaceholderArt() {
  return Container(
    color: Colors.grey[900],
    child: Center(
      child: Icon(
        Icons.music_note,
        size: 80,
        color: Colors.grey[700],
      ),
    ),
  );
}

void _showSessionInfoDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        'Session Information',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status', _session?.status == SessionStatus.active ? 'Active' : 'Waiting'),
          _buildInfoRow('Host', _session?.hostUsername ?? 'Unknown'),
          _buildInfoRow('Guest', _session?.guestUsername ?? 'Waiting...'),
          _buildInfoRow('Your Role', _isHost ? 'Host' : 'Guest'),
          if (_sessionName != null)
            _buildInfoRow('Session Code', _sessionName!),
          _buildInfoRow('Created', _formatTimestamp(_session?.createdAt?.toString() ?? '')),
        ],
      ),
      actions: [
        TextButton(
          child: Text(
            'Close',
            style: GoogleFonts.poppins(color: Colors.greenAccent),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildChatSection() {
  // Check if chat is available
  final bool isChatAvailable = _currentChatId != null;
  
  if (!isChatAvailable) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble,
            size: 64,
            color: Colors.grey[700],
          ),
          SizedBox(height: 24),
          Text(
            'Chat is unavailable',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'The chat functionality is not available for this session.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Focus on enjoying the music together!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.greenAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  return Column(
    children: [
      // Messages list
      Expanded(
        child: _messages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Colors.grey[700],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Share your thoughts about the music!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['sender_id'] == _currentUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(
                      top: 8,
                      bottom: 8,
                      left: isMe ? 80 : 0,
                      right: isMe ? 0 : 80,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.greenAccent.withOpacity(0.2) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMe ? Colors.greenAccent.withOpacity(0.3) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              message['sender_name'] ?? 'User',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                        Text(
                          message['text'],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isMe ? Colors.white : Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            _formatTimestamp(message['timestamp']),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
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
      Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(
            top: BorderSide(color: Colors.grey[800]!, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 3,
              ),
            ),
            SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.black),
                onPressed: () {
                  if (_messageController.text.isEmpty) return;
                  
                  if (_currentChatId == null) {
                    // If no chat has been initialized yet, create one
                    _initializeSessionChat().then((_) {
                      _sendMessage();
                    });
                  } else {
                    _sendMessage();
                  }
                },
                tooltip: 'Send Message',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Future<void> _loadGuestSong(homie.Album album, bool play, int position) async {
  try {
    print('GUEST: Loading song ${album.name} with URL ${album.downloadUrl}');
    
    // Stop current playback
    await _audioService.stop();
    print('GUEST: Stopped previous playback');
    
    // Load the new song
    await _audioService.playSong(album);
    print('GUEST: Loaded new song');
    
    // Play or pause based on current session state
    if (play) {
      await _audioService.play();
      print('GUEST: Started playback');
      
      setState(() {
        _isPlaying = true;
      });
    } else {
      await _audioService.pause();
      print('GUEST: Paused playback');
      
      setState(() {
        _isPlaying = false;
      });
    }
    
    // Seek to the correct position if needed
    if (position > 0) {
      await _audioService.seek(Duration(seconds: position));
      print('GUEST: Seeked to position $position');
    }
  } catch (e) {
    print('ERROR loading guest song: $e');
  }
}

Future<void> _forceLoadGuestSong(homie.Album album, bool play, int position) async {
  try {
    print('GUEST: Force loading song ${album.name}');
    print('GUEST: URL: ${album.downloadUrl}');
    
    if (album.downloadUrl == null || album.downloadUrl.isEmpty) {
      print('GUEST ERROR: Invalid URL provided');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Invalid song URL'))
      );
      return;
    }
    
    // Show loading feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loading song...'))
    );
    
    // Update UI first for feedback
    setState(() {
      _currentSongName = album.name;
      _currentSongUrl = album.downloadUrl;
      _currentImageUrl = album.imageUrl;
      _currentArtist = album.artist;
    });
    
    // CRITICAL FIX: Reset audio player completely

    // Try direct URL method first
    try {
      print('GUEST: Trying direct URL playback');
   
      print('GUEST: Direct URL method succeeded');
      
      setState(() { _isPlaying = true; });
      
      // Seek to position if needed
      if (position > 0) {
        await _audioService.seek(Duration(seconds: position));
      }
      
      // This approach worked, so return
      print('GUEST: Song playback setup complete via direct method');
      return;
    } catch (e) {
      print('GUEST ERROR: Direct playback failed: $e');
    }
    
    // If direct method failed, try the standard approach
    print('GUEST: Falling back to standard playback method');
    
    // Load with retry logic
    bool loaded = false;
    for (int i = 0; i < 3 && !loaded; i++) {
      try {
        await _audioService.playSong(album);
        loaded = true;
        print('GUEST: Song loaded successfully on attempt ${i+1}');
      } catch (e) {
        print('GUEST ERROR: Loading attempt ${i+1} failed: $e');
        await Future.delayed(Duration(milliseconds: 800));
      }
    }
    
    if (!loaded) {
      print('GUEST ERROR: All loading attempts failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load song after multiple attempts'))
      );
      return;
    }
    
    // Set playback state
    if (play) {
      await _audioService.play();
      setState(() { _isPlaying = true; });
    } else {
      await _audioService.pause();
      setState(() { _isPlaying = false; });
    }
    
    // Set position
    if (position > 0) {
      await _audioService.seek(Duration(seconds: position));
    }
    
    print('GUEST: Song playback setup complete');
    
    // Success notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Now playing: ${album.name}'))
    );
  } catch (e) {
    print('FATAL ERROR loading guest song: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error playing song: $e'))
    );
  }
}

// Add a helper method to create a reload button for guests
Widget _buildReloadButton() {
  if (!_isHost && _currentSongUrl != null) {
    return ElevatedButton(
      onPressed: () {
        final album = homie.Album(
          _currentSongName ?? 'Unknown Song',
          _currentSongUrl!,
          _currentImageUrl,
          artist: _currentArtist,
        );
        _forceLoadGuestSong(album, true, _playbackPosition.toInt());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forcing song playback...'))
        );
      },
      child: Text('Reload Song'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
      ),
    );
  }
  return SizedBox.shrink(); // Return empty widget if conditions not met
}}