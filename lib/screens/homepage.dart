import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/screens/expandedplayer.dart';
import 'package:musicgram4/screens/librarypage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musicgram4/screens/profilepage.dart';
import 'package:musicgram4/screens/rewardspage.dart';
import 'package:musicgram4/screens/searchpage.dart';
import 'package:musicgram4/main.dart'; // Import for global Appwrite instances
import 'homie.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final just_audio.AudioPlayer _justAudioPlayer = just_audio.AudioPlayer();
  Duration _songDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  Album? _currentlyPlaying;
  bool _isPlaying = false;
  Timer? _listeningTimer;
  int _totalListeningTimeMinutes = 0;
  List<Album> _allAlbums = [];
  List<Album> _currentQueue = [];
  int _currentIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _fetchAllAlbums().then((_) {
      setState(() {
        _pages.add(HomePage(onPlaySong: _playSong));
        _pages.add(SearchPage(albums: _allAlbums));
        _pages.add(ProfilePage());
        _pages.add(RewardsPage());
        // _pages.add(DashboardPage());
      });
    });

    // Set up audioplayers listeners
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _songDuration = duration;
      });
      print("Duration changed: $duration");
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _currentPosition = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      print("Player state changed: $state");
      
      // Handle player completion
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
        });
        _stopListeningTimer();
      }
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      print("Player playback completed");
    });

    // Set up just_audio listeners
    _justAudioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _songDuration = duration;
        });
        print("just_audio duration: $duration");
      }
    });

    _justAudioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    _justAudioPlayer.playerStateStream.listen((state) {
      print("just_audio state: ${state.processingState}, playing: ${state.playing}");
      
      if (state.processingState == just_audio.ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
        });
        _stopListeningTimer();
      }
    });

    _loadListeningTime();
  }
  void _playNextSong() {
  if (_currentQueue.isEmpty || _currentIndex >= _currentQueue.length - 1) {
    print("No next song in queue");
    return;
  }
  
  _currentIndex++;
  _playSong(_currentQueue[_currentIndex]);
}

