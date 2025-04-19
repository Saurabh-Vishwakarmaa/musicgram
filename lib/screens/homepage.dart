import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/notifications/media_notifications.dart';
import 'package:musicgram4/services/audio_player_service.dart';
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
  final AudioPlayerService _audioService = AudioPlayerService();
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
    
    // Initialize the audio service
    _audioService.init();
    
    _fetchAllAlbums().then((_) {
      setState(() {
        _pages.add(HomePage(onPlaySong: _playSong));
        _pages.add(SearchPage(albums: _allAlbums));
        _pages.add(ProfilePage());
        _pages.add(RewardsPage());
      });
    });

    // Set up audio service callbacks
    _audioService.onPlayPause = () {
      setState(() {
        _isPlaying = _audioService.isPlaying;
      });
      
      if (_isPlaying) {
        _startListeningTimer();
      } else {
        _stopListeningTimer();
      }
    };
    
    _audioService.onPositionChanged = (position) {
      setState(() {
        _currentPosition = position;
      });
    };
    
    _audioService.onDurationChanged = (duration) {
      if (duration != null) {
        setState(() {
          _songDuration = duration;
        });
      }
    };
    
    _audioService.onComplete = _playNextSong;
    _audioService.onNext = _playNextSong;
    _audioService.onPrevious = _playPreviousSong;
    
    // Load listening time
    _loadListeningTime();
  }

  @override
  void dispose() {
    _audioService.dispose();
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
    print("Attempting to play song: ${album.name}");
    
    // Update queue if needed
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
      // Play through the single audio service
      await _audioService.playSong(album);
      
      _startListeningTimer();
      
      // Save to recently played
      _saveToRecentlyPlayed(album);
    } catch (e) {
      print("Error playing song: $e");
      setState(() {
        _isPlaying = false;
      });
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content with enhanced page transitions
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
              // Add haptic feedback for page changes
              HapticFeedback.lightImpact();
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              // Apply subtle scale effect to non-active pages
              return AnimatedScale(
                scale: _currentPage == index ? 1.0 : 0.92,
                duration: Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: _currentPage == index ? 1.0 : 0.7,
                  duration: Duration(milliseconds: 200),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _currentPage == index ? 0 : 20
                    ),
                    child: _pages[index],
                  ),
                ),
              );
            },
            // Custom physics for satisfying swipe experience
            physics: const PageScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
          ),
          
          // Page name indicator at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, -0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                _getPageName(_currentPage),
                key: ValueKey<int>(_currentPage),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Subtle page indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: _currentPage == index ? 20 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Redesigned mini-player with gestures
          if (_currentlyPlaying != null) _buildMinimalistMiniPlayer(),
          
          // Modern, clean bottom navigation
          Container(
            color: Colors.black,
            padding: EdgeInsets.only(
              top: 8, 
              bottom: MediaQuery.of(context).padding.bottom > 0 
                  ? MediaQuery.of(context).padding.bottom 
                  : 8
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, 'Home', Icons.home_outlined, Icons.home),
                  _buildNavItem(1, 'Search', Icons.search_outlined, Icons.search),
                  _buildNavItem(2, 'Profile', Icons.person_outline, Icons.person),
                  _buildNavItem(3, 'Rewards', Icons.emoji_events_outlined, Icons.emoji_events),
                  _buildNavItem(4, 'Library', Icons.library_music_outlined, Icons.library_music),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced navigation item with animations and feedback
  Widget _buildNavItem(int index, String label, IconData outlinedIcon, IconData filledIcon) {
    final bool isSelected = _currentPage == index;
    
    return GestureDetector(
      onTap: () {
        if (_currentPage != index) {
          HapticFeedback.selectionClick();
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom indicator line above icon
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: 20,
            height: 2,
            margin: EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          
          // Animated icon transition
          AnimatedSwitcher(
            duration: Duration(milliseconds: 200),
            child: Icon(
              isSelected ? filledIcon : outlinedIcon,
              key: ValueKey(isSelected),
              color: isSelected ? Colors.white : Colors.white38,
              size: 22,
            ),
          ),
          
          SizedBox(height: 4),
          
          // Label text
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Get page name based on index
  String _getPageName(int page) {
    switch(page) {
      case 0: return "Discover";
      case 1: return "Search";
      case 2: return "Profile";
      case 3: return "Rewards";
      case 4: return "Library";
      default: return "MusicGram";
    }
  }

  // Reimagined minimalist mini player
  Widget _buildMinimalistMiniPlayer() {
    double progress = _songDuration.inSeconds > 0
        ? _currentPosition.inSeconds / _songDuration.inSeconds
        : 0.0;
    progress = progress.clamp(0.0, 1.0);
    
    return GestureDetector(
      onTap: _openExpandedPlayer,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 500) {
          HapticFeedback.mediumImpact();
          _playPreviousSong();
        } else if (details.primaryVelocity! < -500) {
          HapticFeedback.mediumImpact();
          _playNextSong();
        }
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 8, 16, 12),
        height: 70,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Progress bar at the top of the mini player
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            
            // Main mini player content
            Row(
              children: [
                // Album art with subtle animation when playing
                Container(
                  width: 50,
                  height: 50,
                  margin: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _isPlaying
                      ? AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          transform: Matrix4.identity()
                            ..scale(_isPlaying ? 1.05 : 1.0),
                          transformAlignment: Alignment.center,
                          child: _buildMiniPlayerImage(),
                        )
                      : _buildMiniPlayerImage(),
                  ),
                ),
                
                // Song details with ellipsis
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentlyPlaying?.name ?? 'Unknown',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Artist',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Play/pause button
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayerImage() {
    return Image.network(
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
    );
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
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
    
    if (_isPlaying) {
      _startListeningTimer();
    } else {
      _stopListeningTimer();
    }
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

  void _cancelPlayback() {
    _audioService.stop();
    setState(() {
      _currentlyPlaying = null;
      _isPlaying = false;
    });
    _stopListeningTimer();
  }

  void _openExpandedPlayer() {
    if (_currentlyPlaying != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ExpandedMusicPlayer(
            album: _currentlyPlaying!,
            audioService: _audioService, // Pass the existing AudioPlayerService instance
            onNextSong: _playNextSong,
            onPreviousSong: _playPreviousSong,
            onTogglePlayPause: _togglePlayPause,
            isPlaying: _isPlaying,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }
}

