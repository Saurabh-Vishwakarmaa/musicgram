import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/notifications/media_notifications.dart';
import 'package:musicgram4/screens/socialhub.dart';
import 'package:musicgram4/services/audio_player_service.dart';
import 'package:musicgram4/screens/expandedplayer.dart';
import 'package:musicgram4/screens/librarypage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musicgram4/screens/profile2.dart';
import 'package:musicgram4/screens/rewardspage.dart';
import 'package:musicgram4/screens/searchpage.dart';
import 'package:musicgram4/main.dart'; // Import for global Appwrite instances
import 'homie.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;


class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

// Define the _applyCubicEasing method
double _applyCubicEasing(double t) {
  // Cubic easing function: easeInOutCubic
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

class _MainScreenState extends State<MainScreen> {
  PageController _pageController = PageController();
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

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize pages list with placeholders first
    _pages = [
      Center(child: CircularProgressIndicator()), // Replace with a loading indicator
      Center(child: CircularProgressIndicator()),
     Center(child: CircularProgressIndicator()),
     Center(child: CircularProgressIndicator()),
      Center(child: CircularProgressIndicator()),

    ];
    
    // Initialize the audio service
    _audioService.init();
    
    // Then fetch data and update properly
    _fetchAllAlbums().then((_) {
      // Save current page
      final currentPageIndex = _currentPage;
      
      // Dispose old controller
      _pageController.dispose();
      
      setState(() {
        // Create new pages
        _pages = [
          HomePage(onPlaySong: _playSong),
          SearchPage(albums: _allAlbums),
          ProfilePage(),
          RewardsPage(),
          SocialHub()
        ];
        
        // Create new controller
        _pageController = PageController(initialPage: currentPageIndex);
        _currentPage = currentPageIndex;
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
      extendBody: true, // Allow content to extend behind bottom nav
      body: Stack(
        children: [
          _buildParallaxBackground(),
          SafeArea(
            child: _pages.isEmpty
                ? Center(child: CircularProgressIndicator())
                : PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: _pages.asMap().entries.map((entry) {
                      return KeyedSubtree(
                        key: ValueKey('page_${entry.key}'),
                        child: entry.value,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentlyPlaying != null) _buildCompactMiniPlayer(),
          Container(
            color: Colors.black.withOpacity(0.7),
            padding: EdgeInsets.only(
              top: 6, // Reduced top padding
              bottom: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 6, // Reduced bottom padding when no system nav
            ),
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                double page = _pageController.hasClients
                    ? (_pageController.page ?? _currentPage.toDouble())
                    : _currentPage.toDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompactNavItem(page, 0, 'Home', Icons.home_outlined, Icons.home),
                    _buildCompactNavItem(page, 1, 'Search', Icons.search_outlined, Icons.search),
                    _buildCompactNavItem(page, 2, 'Profile', Icons.person_outline, Icons.person),
                    _buildCompactNavItem(page, 3, 'Rewards', Icons.emoji_events_outlined, Icons.emoji_events),
                    _buildCompactNavItem(page , 4, "Social", Icons.social_distance, Icons.social_distance_rounded)
                  ],
                );
              },
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

  Widget _buildParallaxBackground() {
  return AnimatedBuilder(
    animation: _pageController,
    builder: (context, _) {
      double page = _pageController.hasClients
          ? (_pageController.page ?? _currentPage.toDouble())
          : _currentPage.toDouble();
          
      // Improved color palette with better harmony
      const List<List<Color>> pageGradients = [
        [Color(0xFF0A1A2F), Color(0xFF162A45), Color(0xFF20374A)], // Home - Deeper blue
        [Color(0xFF2A1155), Color(0xFF4B2A80), Color(0xFF673AB7)], // Search - Rich purple
        [Color(0xFF0A3762), Color(0xFF0D56A6), Color(0xFF1976D2)], // Profile - Azure
        [Color(0xFF4A0040), Color(0xFF7A007A), Color(0xFF9C27B0)], // Rewards - Vibrant purple
      ];
      
      // Improved interpolation with better easing
      int currentIdx = page.floor().clamp(0, pageGradients.length - 1);
      int nextIdx = (currentIdx + 1).clamp(0, pageGradients.length - 1);
      double pageFraction = page - currentIdx;
      
      // Use cubic easing for smoother transition
      double easedFraction = _applyCubicEasing(pageFraction);
      
      // Interpolate colors
      Color topColor = Color.lerp(
        pageGradients[currentIdx][0],
        pageGradients[nextIdx][0],
        easedFraction,
      )!;
      
      Color midColor = Color.lerp(
        pageGradients[currentIdx][1],
        pageGradients[nextIdx][1],
        easedFraction,
      )!;
      
      Color bottomColor = Color.lerp(
        pageGradients[currentIdx][2],
        pageGradients[nextIdx][2],
        easedFraction,
      )!;
      
      return RepaintBoundary( // Add for better performance
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, midColor, bottomColor],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: EnhancedBackgroundPainter(
              pageOffset: page,
              currentPage: _currentPage,
              easedFraction: easedFraction,
            ),
            size: Size.infinite,
          ),
        ),
      );
    },
  );
}

  Widget _buildParallaxNavItem(
    double currentPage,
    int index,
    String label,
    IconData outlinedIcon,
    IconData filledIcon
  ) {
    // Calculate distance with improved curve
    double distance = (currentPage - index).abs();
    final bool isSelected = distance < 0.5;
    
    // Refined movement calculations
    double yOffset = isSelected 
        ? -3 
        : math.min(4.0, distance * 1.2); // More natural movement curve
        
    // Better opacity curve
    double opacity = math.max(0.4, 1.0 - (distance * 0.2));
    
    // Scale based on distance for more physical feel
    double scale = 1.0 - (distance * 0.05).clamp(0.0, 0.15);
    
    return GestureDetector(
      onTap: () {
        if (_currentPage != index) {
          HapticFeedback.selectionClick();
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeOutQuint, // Better easing curve
          );
        }
      },
      child: Transform(
        transform: Matrix4.identity()
          ..translate(0.0, yOffset)
          ..scale(scale),
        alignment: Alignment.center,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 65, // Slightly wider for better tap target
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Improved animated container with better feedback
                AnimatedContainer(
                  duration: Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 50,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.15) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    // Add subtle border when selected
                    border: isSelected
                        ? Border.all(color: Colors.white24, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        // Use scale transition for icon change
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        isSelected ? filledIcon : outlinedIcon,
                        key: ValueKey(isSelected),
                        color: isSelected ? Colors.white : Colors.white38,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                
                // Add subtle label for better context
                AnimatedOpacity(
                  duration: Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactNavItem(
  double currentPage,
  int index,
  String label,
  IconData outlinedIcon,
  IconData filledIcon
) {
  // Calculate distance with improved curve
  double distance = (currentPage - index).abs();
  final bool isSelected = distance < 0.5;
  
  // Refined movement calculations
  double yOffset = isSelected 
      ? -2 // Less vertical movement
      : math.min(2.0, distance * 1.0); // Reduced movement
      
  // Better opacity curve
  double opacity = math.max(0.4, 1.0 - (distance * 0.2));
  
  // Scale based on distance for more physical feel
  double scale = 1.0 - (distance * 0.03).clamp(0.0, 0.10); // Less scaling
  
  return GestureDetector(
    onTap: () {
      if (_currentPage != index) {
        HapticFeedback.selectionClick();
        _pageController.animateToPage(
          index,
          duration: Duration(milliseconds: 400), // Faster transition
          curve: Curves.easeOutQuint,
        );
      }
    },
    child: Transform(
      transform: Matrix4.identity()
        ..translate(0.0, yOffset)
        ..scale(scale),
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 58, // Slightly narrower
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // More compact animated container
              AnimatedContainer(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: 46, // Slightly narrower
                height: 40, // Shorter
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.15) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: Colors.white24, width: 1.0) // Thinner border
                      : null,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      isSelected ? filledIcon : outlinedIcon,
                      key: ValueKey(isSelected),
                      color: isSelected ? Colors.white : Colors.white38,
                      size: 22, // Smaller icon
                    ),
                  ),
                ),
              ),
              
              // Add subtle label with no background for cleaner look
              AnimatedOpacity(
                duration: Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.0,
                child: Container(
                  margin: EdgeInsets.only(top: 2),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildParallaxMiniPlayer() {
  double progress = _songDuration.inSeconds > 0
      ? _currentPosition.inSeconds / _songDuration.inSeconds
      : 0.0;
  progress = progress.clamp(0.0, 1.0);
  
  return AnimatedBuilder(
    animation: _pageController,
    builder: (context, child) {
      double page = _pageController.hasClients
          ? (_pageController.page ?? _currentPage.toDouble())
          : _currentPage.toDouble();
          
      // More subtle parallax effect
      double pageOffset = page - page.round();
      double parallaxX = pageOffset * 8.0;
      
      return Transform.translate(
        offset: Offset(parallaxX, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openExpandedPlayer,
          onHorizontalDragUpdate: (details) {
            // Less frequent haptic feedback
            if (details.primaryDelta != null && 
                details.primaryDelta!.abs() > 5.0 && 
                details.primaryDelta!.abs() % 10 < 1) {
              HapticFeedback.selectionClick();
            }
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            
            if (details.primaryVelocity! > 300) {
              HapticFeedback.mediumImpact();
              _playPreviousSong();
            } else if (details.primaryVelocity! < -300) {
              HapticFeedback.mediumImpact();
              _playNextSong();
            }
          },
          child: Container(
            margin: EdgeInsets.fromLTRB(16, 8, 16, 12),
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.white10, width: 0.5),
            ),
            child: Stack(
              children: [
                // Ripple effect only when playing
                Positioned.fill(
                  child: _isPlaying ? AnimatedRippleContainer() : SizedBox(),
                ),
                
                // Optimized progress bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      height: 2,
                      child: TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: progress),
                        builder: (context, animatedProgress, child) {
                          return CustomPaint(
                            size: Size.fromHeight(2),
                            painter: EnhancedProgressPainter(
                              progress: animatedProgress,
                              pageOffset: pageOffset,
                              isPlaying: _isPlaying,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Content with improved layout
                Row(
                  children: [
                    // Album art with reduced parallax
                    Container(
                      width: 50,
                      height: 50,
                      margin: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            // Reduced parallax X
                            Transform.translate(
                              offset: Offset(-pageOffset * 3, 0),
                              child: _isPlaying
                                ? AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    transform: Matrix4.identity()
                                      ..scale(_isPlaying ? 1.03 : 1.0), // Less scaling
                                    transformAlignment: Alignment.center,
                                    child: _buildMiniPlayerImage(),
                                  )
                                : _buildMiniPlayerImage(),
                            ),
                            
                            // Simplified audio wave indicator
                            if (_isPlaying)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black54,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: _buildAudioWaveIndicator(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Song details
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
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                // Simplified status indicator
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isPlaying ? Colors.greenAccent : Colors.white38,
                                  ),
                                ),
                                Text(
                                  _isPlaying ? 'Now Playing' : 'Paused',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    letterSpacing: 0.1,
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
                    Transform.translate(
                      offset: Offset(pageOffset * 2, 0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _togglePlayPause();
                            HapticFeedback.mediumImpact();
                          },
                          customBorder: CircleBorder(),
                          child: Container(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  key: ValueKey(_isPlaying),
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Little audio wave indicator with improved performance
Widget _buildAudioWaveIndicator() {
  return RepaintBoundary(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) { // Reduced from 4 to 3 elements
        return TweenAnimationBuilder<double>(
          tween: Tween(
            begin: index % 2 == 1 ? 1.5 : 1.0,
            end: index % 2 == 1 ? 3.0 : 1.5
          ),
          duration: Duration(milliseconds: 600 + (index * 150)),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Container(
              width: 1.5, // Thinner lines
              height: value,
              margin: EdgeInsets.symmetric(horizontal: 0.8), // Reduced spacing
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(0.5),
              ),
            );
          },
        );
      }),
    ),
  );
}

Widget _buildCompactMiniPlayer() {
  double progress = _songDuration.inSeconds > 0
      ? _currentPosition.inSeconds / _songDuration.inSeconds
      : 0.0;
  progress = progress.clamp(0.0, 1.0);
  
  return AnimatedBuilder(
    animation: _pageController,
    builder: (context, child) {
      double page = _pageController.hasClients
          ? (_pageController.page ?? _currentPage.toDouble())
          : _currentPage.toDouble();
          
      // More subtle parallax effect
      double pageOffset = page - page.round();
      double parallaxX = pageOffset * 6.0; // Reduced parallax
      
      return Transform.translate(
        offset: Offset(parallaxX, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openExpandedPlayer,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            
            if (details.primaryVelocity! > 300) {
              HapticFeedback.mediumImpact();
              _playPreviousSong();
            } else if (details.primaryVelocity! < -300) {
              HapticFeedback.mediumImpact();
              _playNextSong();
            }
          },
          child: Container(
            // Reduced margins for more space
            margin: EdgeInsets.fromLTRB(12, 6, 12, 8),
            height: 60, // Slightly shorter
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white10, width: 0.5),
            ),
            child: Stack(
              children: [
                // Ripple effect only when playing
                Positioned.fill(
                  child: _isPlaying ? AnimatedRippleContainer() : SizedBox(),
                ),
                
                // Optimized progress bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                    child: Container(
                      height: 2,
                      child: TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: progress),
                        builder: (context, animatedProgress, child) {
                          return CustomPaint(
                            size: Size.fromHeight(2),
                            painter: EnhancedProgressPainter(
                              progress: animatedProgress,
                              pageOffset: pageOffset,
                              isPlaying: _isPlaying,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Content with more compact layout
                Row(
                  children: [
                    // Album art - slightly smaller
                    Container(
                      width: 45,
                      height: 45,
                      margin: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            // Reduced parallax X
                            Transform.translate(
                              offset: Offset(-pageOffset * 2, 0),
                              child: _buildMiniPlayerImage(),
                            ),
                            
                            // Simplified audio wave indicator
                            if (_isPlaying)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black54,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: _buildAudioWaveIndicator(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Song details - no change in vertical padding
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentlyPlaying?.name ?? 'Unknown',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14, // Slightly smaller text
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3), // Reduced spacing
                            Row(
                              children: [
                                // Simplified status indicator
                                Container(
                                  width: 3,
                                  height: 3,
                                  margin: EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isPlaying ? Colors.greenAccent : Colors.white38,
                                  ),
                                ),
                                Text(
                                  _isPlaying ? 'Now Playing' : 'Paused',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10, // Smaller text
                                    letterSpacing: 0.1,
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
                    Transform.translate(
                      offset: Offset(pageOffset * 2, 0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _togglePlayPause();
                            HapticFeedback.mediumImpact();
                          },
                          customBorder: CircleBorder(),
                          child: Container(
                            width: 45, // Slightly smaller
                            height: 45, // Slightly smaller
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  key: ValueKey(_isPlaying),
                                  color: Colors.white,
                                  size: 28, // Slightly smaller
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

}

class ParallaxProgressPainter extends CustomPainter {
  final double progress;
  final double pageOffset;
  final bool isPlaying;
  
  ParallaxProgressPainter({
    required this.progress,
    required this.pageOffset,
    required this.isPlaying,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.fill;
      
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Foreground with wave effect for playing state
    if (progress > 0) {
      final width = size.width * progress;
      final path = Path();
      
      // Start point
      path.moveTo(0, 0);
      
      if (isPlaying) {
        // Draw wavy line when playing
        for (double x = 0; x <= width; x += 4) {
          // Apply parallax to wave frequency
          double frequency = 10 + (pageOffset.abs() * 5);
          double amplitude = 2.0 + (pageOffset.abs() * 0.5);
          
          // Calculate wave Y position
          double y = math.sin(x / frequency + DateTime.now().millisecondsSinceEpoch * 0.002) * amplitude;
          path.lineTo(x, y + (size.height / 2));
        }
      } else {
        // Straight line when paused
        path.lineTo(width, 0);
        path.lineTo(width, size.height);
      }
      
      // Complete the path
      path.lineTo(0, size.height);
      path.close();
      
      // Draw with gradient
      final progressPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [
            Colors.white,
            Colors.white70,
          ],
        );
        
      canvas.drawPath(path, progressPaint);
    }
  }
  
  @override
  bool shouldRepaint(ParallaxProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.pageOffset != pageOffset ||
           oldDelegate.isPlaying != isPlaying;
  }
}

class ParallaxBackgroundPainter extends CustomPainter {
  final double pageOffset;
  
  ParallaxBackgroundPainter({required this.pageOffset});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Create parallax circles with different depths
    // Draw multiple background circles that move with parallax effect
    for (int i = 0; i < 15; i++) { // Increased number of elements
      double depth = i / 15; // Depth factor (0.0 - 0.93)
      double parallaxFactor = 1.0 - depth;
      double angle = i * (math.pi / 7.5);
      
      // Create varied shapes (circles and soft rectangles)
      bool isCircle = i % 3 != 0;
      
      // Calculate position with parallax movement
      double radius = size.width * (0.1 + (depth * 0.2));
      double centerX = size.width * 0.5 + math.cos(angle) * size.width * 0.6;
      double centerY = size.height * 0.5 + math.sin(angle) * size.height * 0.5;
      
      // Apply parallax movement based on page offset
      double offsetX = pageOffset * size.width * 0.2 * parallaxFactor;
      centerX -= offsetX;
      
      final Paint shapePaint = Paint()
        ..color = Colors.white.withOpacity(0.03 + (depth * 0.04))
        ..style = PaintingStyle.fill;
      
      if (isCircle) {
        canvas.drawCircle(Offset(centerX, centerY), radius, shapePaint);
      } else {
        // Draw rounded rectangle with random aspect ratio
        double width = radius * 1.8;
        double height = radius * (0.8 + math.sin(angle) * 0.4);
        
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: width,
            height: height,
          ),
          Radius.circular(radius * 0.5),
        );
        
        canvas.drawRRect(rect, shapePaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(ParallaxBackgroundPainter oldDelegate) {
    return oldDelegate.pageOffset != pageOffset;
  }
}

class ParallaxCardSwiper extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final Function(int) onPageChanged;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const ParallaxCardSwiper({
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Get device dimensions for responsive design
    final Size deviceSize = MediaQuery.of(context).size;
    final double cardWidth = deviceSize.width * 0.85;
    final double viewportFraction = cardWidth / deviceSize.width;
    
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: itemCount,
      physics: CustomPagePhysics(),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            double page = controller.hasClients
                ? (controller.page ?? currentPage.toDouble())
                : currentPage.toDouble();
                
            // Calculate parallax effect parameters
            double pageOffset = page - index;
            double absPageOffset = pageOffset.abs();
            
            // Scale the card based on offset
            double scale = 1.0 - (absPageOffset * 0.1).clamp(0.0, 0.15);
            
            // Opacity adjustment
            double opacity = 1.0 - (absPageOffset * 0.3).clamp(0.0, 0.7);
            
            // Parallax movement calculations
            double parallaxOffset = pageOffset * deviceSize.width * 0.35;
            double yOffset = absPageOffset * 30;
            
            // Transform the card for parallax effect
            return Opacity(
              opacity: opacity,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translate(parallaxOffset, yOffset)
                  ..scale(scale),
                child: Container(
                  margin: EdgeInsets.only(
                    top: 100 + (absPageOffset * 20),
                    bottom: 80 + (absPageOffset * 20),
                    left: 16 + (absPageOffset * 8),
                    right: 16 + (absPageOffset * 8),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Subtle gradient overlay for depth
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CardGradientPainter(
                              pageOffset: pageOffset,
                            ),
                          ),
                        ),
                        
                        // Content
                        child!,
                        
                        // Edge shadow for parallax effect
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: pageOffset > 0 ? 0 : null,
                          right: pageOffset < 0 ? 0 : null,
                          width: 32,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: pageOffset > 0 
                                    ? Alignment.centerLeft 
                                    : Alignment.centerRight,
                                end: pageOffset > 0 
                                    ? Alignment.centerRight 
                                    : Alignment.centerLeft,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

// Custom painter for card gradient depth
class CardGradientPainter extends CustomPainter {
  final double pageOffset;
  
  CardGradientPainter({required this.pageOffset});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Left-right gradient intensity based on swipe direction
    double leftIntensity = pageOffset > 0 
        ? (pageOffset * 0.1).clamp(0.0, 0.1) 
        : 0.0;
    double rightIntensity = pageOffset < 0 
        ? (pageOffset * -0.1).clamp(0.0, 0.1)
        : 0.0;
    
    // Create horizontal gradient overlay
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(leftIntensity),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(rightIntensity),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(rect);
      
    canvas.drawRect(rect, paint);
    
    // Add subtle vignette effect
    final Paint vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.1),
        ],
        stops: [0.7, 1.0],
      ).createShader(rect);
      
    canvas.drawRect(rect, vignettePaint);
  }
  
  @override
  bool shouldRepaint(CardGradientPainter oldDelegate) {
    return oldDelegate.pageOffset != pageOffset;
  }
}

class ParallaxPageTitle extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final List<String> pageTitles;
  
  const ParallaxPageTitle({
    required this.pageController,
    required this.currentPage,
    required this.pageTitles,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, _) {
        double page = pageController.hasClients
            ? (pageController.page ?? currentPage.toDouble())
            : currentPage.toDouble();
        
        return Stack(
          alignment: Alignment.center,
          children: List.generate(pageTitles.length, (index) {
            // Calculate distance from current page
            double distance = (index - page).abs();
            double opacity = 1.0 - (distance * 0.9).clamp(0.0, 1.0);
            
            // Skip rendering titles that are too far away
            if (opacity < 0.1) return const SizedBox.shrink();
            
            // Calculate parallax movement for title
            double xOffset = (index - page) * 40;
            double scale = 1.0 - (distance * 0.15).clamp(0.0, 0.3);
            
            return Opacity(
              opacity: opacity,
              child: Transform(
                transform: Matrix4.identity()
                  ..translate(xOffset, 0)
                  ..scale(scale),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white,
                        Colors.white,
                        Colors.white.withOpacity(0.9),
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
                    ).createShader(bounds);
                  },
                  child: Text(
                    pageTitles[index],
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
            );
          }),
        );
      },
    );
  }
}

class CustomPagePhysics extends ScrollPhysics {
  const CustomPagePhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  CustomPagePhysics applyTo(ScrollPhysics? ancestor) {
    return CustomPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 1.1,
      );

  @override
  double get dragStartDistanceMotionThreshold => 0.0;

  @override
  double get minFlingVelocity => 300.0;

  @override
  double get maxFlingVelocity => 5000.0;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Custom simulation for smoother deceleration
    if (velocity.abs() >= minFlingVelocity) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        friction: 0.9, // Higher value for smoother deceleration
        tolerance: tolerance,
      );
    }
    
    // Snap to nearest page
    double page = position.pixels / position.viewportDimension;
    double targetPage = velocity.abs() < tolerance.velocity
        ? page.roundToDouble()
        : velocity > 0
            ? page.ceilToDouble()
            : page.floorToDouble();
            
    double target = targetPage * position.viewportDimension;
    if (target == position.pixels) return null;
    
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

class FullWidthParallaxSwiper extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final Function(int) onPageChanged;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const FullWidthParallaxSwiper({
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Get device dimensions for responsive design
    final Size deviceSize = MediaQuery.of(context).size;
    
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: itemCount,
      physics: CustomPagePhysics(),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            double page = controller.hasClients
                ? (controller.page ?? currentPage.toDouble())
                : currentPage.toDouble();
                
            // Calculate parallax effect parameters
            double pageOffset = page - index;
            double absPageOffset = pageOffset.abs();
            
            // Scale the card based on offset for subtle zoom effect
            double scale = 1.0 - (absPageOffset * 0.06).clamp(0.0, 0.1);
            
            // Opacity adjustment for fade transition
            double opacity = 1.0 - (absPageOffset * 0.3).clamp(0.0, 0.7);
            
            // Parallax movement calculations
            double parallaxOffset = pageOffset * deviceSize.width * 0.2;
            double yOffset = absPageOffset * 20; // Reduced vertical movement
            
            // Transform the card for parallax effect
            return Opacity(
              opacity: opacity,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translate(parallaxOffset, yOffset)
                  ..scale(scale),
                child: Container(
                  margin: EdgeInsets.only(
                    top: 70, // Reduced top margin since we removed the title
                    bottom: 70 + (absPageOffset * 10), // Keep some bottom margin for nav bar
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    // Only round the top corners for a seamless bottom edge
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        // Subtle gradient overlay for depth
                        Positioned.fill(
                          child: CustomPaint(
                            painter: FullWidthCardGradientPainter(
                              pageOffset: pageOffset,
                            ),
                          ),
                        ),
                        
                        // Content
                        child!,
                        
                        // Edge shadow for parallax effect - now only on sides
                        if (pageOffset != 0) Positioned(
                          top: 0,
                          bottom: 0,
                          left: pageOffset > 0 ? 0 : null,
                          right: pageOffset < 0 ? 0 : null,
                          width: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: pageOffset > 0 
                                    ? Alignment.centerLeft 
                                    : Alignment.centerRight,
                                end: pageOffset > 0 
                                    ? Alignment.centerRight 
                                    : Alignment.centerLeft,
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

// Updated gradient painter for full-width cards
class FullWidthCardGradientPainter extends CustomPainter {
  final double pageOffset;
  
  FullWidthCardGradientPainter({required this.pageOffset});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Left-right gradient intensity based on swipe direction
    double leftIntensity = pageOffset > 0 
        ? (pageOffset * 0.15).clamp(0.0, 0.15) 
        : 0.0;
    double rightIntensity = pageOffset < 0 
        ? (pageOffset * -0.15).clamp(0.0, 0.15)
        : 0.0;
    
    // Create horizontal gradient overlay
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(leftIntensity),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(rightIntensity),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(rect);
      
    canvas.drawRect(rect, paint);
    
    // Add subtle top vignette for better readability 
    final Paint topVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.black.withOpacity(0.2),
          Colors.transparent,
        ],
        stops: [0.0, 0.5],
      ).createShader(rect);
      
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.3),
      topVignette
    );
  }
  
  @override
  bool shouldRepaint(FullWidthCardGradientPainter oldDelegate) {
    return oldDelegate.pageOffset != pageOffset;
  }
}

class FullScreenParallaxSwiper extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final Function(int) onPageChanged;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const FullScreenParallaxSwiper({
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final Size deviceSize = MediaQuery.of(context).size;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    // Reduced nav height to maximize content space
    final double bottomNavHeight = 50 + bottomPadding;
    
    return Listener(
      onPointerDown: (_) => HapticFeedback.selectionClick(),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          
          if (details.primaryVelocity!.abs() > 200) {
            final int targetPage = details.primaryVelocity! > 0 
                ? (currentPage - 1).clamp(0, itemCount - 1)
                : (currentPage + 1).clamp(0, itemCount - 1);
                
            if (targetPage != currentPage) {
              HapticFeedback.selectionClick();
              controller.animateToPage(
                targetPage,
                duration: Duration(milliseconds: 400), // Faster transition
                curve: Curves.easeOutCubic,
              );
            }
          }
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification && 
                (notification.dragDetails?.delta.dx.abs() ?? 0) > 8.0) {
              HapticFeedback.selectionClick();
            }
            return true;
          },
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: itemCount,
            physics: OptimizedPagePhysics(),
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  double page = controller.hasClients
                      ? (controller.page ?? currentPage.toDouble())
                      : currentPage.toDouble();
                      
                  double pageOffset = page - index;
                  double absPageOffset = pageOffset.abs();
                  
                  // More subtle transformations for cleaner transitions
                  double scale = 1.0 - (absPageOffset * 0.02).clamp(0.0, 0.04);
                  double opacity = math.max(0.2, 1.0 - (absPageOffset * 0.35));
                  double parallaxOffset = pageOffset * deviceSize.width * 0.06;
                  double yOffset = absPageOffset * 5;
                  
                  return Opacity(
                    opacity: opacity,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..translate(parallaxOffset, yOffset)
                        ..scale(scale),
                      child: Container(
                        // Full edge-to-edge container for maximum space
                        width: deviceSize.width,
                        height: deviceSize.height,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          boxShadow: absPageOffset > 0.1 ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ] : null,
                        ),
                        child: Stack(
                          children: [
                            // Gradient overlay
                            Positioned.fill(
                              child: CustomPaint(
                                painter: EnhancedScreenGradientPainter(
                                  pageOffset: pageOffset,
                                  isActive: absPageOffset < 0.5,
                                ),
                              ),
                            ),
                            
                            // Content with optimized padding
                            SafeArea(
                              bottom: false, // Allow content to extend to bottom
                              child: Padding(
                                padding: EdgeInsets.only(
                                  // Reduced bottom padding for more content space
                                  bottom: bottomNavHeight - 10,
                                ),
                                child: child!,
                              ),
                            ),
                            
                            // Edge shadow - only during active swipe
                            if (absPageOffset > 0.01 && absPageOffset < 0.7) Positioned(
                              top: 0,
                              bottom: 0,
                              left: pageOffset > 0 ? 0 : null,
                              right: pageOffset < 0 ? 0 : null,
                              width: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: pageOffset > 0 
                                        ? Alignment.centerLeft 
                                        : Alignment.centerRight,
                                    end: pageOffset > 0 
                                        ? Alignment.centerRight 
                                        : Alignment.centerLeft,
                                    colors: [
                                      Colors.black.withOpacity(math.min(0.3, absPageOffset * 0.5)),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // More compact page indicator
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Opacity(
                                opacity: 0.7,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "${index + 1}/${itemCount}",
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: itemBuilder(context, index),
              );
            },
          ),
        ),
      ),
    );
  }
}

class FullScreenCardGradientPainter extends CustomPainter {
  final double pageOffset;
  final bool isActive;
  
  FullScreenCardGradientPainter({
    required this.pageOffset,
    required this.isActive,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Left-right gradient intensity based on swipe direction
    double leftIntensity = pageOffset > 0 
        ? (pageOffset * 0.15).clamp(0.0, 0.15) 
        : 0.0;
    double rightIntensity = pageOffset < 0 
        ? (pageOffset * -0.15).clamp(0.0, 0.15)
        : 0.0;
    
    // Create horizontal gradient overlay
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(leftIntensity),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(rightIntensity),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(rect);
      
    canvas.drawRect(rect, paint);
    
    // Add subtle top and bottom vignettes for better readability
    final Paint topVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.black.withOpacity(0.25),
          Colors.transparent,
        ],
        stops: [0.0, 0.35],
      ).createShader(rect);
      
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.25),
      topVignette
    );
    
    // Bottom vignette for nav area separation
    final Paint bottomVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          Colors.black.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: [0.0, 0.4],
      ).createShader(rect);
      
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      bottomVignette
    );
  }
  
  @override
  bool shouldRepaint(FullScreenCardGradientPainter oldDelegate) {
    return oldDelegate.pageOffset != pageOffset || 
           oldDelegate.isActive != isActive;
  }
}

class ImprovedPagePhysics extends ScrollPhysics {
  const ImprovedPagePhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  ImprovedPagePhysics applyTo(ScrollPhysics? ancestor) {
    return ImprovedPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 40,        // Reduced mass for quicker response
        stiffness: 150,  // Increased stiffness for snappier feel
        damping: 1.2,    // Optimized damping to prevent oscillation
      );

  @override
  double get dragStartDistanceMotionThreshold => 2.0; // More sensitive detection

  @override
  double get minFlingVelocity => 200.0; // Lower threshold for easier page flips

  @override
  double get maxFlingVelocity => 8000.0;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final double pageSize = position.viewportDimension;
    final double currentPage = position.pixels / pageSize;
    
    // Improved target page calculation
    double targetPage;
    final double remainder = currentPage - currentPage.floor();
    
    if (velocity.abs() >= 300.0) {
      // For faster flicks, follow the direction
      targetPage = velocity > 0.0 ? currentPage.ceil().toDouble() : currentPage.floor().toDouble();
    } else if (velocity.abs() >= 50.0) {
      // For medium flicks, use direction but with threshold
      if (velocity > 0 && remainder > 0.1) {
        targetPage = currentPage.ceil().toDouble();
      } else if (velocity < 0 && remainder < 0.9) {
        targetPage = currentPage.floor().toDouble();
      } else {
        targetPage = currentPage.round().toDouble();
      }
    } else {
      // For slow/no velocity, use 40/60 threshold for natural feel
      if (remainder < 0.4) {
        targetPage = currentPage.floor().toDouble();
      } else if (remainder > 0.6) {
        targetPage = currentPage.ceil().toDouble();
      } else {
        targetPage = currentPage.round().toDouble();
      }
    }
    
    final double targetPixels = targetPage * pageSize;
    
    if ((targetPixels - position.pixels).abs() < 0.5) {
      return null;
    }
    
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}

class EnhancedScreenGradientPainter extends CustomPainter {
  final double pageOffset;
  final bool isActive;
  
  EnhancedScreenGradientPainter({
    required this.pageOffset,
    required this.isActive,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final double absOffset = pageOffset.abs();
    
    // Optimized gradient creation
    final Rect rect = Offset.zero & size;
    
    // Only paint complex gradients when necessary
    if (pageOffset != 0) {
      // Horizontal gradient for swipe effect
      double leftIntensity = pageOffset > 0 
          ? (pageOffset * 0.08).clamp(0.0, 0.08) 
          : 0.0;
      double rightIntensity = pageOffset < 0 
          ? (pageOffset * -0.08).clamp(0.0, 0.08)
          : 0.0;
      
      final Paint paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withOpacity(leftIntensity),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(rightIntensity),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ).createShader(rect);
        
      canvas.drawRect(rect, paint);
    }
    
    // Add vignettes with repaint optimization
    if (isActive) {
      // Top vignette
      final Paint topVignette = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.black.withOpacity(0.25),
            Colors.transparent,
          ],
          stops: [0.0, 0.35],
        ).createShader(rect);
        
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.25),
        topVignette
      );
      
      // Bottom vignette for nav area separation
      final Paint bottomVignette = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
          stops: [0.0, 0.4],
        ).createShader(rect);
        
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
        bottomVignette
      );
    }
  }
  
  @override
  bool shouldRepaint(EnhancedScreenGradientPainter oldDelegate) {
    // Optimize repainting
    return (oldDelegate.pageOffset - pageOffset).abs() > 0.01 || 
           oldDelegate.isActive != isActive;
  }
}

class AnimatedRippleContainer extends StatefulWidget {
  @override
  _AnimatedRippleContainerState createState() => _AnimatedRippleContainerState();
}

class _AnimatedRippleContainerState extends State<AnimatedRippleContainer> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3), // Slower for better performance
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return RepaintBoundary( // Performance optimization
          child: CustomPaint(
            painter: RipplePainter(
              _controller.value,
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  
  RipplePainter(this.progress);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Create a smoother ripple with two layers
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.fill;
    
    final overlayPaint = Paint()
      ..color = Colors.white.withOpacity(0.01)
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width * 0.5, size.height * 0.5);
    
    // Base ripple - slower cycle
    final baseRadius = size.width * 0.4 * 
        (0.5 + 0.5 * math.sin(progress * math.pi));
    canvas.drawCircle(center, baseRadius, basePaint);
    
    // Overlay ripple - faster cycle, offset from base
    final overlayRadius = size.width * 0.25 * 
        (0.5 + 0.5 * math.sin(progress * math.pi * 2 + math.pi/2));
    canvas.drawCircle(center, overlayRadius, overlayPaint);
  }
  
  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    // Only repaint when significant changes occur
    return (oldDelegate.progress - progress).abs() > 0.05;
  }
}

class EnhancedProgressPainter extends CustomPainter {
  final double progress;
  final double pageOffset;
  final bool isPlaying;
  
  EnhancedProgressPainter({
    required this.progress,
    required this.pageOffset,
    required this.isPlaying,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Simple background
    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.fill;
      
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Only draw complex foreground when needed
    if (progress <= 0) return;
    
    final width = size.width * progress;
    
    if (isPlaying) {
      // Calculate time only once for consistent wave
      final double timeOffset = DateTime.now().millisecondsSinceEpoch * 0.001;
      
      // Create simple but effective wave effect
      final path = Path();
      path.moveTo(0, size.height / 2);
      
      // Use larger steps for better performance (8px)
      for (double x = 0; x <= width; x += 8) {
        // Combine two waves for more organic feel
        final double wave1 = math.sin(x * 0.05 + timeOffset) * size.height * 0.3;
        final double wave2 = math.sin(x * 0.02 + timeOffset * 0.7) * size.height * 0.1;
        final double y = (wave1 + wave2) + (size.height / 2);
        
        path.lineTo(x, y);
      }
      
      // Close the path
      path.lineTo(width, size.height);
      path.lineTo(0, size.height);
      path.close();
      
      // Use a nice gradient that transitions from pure white to soft white
      final progressPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [
            Colors.white,
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.8),
          ],
          [0.0, 0.7, 1.0],
        );
        
      canvas.drawPath(path, progressPaint);
    } else {
      // Simple rectangle when paused
      final progressPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(Rect.fromLTWH(0, 0, width, size.height), progressPaint);
    }
  }
  
  @override
  bool shouldRepaint(EnhancedProgressPainter oldDelegate) {
    // Minimize repaints for better performance
    if (isPlaying != oldDelegate.isPlaying) return true;
    if ((progress - oldDelegate.progress).abs() > 0.01) return true;
    if (isPlaying && (DateTime.now().millisecondsSinceEpoch % 100) < 20) return true;
    return false;
  }
}

class EnhancedBackgroundPainter extends CustomPainter {
  final double pageOffset;
  final int currentPage;
  final double easedFraction;
  
  EnhancedBackgroundPainter({
    required this.pageOffset,
    required this.currentPage,
    required this.easedFraction,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Reduce to 8 elements for better performance
    final int maxShapes = 8;
    
    // Use more optimized drawing
    for (int i = 0; i < maxShapes; i++) {
      // Using deterministic randomness based on shape index
      final int seed = (i * 1000 + currentPage * 10).toInt();
      final math.Random rng = math.Random(seed);
      
      // Create more varied depths for more interesting parallax
      double depth = (i / maxShapes) + (rng.nextDouble() * 0.05);
      double parallaxFactor = math.pow(1.0 - depth, 2.0).toDouble();
      
      // More varied angles
      double angle = i * (math.pi / 4) + (rng.nextDouble() * 0.3);
      
      // Create varied shape types for visual interest
      int shapeType = i % 3; // Reduced to 3 shape types
      
      // Position with smoother parallax movement
      double radius = size.width * (0.05 + (depth * 0.15));
      double centerX = size.width * 0.5 + math.cos(angle) * size.width * 0.6;
      double centerY = size.height * 0.5 + math.sin(angle) * size.height * 0.5;
      
      // Apply parallax movement - reduced intensity for less janky motion
      double offsetX = pageOffset * size.width * 0.1 * parallaxFactor;
      centerX -= offsetX;
      
      // Improved color with better opacity and blending
      Color shapeColor = _getShapeColor(currentPage, depth, i);
      
      final Paint shapePaint = Paint()
        ..color = shapeColor
        ..style = PaintingStyle.fill;
      
      // Draw different shape types - simplified for performance
      switch (shapeType) {
        case 0: // Circle
          canvas.drawCircle(Offset(centerX, centerY), radius, shapePaint);
          break;
          
        case 1: // Rounded rectangle
          double width = radius * 1.8;
          double height = radius * (0.7 + math.sin(angle) * 0.4);
          
          final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(centerX, centerY),
              width: width,
              height: height,
            ),
            Radius.circular(radius * 0.5),
          );
          
          canvas.drawRRect(rect, shapePaint);
          break;
          
        case 2: // Oval - simplified from previous version
          canvas.save();
          canvas.translate(centerX, centerY);
          canvas.rotate(angle * 0.5);
          canvas.scale(1.5, 0.8);
          canvas.drawCircle(Offset.zero, radius * 0.7, shapePaint);
          canvas.restore();
          break;
      }
    }
  }
  
  Color _getShapeColor(int page, double depth, int seed) {
    // Define color palettes for each page - more harmonious colors
    final List<List<Color>> pagePalettes = [
      [Color(0x33FFFFFF), Color(0x29FFFFFF), Color(0x1FFFFFFF)], // Home
      [Color(0x33D6A4FF), Color(0x29AD89FF), Color(0x1FC9A0FF)], // Search
      [Color(0x336ADFFF), Color(0x2959A7FF), Color(0x1F81CAFF)], // Profile
      [Color(0x33F09CFF), Color(0x29D35EFF), Color(0x1FFFA3FF)], // Rewards
    ];
    
    int paletteIndex = page.clamp(0, pagePalettes.length - 1);
    int nextIndex = (paletteIndex + 1).clamp(0, pagePalettes.length - 1);
    int colorIndex = seed % pagePalettes[paletteIndex].length;
    
    // Get colors from current and next page palettes
    final Color currentColor = pagePalettes[paletteIndex][colorIndex];
    final Color nextColor = pagePalettes[nextIndex][colorIndex];
    
    // Interpolate between pages for smooth transition
    final Color blendedColor = Color.lerp(currentColor, nextColor, easedFraction)!;
    
    // Apply depth effect to color for layering
    final opacity = (blendedColor.opacity * (0.5 + depth * 0.5))
        .clamp(0.0, blendedColor.opacity);
    
    return blendedColor.withOpacity(opacity);
  }
  
  @override
  bool shouldRepaint(EnhancedBackgroundPainter oldDelegate) {
    return (oldDelegate.pageOffset - pageOffset).abs() > 0.01 ||
           oldDelegate.currentPage != currentPage ||
           (oldDelegate.easedFraction - easedFraction).abs() > 0.01;
  }
}

class OptimizedPagePhysics extends ScrollPhysics {
  const OptimizedPagePhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  OptimizedPagePhysics applyTo(ScrollPhysics? ancestor) {
    return OptimizedPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 30,
    stiffness: 150,
    damping: 1.2,
  );

  @override
  double get dragStartDistanceMotionThreshold => 2.0;

  @override
  double get minFlingVelocity => 200.0;

  @override
  double get maxFlingVelocity => 8000.0;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final double pageSize = position.viewportDimension;
    final double currentPage = position.pixels / pageSize;
    
    // Improved target page calculation
    double targetPage;
    final double remainder = currentPage - currentPage.floor();
    
    if (velocity.abs() >= 300.0) {
      // For faster flicks, follow the direction
      targetPage = velocity > 0.0 ? currentPage.ceil().toDouble() : currentPage.floor().toDouble();
    } else if (velocity.abs() >= 50.0) {
      // For medium flicks, use direction but with threshold
      if (velocity > 0 && remainder > 0.1) {
        targetPage = currentPage.ceil().toDouble();
      } else if (velocity < 0 && remainder < 0.9) {
        targetPage = currentPage.floor().toDouble();
      } else {
        targetPage = currentPage.round().toDouble();
      }
    } else {
      // For slow/no velocity, use 40/60 threshold for natural feel
      if (remainder < 0.4) {
        targetPage = currentPage.floor().toDouble();
      } else if (remainder > 0.6) {
        targetPage = currentPage.ceil().toDouble();
      } else {
        targetPage = currentPage.round().toDouble();
      }
    }
    
    final double targetPixels = targetPage * pageSize;
    
    if ((targetPixels - position.pixels).abs() < 0.5) {
      return null;
    }
    
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}