void _playPreviousSong() {
  if (_currentQueue.isEmpty || _currentIndex <= 0) {
    print("No previous song in queue");
    return;
  }
  
  _currentIndex--;
  _playSong(_currentQueue[_currentIndex]);
}

  @override
  void dispose() {
    _audioPlayer.dispose();
    _justAudioPlayer.dispose();
    _listeningTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllAlbums() async {
    try {
      // List all files in the bucket
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
      );
      
      final List<Album> fetchedAlbums = await Future.wait(
        result.files.where((file) => file.name.endsWith('.mp3')).map((file) async {
          // Create the URL for the audio file
          String downloadUrl = await _getFileViewUrl(file.$id);
          String name = file.name.replaceAll('.mp3', '');
          
          // Try to find a matching image file
          String? imageUrl = await _getImageUrl(name);
          
          return Album(name, downloadUrl, imageUrl);
        }).toList()
      );

      setState(() {
        _allAlbums = fetchedAlbums;
      });
    } catch (e) {
      print('Error fetching songs from Appwrite: $e');
    }
  }

  // Helper method to get a view URL for a file
  Future<String> _getFileViewUrl(String fileId) async {
    // IMPORTANT: Use download endpoint for audio files
    return '${AppConfig.endpoint}/storage/buckets/${AppConfig.storageId}/files/$fileId/download?project=${AppConfig.projectId}';
  }

  Future<String?> _getImageUrl(String songName) async {
    try {
      // List all files in the bucket to find matching image
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
        queries: [
          // Try exact match with jpg extension
          Query.equal('name', '$songName.jpg'),
        ],
      );
      
      if (result.files.isNotEmpty) {
        // Found exact match
        return _getFileViewUrl(result.files.first.$id);
      }
      
      // Try with png extension
      final resultPng = await storage.listFiles(
        bucketId: AppConfig.storageId,
        queries: [
          Query.equal('name', '$songName.png'),
        ],
      );
      
      if (resultPng.files.isNotEmpty) {
        return _getFileViewUrl(resultPng.files.first.$id);
      }
      
      // No image found
      return null;
    } catch (e) {
      print('Error fetching image for $songName: $e');
      return null;
    }
  }

  Future<void> _loadListeningTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
    });
  }

  Future<void> _updateListeningTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalListeningTimeMinutes += 1;
      prefs.setInt('listening_time', _totalListeningTimeMinutes);
    });
  }

  void _startListeningTimer() {
    _listeningTimer?.cancel();
    _listeningTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _updateListeningTime();
    });
  }

  void _stopListeningTimer() {
    _listeningTimer?.cancel();
    _listeningTimer = null;
  }

  Future<void> _playSong(Album album) async {
    await _audioPlayer.stop();
    await _justAudioPlayer.stop();
    
    print("Attempting to play song: ${album.name}");
    print("Original URL: ${album.downloadUrl}");

      if (_currentlyPlaying == null || album.name != _currentlyPlaying!.name) {
    if (_allAlbums.isNotEmpty) {
      _currentQueue = List.from(_allAlbums);
      _currentIndex = _currentQueue.indexWhere((a) => a.name == album.name);
      if (_currentIndex < 0) _currentIndex = 0; // Fallback
    }
  }

    setState(() {
      _currentlyPlaying = album;
      _isPlaying = true;
      _currentPosition = Duration.zero;
      _songDuration = Duration.zero;
    });
    
    try {
      // Try with just_audio first (better for streaming)
      print("Trying with just_audio player");
      
      // Add cache-busting to prevent potential caching issues
      String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      String playUrl = album.downloadUrl;
      if (playUrl.contains('?')) {
        playUrl += '&cache=$cacheBuster';
      } else {
        playUrl += '?cache=$cacheBuster';
      }
      
      await _justAudioPlayer.setUrl(playUrl);
      print("just_audio set URL successfully");

       _justAudioPlayer.processingStateStream.listen((state) {
      if (state == just_audio.ProcessingState.completed) {
        _playNextSong();
      }
    });
      
      await _justAudioPlayer.play();
      print("just_audio player started");
      
      _startListeningTimer();
      
      // Try to save recently played
      try {
        _saveToRecentlyPlayed(album);
      } catch (e) {
        print("Error saving recently played: $e");
      }
    } catch (e) {
      print("Error playing with just_audio: $e");
      
      // Fall back to original audioplayers
      try {
        print("Falling back to audioplayers");
        
        // Force using download URL regardless of what's stored
        String fileId = album.downloadUrl.split('/files/')[1].split('/')[0];
        String downloadUrl = '${AppConfig.endpoint}/storage/buckets/${AppConfig.storageId}/files/$fileId/download?project=${AppConfig.projectId}';
        
        print("Using direct download URL: $downloadUrl");
        
        await _audioPlayer.setSourceUrl(downloadUrl);
        print("Source URL set successfully");
        
        await _audioPlayer.resume();
        print("Player resumed successfully");
        
        _startListeningTimer();
      } catch (e) {
        print("Error with first fallback: $e");
        
        // Last resort approach
        try {
          print("Trying last resort method...");
          
          // Try with additional parameters that might help
          String cleanUrl = album.downloadUrl.split('?')[0];
          if (cleanUrl.contains('/view')) {
            cleanUrl = cleanUrl.replaceAll('/view', '/download');
          }
          cleanUrl += '?project=${AppConfig.projectId}&cache=${DateTime.now().millisecondsSinceEpoch}';
          
          print("Using clean URL: $cleanUrl");
          _audioPlayer.play(UrlSource(cleanUrl));
        } catch (e) {
          print("All playback attempts failed: $e");
          setState(() {
            _isPlaying = false;
          });
        }
      }
    }
  }

  Future<void> _saveToRecentlyPlayed(Album album) async {
    try {
      // Get current user
      final currentUser = await account.get();
      
      // Create or update recently played document
      await databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: 'recently_played',
        documentId: ID.unique(),
        data: {
          'user_id': currentUser.$id,
          'song_name': album.name,
          'song_url': album.downloadUrl,
          'image_url': album.imageUrl ?? '',
          'played_at': DateTime.now().toIso8601String(),
        },
      );
      
      print('Song added to recently played');
    } catch (e) {
      print('Error saving recently played: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color.fromARGB(255, 124, 166, 231),
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: _pages,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentlyPlaying != null) _buildMiniPlayer(),
          BottomNavigationBar(
            currentIndex: _currentPage,
            onTap: (int index) {
              setState(() {
                _currentPage = index;
                _pageController.jumpToPage(index);
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home, color: Colors.black),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search, color: Colors.black),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, color: Colors.black),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events, color: Colors.black),
                label: 'Rewards',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music, color: Colors.black),
                label: 'Library',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    double progress = _songDuration.inSeconds > 0
        ? _currentPosition.inSeconds / _songDuration.inSeconds
        : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpandedMusicPlayer(
              album: _currentlyPlaying!,
              audioPlayer: _audioPlayer,
              justAudioPlayer: _justAudioPlayer,
              onNextSong: _playNextSong,
              onPreviousSong: _playPreviousSong,
              onTogglePlayPause: _togglePlayPause,
              isPlaying: _isPlaying,
            ),
          ),
        );
      },
      // Add horizontal swipe detection
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          // Swiped right - play previous
          _playPreviousSong();
        } else if (details.primaryVelocity! < 0) {
          // Swiped left - play next
          _playNextSong();
        }
      },
      child: Container(
        height: 80,
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _currentlyPlaying?.imageUrl ?? 'https://via.placeholder.com/64',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentlyPlaying?.name ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Artist Name', // Replace with actual artist name if available
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
              onPressed: _togglePlayPause,
            ),
            IconButton(
              icon: Icon(Icons.skip_previous, color: Colors.white, size: 30),
              onPressed: _playPreviousSong,
            ),
            IconButton(
              icon: Icon(Icons.skip_next, color: Colors.white, size: 30),
              onPressed: _playNextSong,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _togglePlayPause() {
  if (_isPlaying) {
    // Store current position before pausing
    final currentPos = _currentPosition;
    
    // Pause both players (only one will be active)
    _audioPlayer.pause();
    _justAudioPlayer.pause();
    _stopListeningTimer();
    
    setState(() {
      _isPlaying = false;
      // Keep track of the position
      _currentPosition = currentPos;
    });
  } else {
    // Resume playback from stored position
    if (_justAudioPlayer.processingState != just_audio.ProcessingState.idle) {
      // First try to resume with just_audio
      _justAudioPlayer.seek(_currentPosition);
      _justAudioPlayer.play();
      print("Resuming with just_audio from position: $_currentPosition");
    } else {
      // Fall back to audioplayers
      _audioPlayer.seek(_currentPosition);
      _audioPlayer.resume();
      print("Resuming with audioplayers from position: $_currentPosition");
    }
    
    _startListeningTimer();
    
    setState(() {
      _isPlaying = true;
    });
  }
}

  void _cancelPlayback() {
    _audioPlayer.stop();
    _justAudioPlayer.stop();
    _stopListeningTimer();
    setState(() {
      _currentlyPlaying = null;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _songDuration = Duration.zero;
    });
  }
}

