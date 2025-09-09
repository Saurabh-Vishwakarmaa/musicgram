import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/main.dart';
import 'package:musicgram4/screens/homie.dart' as homie;
import 'package:musicgram4/services/appwrite_service.dart' as service;
import 'package:musicgram4/services/audio_player_service.dart';
import 'package:musicgram4/screens/expandedplayer.dart';
import 'package:flutter/services.dart';

class SongSelectionScreen extends StatefulWidget {
  final String? sessionId;
  final String? currentUserId;
  final String? partnerUserId;

  const SongSelectionScreen({
    Key? key,
    this.sessionId,
    this.currentUserId,
    this.partnerUserId,
  }) : super(key: key);

  @override
  _SongSelectionScreenState createState() => _SongSelectionScreenState();
}

class _SongSelectionScreenState extends State<SongSelectionScreen> {
  final SocialDatabaseService _socialService = SocialDatabaseService(
    databases: databases,
    storage: storage,
    account: account,
  );

  List<homie.Album> _allSongs = [];
  List<homie.Album> _displayedSongs = [];
  Map<String, String> _songOwners = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreSongs = true;

  String? _currentUserId;
  String? _currentUsername;

  // ADD: Audio player integration
  final AudioPlayerService _audioService = AudioPlayerService();
  homie.Album? _currentlyPlaying;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _songDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    
    // Initialize audio service
    _audioService.init();
    _setupAudioListeners();
    
    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  // ADD: Audio listeners setup
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

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreSongs) {
        _loadMoreSongs();
      }
    }
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get current user info
      final account = await service.AppwriteService.account.get();
      _currentUserId = account.$id;
      _currentUsername = account.name;

      print('Current user: $_currentUserId ($_currentUsername)');
      print('Partner user: ${widget.partnerUserId}');

      // Load initial songs using the same method as homie.dart
      await _loadInitialSongs();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing data: $e');
      setState(() {
        _error = 'Failed to load songs: $e';
        _isLoading = false;
      });
    }
  }

  // FIXED: Use the same fetching mechanism as homie.dart
  Future<void> _loadInitialSongs() async {
    try {
      _currentPage = 0;
      _allSongs.clear();
      _displayedSongs.clear();
      _songOwners.clear();

      // Get all files from storage (same as homie.dart)
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
      );

      print('Found ${result.files.length} total files');

      // Filter and process MP3 files (same as homie.dart)
      final List<homie.Album> fetchedAlbums = await Future.wait(
        result.files.where((file) => file.name.endsWith('.mp3')).map((file) async {
          String downloadUrl = await getFileViewUrl(file.$id);
          String name = file.name.replaceAll('.mp3', '');
          String? imageUrl = await getImageUrl(name);
          
          return homie.Album(
            name,
            downloadUrl,
            imageUrl,
            id: file.$id,
            artist: 'Unknown Artist',
            createdAt: DateTime.now(), // Use current time as fallback
          );
        }).toList()
      );

      print('Processed ${fetchedAlbums.length} songs');

      // Set owner info for all songs
      for (var album in fetchedAlbums) {
        _songOwners[album.downloadUrl] = 'Available';
      }

      // Sort songs by name
      fetchedAlbums.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _allSongs = fetchedAlbums;
      });

      // Load first page
      _loadNextPage();
    } catch (e) {
      print('Error loading initial songs: $e');
      throw e;
    }
  }

  // ADDED: Same helper methods as homie.dart
  Future<String> getFileViewUrl(String fileId) async {
    return '${AppConfig.endpoint}/storage/buckets/${AppConfig.storageId}/files/$fileId/download?project=${AppConfig.projectId}';
  }

  Future<String?> getImageUrl(String songName) async {
    try {
      // Try to find JPG image
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
        queries: [
          Query.equal('name', '$songName.jpg'),
        ],
      );
      
      if (result.files.isNotEmpty) {
        return getFileViewUrl(result.files.first.$id);
      }
      
      // Try to find PNG image
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

  void _loadNextPage() {
    final startIndex = _currentPage * _pageSize;
    final endIndex = startIndex + _pageSize;
    
    if (startIndex >= _allSongs.length) {
      setState(() {
        _hasMoreSongs = false;
      });
      return;
    }

    final newSongs = _allSongs.sublist(
      startIndex,
      endIndex > _allSongs.length ? _allSongs.length : endIndex,
    );

    setState(() {
      _displayedSongs.addAll(newSongs);
      _currentPage++;
      _hasMoreSongs = endIndex < _allSongs.length;
    });
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore || !_hasMoreSongs) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate network delay for smooth UX
    await Future.delayed(Duration(milliseconds: 500));

    _loadNextPage();

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshSongs() async {
    try {
      await _loadInitialSongs();
    } catch (e) {
      print('Error refreshing songs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh songs'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ADD: Play/Pause functionality
  Future<void> _playSong(homie.Album album) async {
    try {
      print("Playing song: ${album.name}");
      
      // Update current playing state
      setState(() {
        _currentlyPlaying = album;
        _isPlaying = true;
        _currentPosition = Duration.zero;
        _songDuration = Duration.zero;
      });
      
      // Play the song using audio service
      await _audioService.playSong(album);
      
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
    } catch (e) {
      print('Error playing song: $e');
      
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

  // ADD: Quick play functionality
  Future<void> _quickPlay(homie.Album album) async {
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
    if (_displayedSongs.isEmpty || _currentlyPlaying == null) return;
    
    int currentIndex = _displayedSongs.indexWhere((album) => album.id == _currentlyPlaying!.id);
    int nextIndex = (currentIndex + 1) % _displayedSongs.length;
    _playSong(_displayedSongs[nextIndex]);
  }

  void _playPreviousSong() {
    if (_displayedSongs.isEmpty || _currentlyPlaying == null) return;
    
    int currentIndex = _displayedSongs.indexWhere((album) => album.id == _currentlyPlaying!.id);
    int prevIndex = (currentIndex - 1 + _displayedSongs.length) % _displayedSongs.length;
    _playSong(_displayedSongs[prevIndex]);
  }

  void _selectSong(homie.Album album) {
    Navigator.pop(context, album);
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
              'Select Song',
              style: GoogleFonts.poppins(
                color: Colors.greenAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_displayedSongs.isNotEmpty)
              Text(
                '${_displayedSongs.length} of ${_allSongs.length} songs',
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
            icon: Icon(Icons.refresh, color: Colors.greenAccent),
            onPressed: _refreshSongs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ADD: Mini player at top if song is playing
          if (_currentlyPlaying != null)
            _buildMiniPlayer(),
          
          // Main body
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ADD: Mini player widget
  Widget _buildMiniPlayer() {
    return Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Album art
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(6),
            ),
            child: _currentlyPlaying!.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _currentlyPlaying!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.music_note, color: Colors.greenAccent, size: 20);
                      },
                    ),
                  )
                : Icon(Icons.music_note, color: Colors.greenAccent, size: 20),
          ),
          
          SizedBox(width: 12),
          
          // Song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentlyPlaying!.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currentlyPlaying!.artist ?? 'Unknown Artist',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous, color: Colors.white),
                onPressed: _playPreviousSong,
                iconSize: 20,
              ),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.skip_next, color: Colors.white),
                onPressed: _playNextSong,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            ),
            SizedBox(height: 16),
            Text(
              'Loading songs...',
              style: GoogleFonts.poppins(
                color: Colors.greenAccent,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Error Loading Songs',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_displayedSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Colors.grey[600],
            ),
            SizedBox(height: 16),
            Text(
              'No Songs Available',
              style: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Upload some music to start sharing!',
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshSongs,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshSongs,
      color: Colors.greenAccent,
      backgroundColor: Colors.grey[900],
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount: _displayedSongs.length + (_hasMoreSongs ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedSongs.length) {
            return _buildLoadingItem();
          }

          final song = _displayedSongs[index];
          final owner = _songOwners[song.downloadUrl] ?? 'Unknown';
          
          return _buildSongItem(song, owner);
        },
      ),
    );
  }

  Widget _buildSongItem(homie.Album song, String owner) {
    final isCurrentlyPlaying = _currentlyPlaying?.id == song.id;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentlyPlaying ? Colors.greenAccent.withOpacity(0.1) : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentlyPlaying ? Colors.greenAccent.withOpacity(0.3) : Colors.grey[800]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            _selectSong(song);
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Album art
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: song.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.network(
                            song.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.music_note,
                                color: Colors.greenAccent,
                                size: 30,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.music_note,
                          color: Colors.greenAccent,
                          size: 30,
                        ),
                ),
                
                SizedBox(width: 16),
                
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.name,
                        style: GoogleFonts.poppins(
                          color: isCurrentlyPlaying ? Colors.greenAccent : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        song.artist ?? 'Unknown Artist',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.library_music,
                            color: Colors.greenAccent,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Available',
                            style: GoogleFonts.poppins(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Play button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (isCurrentlyPlaying) {
                      _togglePlayPause();
                    } else {
                      _quickPlay(song);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrentlyPlaying 
                          ? Colors.greenAccent.withOpacity(0.2) 
                          : Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCurrentlyPlaying && _isPlaying 
                          ? Icons.pause 
                          : Icons.play_arrow,
                      color: Colors.greenAccent,
                      size: 24,
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

  Widget _buildLoadingItem() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Loading more songs...',
            style: GoogleFonts.poppins(
              color: Colors.greenAccent,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}