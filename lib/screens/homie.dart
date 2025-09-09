// the take reborn
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/services/audio_player_service.dart';
import 'package:musicgram4/screens/expandedplayer.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  final Function(Album)? onPlaySong;
  final bool inSelectionMode;
  final Function(Album)? onSongSelected;
  final bool isSelectingForPairedListening;
  
  const HomePage({
    Key? key, 
    this.onPlaySong,
    this.inSelectionMode = false,
    this.onSongSelected,
    this.isSelectingForPairedListening = false,
  }) : super(key: key);
  
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<Album> albums = [];
  Set<Album> _recentlyPlayed = {};
  static const int _maxRecentlyPlayed = 5;
  String userName = "User";
  ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _greetingVisible = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Audio player service
  final AudioPlayerService _audioService = AudioPlayerService();
  
  // Current playback state
  Album? _currentlyPlaying;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _songDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // Initialize audio service
    _audioService.init();
    _setupAudioListeners();
    
    fetchSongsFromAppwrite();
    loadRecentlyPlayed();
    fetchUserName();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    _audioService.onPlayPause = () {
      if (mounted) {
        setState(() {
          _isPlaying = _audioService.isPlaying;
        });
      }
    };
    
    _audioService.onPositionChanged = (position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    };
    
    _audioService.onDurationChanged = (duration) {
      if (duration != null && mounted) {
        setState(() {
          _songDuration = duration;
        });
      }
    };
    
    _audioService.onComplete = () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    };
  }

  Future<void> fetchUserName() async {
    try {
      final currentUser = await account.get();
      String displayName = currentUser.name;
      
      if (displayName.isEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String email = prefs.getString('user_email') ?? '';
        displayName = email.split('@')[0].replaceFirst(
          email.isNotEmpty ? email[0] : '', 
          email.isNotEmpty ? email[0].toUpperCase() : ''
        );
      }
      
      setState(() {
        userName = displayName;
      });
      
      try {
        final documents = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: 'users',
          queries: [
            Query.equal('user_id', currentUser.$id),
          ],
        );
        
        if (documents.documents.isNotEmpty) {
          final userProfile = documents.documents.first;
          if (userProfile.data.containsKey('name') && 
              userProfile.data['name'] != null &&
              userProfile.data['name'].toString().isNotEmpty) {
            setState(() {
              userName = userProfile.data['name'];
            });
          }
        }
      } catch (e) {
        print('Error fetching user profile from database: $e');
      }
    } catch (e) {
      print('Error fetching user data from Appwrite: $e');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String email = prefs.getString('user_email') ?? '';
      setState(() {
        userName = email.split('@')[0].replaceFirst(
          email.isNotEmpty ? email[0] : '', 
          email.isNotEmpty ? email[0].toUpperCase() : ''
        );
      });
    }
  }

  Future<void> fetchSongsFromAppwrite() async {
    try {
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
      );
      
      final List<Album> fetchedAlbums = await Future.wait(
        result.files.where((file) => file.name.endsWith('.mp3')).map((file) async {
          String downloadUrl = await getFileViewUrl(file.$id);
          String name = file.name.replaceAll('.mp3', '');
          String? imageUrl = await getImageUrl(name);
          
          return Album(
            name, 
            downloadUrl, 
            imageUrl,
            id: file.$id,
            artist: 'Unknown Artist',
          );
        }).toList()
      );

      setState(() {
        albums = fetchedAlbums;
      });
    } catch (e) {
      print('Error fetching songs from Appwrite: $e');
    }
  }

  Future<String> getFileViewUrl(String fileId) async {
    return '${AppConfig.endpoint}/storage/buckets/${AppConfig.storageId}/files/$fileId/download?project=${AppConfig.projectId}';
  }

  Future<String?> getImageUrl(String songName) async {
    try {
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
        queries: [
          Query.equal('name', '$songName.jpg'),
        ],
      );
      
      if (result.files.isNotEmpty) {
        return getFileViewUrl(result.files.first.$id);
      }
      
      final resultPng = await storage.listFiles(
        bucketId: AppConfig.storageId,
        queries: [
          Query.equal('name', '$songName.png'),
        ],
      );
      
      if (resultPng.files.isNotEmpty) {
        return getFileViewUrl(resultPng.files.first.$id);
      }
      
      return null;
    } catch (e) {
      print('Error fetching image for $songName: $e');
      return null;
    }
  }

  Future<void> loadRecentlyPlayed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recentlyPlayedJson = prefs.getStringList('recently_played') ?? [];
    setState(() {
      _recentlyPlayed = recentlyPlayedJson
          .map((json) => Album.fromJson(jsonDecode(json)))
          .toSet();
    });
  }

  Future<void> saveRecentlyPlayed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recentlyPlayedJson = _recentlyPlayed
        .map((album) => jsonEncode(album.toJson()))
        .toList();
    await prefs.setStringList('recently_played', recentlyPlayedJson);
  }

  void addToRecentlyPlayed(Album album) {
    setState(() {
      _recentlyPlayed = {album, ..._recentlyPlayed}.take(_maxRecentlyPlayed).toSet();
    });
    saveRecentlyPlayed();
  }
  
  // Core song playing functionality
  Future<void> _playSong(Album album) async {
    try {
      print("Playing song: ${album.name}");
      
      // Add to recently played
      addToRecentlyPlayed(album);
      
      // Update current playing state
      setState(() {
        _currentlyPlaying = album;
        _isPlaying = true;
        _currentPosition = Duration.zero;
        _songDuration = Duration.zero;
      });
      
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.greenAccent,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading ${album.name}...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      
      // Play the song using audio service
      await _audioService.playSong(album);
      
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        
        // Navigate to expanded player
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpandedMusicPlayer(
              album: album,
              audioService: _audioService,
              onNextSong: () => _playNextSong(),
              onPreviousSong: () => _playPreviousSong(),
              onTogglePlayPause: () => _togglePlayPause(),
              isPlaying: _isPlaying,
            ),
          ),
        );
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now playing: ${album.name}'),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error playing song: $e');
      
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        
        setState(() {
          _isPlaying = false;
          _currentlyPlaying = null;
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing song: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Quick play functionality for testing
  Future<void> _quickPlay(Album album) async {
    try {
      print("Quick playing: ${album.name}");
      
      setState(() {
        _currentlyPlaying = album;
        _isPlaying = true;
      });
      
      await _audioService.playSong(album);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Playing: ${album.name}',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Stop',
            textColor: Colors.white,
            onPressed: () {
              _audioService.stop();
              setState(() {
                _isPlaying = false;
                _currentlyPlaying = null;
              });
            },
          ),
        ),
      );
    } catch (e) {
      print('Error in quick play: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing song: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
  }

  void _playNextSong() {
    if (albums.isEmpty || _currentlyPlaying == null) return;
    
    int currentIndex = albums.indexWhere((album) => album.id == _currentlyPlaying!.id);
    int nextIndex = (currentIndex + 1) % albums.length;
    _playSong(albums[nextIndex]);
  }

  void _playPreviousSong() {
    if (albums.isEmpty || _currentlyPlaying == null) return;
    
    int currentIndex = albums.indexWhere((album) => album.id == _currentlyPlaying!.id);
    int prevIndex = (currentIndex - 1 + albums.length) % albums.length;
    _playSong(albums[prevIndex]);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, ";
    if (hour < 18) return "Good afternoon, ";
    return "Good evening, ";
  }

  Widget _buildFunctionTiles() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.playlist_play, color: Colors.greenAccent),
          title: Text(
            "Playlists",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          onTap: () {},
        ),
        ListTile(
          leading: Icon(Icons.favorite, color: Colors.redAccent),
          title: Text(
            "Favorites",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          onTap: () {},
        ),
        ListTile(
          leading: Icon(Icons.settings, color: Colors.grey),
          title: Text(
            "Settings",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          onTap: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: widget.isSelectingForPairedListening
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Select Song for Paired Listening',
                style: GoogleFonts.poppins(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(color: Colors.greenAccent),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting banner
            if (_greetingVisible && !widget.isSelectingForPairedListening)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.black87,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}$userName',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: screenSize.width < 360 ? 20 : 24,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Let's explore some music!",
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width < 360 ? 14 : 16,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _greetingVisible = false;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              
            // Page heading
            if (!widget.isSelectingForPairedListening)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  "Home",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: screenSize.width < 360 ? 28 : 32,
                    color: Colors.white,
                  ),
                ),
              ),
            
            // Main scrollable content
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: BouncingScrollPhysics(),
                children: [
                  if (!widget.isSelectingForPairedListening) _buildFunctionTiles(),
                  
                  // Albums section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      widget.isSelectingForPairedListening
                          ? "Select a Song"
                          : "Recommended Albums",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  // Albums grid
                  _buildResponsiveAlbumGrid(screenSize),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveAlbumGrid(Size screenSize) {
    final crossAxisCount = screenSize.width < 600 ? 2 : 3;
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return _buildAlbumCard(album);
        },
      ),
    );
  }

  Widget _buildAlbumCard(Album album) {
    final isCurrentPlaying = _currentlyPlaying?.id == album.id;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        
        if (widget.isSelectingForPairedListening && widget.onSongSelected != null) {
          widget.onSongSelected!(album);
        } else if (widget.inSelectionMode && widget.onSongSelected != null) {
          widget.onSongSelected!(album);
        } else {
          if (widget.onPlaySong != null) {
            widget.onPlaySong!(album);
          } else {
            _playSong(album);
          }
        }
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isCurrentPlaying ? Colors.greenAccent.withOpacity(0.2) : Colors.grey[900],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Album image
                  Expanded(
                    flex: 3,
                    child: album.imageUrl != null
                        ? Image.network(
                            album.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: Center(
                                  child: Icon(
                                    Icons.music_note, 
                                    size: 40, 
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: Icon(
                                Icons.music_note, 
                                size: 40, 
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                  ),
                  
                  // Album info
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.black45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            album.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isCurrentPlaying ? Colors.greenAccent : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (album.artist != null && album.artist!.isNotEmpty)
                            Text(
                              album.artist!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isCurrentPlaying ? Colors.greenAccent.withOpacity(0.8) : Colors.white70,
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
              
              // Currently playing indicator
              if (isCurrentPlaying)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
              
              // Quick play button overlay
              if (!widget.inSelectionMode && !widget.isSelectingForPairedListening)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _quickPlay(album);
                    },
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              
              // Selection mode indicator
              if (widget.inSelectionMode || widget.isSelectingForPairedListening)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// UPDATED: Album class with proper serialization
class Album {
  final String id;
  final String name;
  final String downloadUrl;
  final String? imageUrl;
  final String? artist;
  final DateTime? createdAt;
  
  Album(
    this.name,
    this.downloadUrl,
    this.imageUrl, {
    this.id = 'default_song',
    this.artist,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'downloadUrl': downloadUrl,
        'imageUrl': imageUrl,
        'artist': artist,
        'createdAt': createdAt?.toIso8601String(),
      };

  static Album fromJson(Map<String, dynamic> json) => Album(
        json['name'] ?? 'Unknown Song',
        json['downloadUrl'] ?? '',
        json['imageUrl'],
        id: json['id'] ?? 'default_song',
        artist: json['artist'],
        createdAt: json['createdAt'] != null 
            ? DateTime.tryParse(json['createdAt']) 
            : null,
      );
}