import 'dart:async';
import 'package:http/http.dart';
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
  bool _songReadyForSync = false;
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
    // For host, periodically update playback position more frequently
    if (_isHost) {
      _syncTimer = Timer.periodic(Duration(seconds: 2), (timer) {
        if (_isPlaying) {
          _updateSessionPlayback();
        }
      });
    }
    // For guests, add more frequent polling for better sync
    else {
      _pollingTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
        if (_currentSongUrl != null) {
          _syncPlaybackPosition();
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
    print('HOST: Preparing song: ${album.name}');
    
    // Step 1: First just update the UI and load the song WITHOUT playing
    setState(() {
      _currentSongName = album.name;
      _currentSongUrl = album.downloadUrl;
      _currentImageUrl = album.imageUrl;
      _currentArtist = album.artist;
      _isPlaying = false;  // Important: Don't start playing yet
    });
    
    // Just load the song without playing
    await _audioService.stop();
    await _audioService.playSong(album);
    
    // Step 2: Update the session with the new song info, but keep isPlaying false
    if (_isHost && _sessionId != null) {
      print('HOST: Sending song information to guest');
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'song_id': album.downloadUrl,
          'current_song_name': album.name,
          'current_artist_name': album.artist ?? 'Unknown Artist',
          'album_art_url': album.imageUrl,
          'current_position': 0,
          'is_playing': false,
          'song_loaded': false,  // Add a new field to track loading state
          'last_sync_time': DateTime.now().toIso8601String(),
        },
      );
      
      // Step 3: Show a "waiting for guest" message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waiting for guest to load song...'),
          duration: Duration(seconds: 5),
        )
      );
      
      // Step 4: Wait a moment for the guest to receive the song
      await Future.delayed(Duration(seconds: 3));
      
      // Step 5: Show the "Play Together" button or use auto-sync
      setState(() {
        _songReadyForSync = true;  // Add this state variable to your class
      });
    }
  } catch (e) {
    print('ERROR preparing song: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error preparing song: $e')),
    );
  }
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
    print('GUEST: Preparing to load song ${album.name}');
    
    // First show loading feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loading song...'))
    );
    
    // Update UI immediately to show the song info
    setState(() {
      _currentSongName = album.name;
      _currentSongUrl = album.downloadUrl;
      _currentImageUrl = album.imageUrl;
      _currentArtist = album.artist;
      _isPlaying = false; // Start in paused state
    });
    
    // Stop previous playback
    await _audioService.stop();
    
    // Load the song but don't play yet
    await _audioService.playSong(album);
    print('GUEST: Song loaded and ready');
    
    // Tell the host we're ready
    if (_sessionId != null) {
      await _socialService.updateDocument(
        collectionId: 'paired_sessions',
        documentId: _sessionId!,
        data: {
          'guest_song_loaded': true,  // Add this field to track guest loading
        },
      );
    }
    
    // Now wait for sync signal from host
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Song loaded! Waiting for host to start playback...'))
    );
    
    // Note: We don't start playing here - we wait for the countdown event
  } catch (e) {
    print('ERROR loading guest song: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading song: $e')),
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
}

// Add this optimization method to improve sync timing
Future<void> _syncPlaybackPosition() async {
  if (_sessionId == null) return;
  
  try {
    // Get the latest position from the session
    final document = await _socialService.getDocument(
      collectionId: 'paired_sessions',
      documentId: _sessionId!,
    );
    
    final serverPosition = document.data['current_position'] ?? 0;
    final serverIsPlaying = document.data['is_playing'] ?? false;
    
    // Calculate time sync offset (compensate for network delay)
    final localPosition = _playbackPosition.toInt();
    final positionDifference = (serverPosition - localPosition).abs();
    
    print('SYNC: Server position: $serverPosition, Local position: $localPosition, Diff: $positionDifference');
    
    // Only sync if difference is significant (>2 seconds)
    if (positionDifference > 2) {
      print('SYNC: Adjusting position to match server');
      await _audioService.seek(Duration(seconds: serverPosition));
      setState(() {
        _playbackPosition = serverPosition.toDouble();
      });
    }
    
    // Make sure play state is in sync
    if (_isPlaying != serverIsPlaying) {
      print('SYNC: Adjusting play state to match server');
      if (serverIsPlaying) {
        await _audioService.play();
      } else {
        await _audioService.pause();
      }
      setState(() {
        _isPlaying = serverIsPlaying;
      });
    }
  } catch (e) {
    print('Error syncing playback: $e');
  }
}

Future<void> _playTogether() async {
  if (!_isHost || _sessionId == null) return;
  
  try {
    // Check if guest has loaded the song
    final document = await _socialService.getDocument(
      collectionId: 'paired_sessions',
      documentId: _sessionId!,
    );
    
    final guestReady = document.data['guest_song_loaded'] ?? false;
    
    if (!guestReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Waiting for guest to finish loading...'))
      );
      return;
    }
    
    // First update session with countdown flag and current position
    await _socialService.updateDocument(
      collectionId: 'paired_sessions',
      documentId: _sessionId!,
      data: {
        'start_countdown': true,
        'countdown_timestamp': DateTime.now().add(Duration(seconds: 5)).toIso8601String(),
        'current_position': _playbackPosition.toInt(),
        'is_playing': false, // Will be set to true when countdown completes
      },
    );
    
    // Show countdown UI
    _showCountdownOverlay(5);
    
    // Wait for countdown
    await Future.delayed(Duration(seconds: 5));
    
    // Play together
    await _audioService.play();
    setState(() { 
      _isPlaying = true;
      _songReadyForSync = false; // Reset this flag
    });
    
    // Update session
    await _socialService.updateDocument(
      collectionId: 'paired_sessions',
      documentId: _sessionId!,
      data: {
        'start_countdown': false,
        'is_playing': true,
      },
    );
  } catch (e) {
    print('Error in play together: $e');
  }
}

// Add this after your play/pause button
_buildPlayTogetherButton() {
  if (_isHost && _songReadyForSync && _currentSongUrl != null) {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: ElevatedButton.icon(
        icon: Icon(Icons.play_circle),
        label: Text('Play Together'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: _playTogether,
      ),
    );
  }
  return SizedBox.shrink(); // Return empty widget if conditions not met
}

void _showCountdownOverlay(int seconds) {
  // Create an overlay entry for the countdown
  OverlayState? overlayState = Overlay.of(context);
  OverlayEntry? entry;
  
  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Starting playback in',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              StreamBuilder<int>(
                stream: Stream.periodic(Duration(seconds: 1), (i) => seconds - i - 1)
                  .take(seconds),
                initialData: seconds,
                builder: (context, snapshot) {
                  return Text(
                    '${snapshot.data}',
                    style: GoogleFonts.poppins(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  
  // Show the overlay
  overlayState.insert(entry);
  
  // Remove it after the countdown
  Future.delayed(Duration(seconds: seconds + 1), () {
    entry?.remove();
  });
}

// Inside your subscription handler:
if (_isHost) {
  // Check if guest has loaded the song
  final guestReady = updatedDocument.data['guest_song_loaded'] ?? false;
  if (guestReady && !_songReadyForSync && _currentSongUrl != null) {
    setState(() {
      _songReadyForSync = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guest is ready! You can start playback.'))
    );
  }
}  
else {
  // Guest code to handle countdown
  if (updatedDocument.data['start_countdown'] == true) {
    final countdownTimestamp = updatedDocument.data['countdown_timestamp'];
    if (countdownTimestamp != null) {
      _handleCountdown(countdownTimestamp);
    }
  }
}
}