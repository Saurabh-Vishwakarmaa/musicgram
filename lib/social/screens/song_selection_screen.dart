import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/screens/homie.dart';
import 'package:musicgram4/services/appwrite_service.dart' hide AppConfig;
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';



/*new one which will cause issue*/ 
class Album {
  final String id;
  final String name;
  final String downloadUrl;
  final String? imageUrl;
  final String? artist;

  Album({
    required this.id,
    required this.name,
    required this.downloadUrl,
    this.imageUrl,
    this.artist,
  });
}

class SongSelectionScreen extends StatefulWidget {
  const SongSelectionScreen({Key? key}) : super(key: key);

  @override
  State<SongSelectionScreen> createState() => _SongSelectionScreenState();
}

class _SongSelectionScreenState extends State<SongSelectionScreen> {
  List<Album> _availableSongs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  List<Album> _filteredSongs = [];
  
  @override
  void initState() {
    super.initState();
    _loadSongs();
  }
  
  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get songs from Appwrite storage
      final result = await AppwriteService.storage.listFiles(
        bucketId: AppConfig.storageId,
      );
      
      List<Album> songs = [];
      
      for (var file in result.files) {
        if (file.name.toLowerCase().endsWith('.mp3')) {
          // This is a music file
          final String songId = file.$id;
          final String songName = file.name.replaceAll('.mp3', '');
          final String downloadUrl = AppwriteService.getFilePreview(songId);
          
          // Check for a matching image with the same name
          String? imageUrl;
          try {
            final imgResult = await AppwriteService.storage.listFiles(
              bucketId: AppConfig.storageId,
              queries: [
                Query.search('name', songName),
                Query.limit(1),
              ],
            );
            
            for (var imgFile in imgResult.files) {
              if (imgFile.name.toLowerCase().endsWith('.jpg') || 
                  imgFile.name.toLowerCase().endsWith('.png') ||
                  imgFile.name.toLowerCase().endsWith('.jpeg')) {
                imageUrl = AppwriteService.getFilePreview(imgFile.$id);
                break;
              }
            }
          } catch (e) {
            print('Error finding image for $songName: $e');
          }
          
          songs.add(Album(
            id: songId,
            name: songName,
            downloadUrl: downloadUrl,
            imageUrl: imageUrl,
            artist: 'Unknown Artist',
          ));
        }
      }
      
      setState(() {
        _availableSongs = songs;
        _filteredSongs = List.from(_availableSongs);
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading songs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading songs: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _filterSongs(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      
      if (_searchQuery.isEmpty) {
        _filteredSongs = List.from(_availableSongs);
      } else {
        _filteredSongs = _availableSongs.where((song) {
          return song.name.toLowerCase().contains(_searchQuery) ||
                 (song.artist?.toLowerCase() ?? '').contains(_searchQuery);
        }).toList();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Select a Song',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filterSongs,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Songs list
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : _filteredSongs.isEmpty
                ? _buildEmptySongsList()
                : ListView.builder(
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      return _buildSongItem(song);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptySongsList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No songs available'
                : 'No songs matching "$_searchQuery"',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 18,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: () {
                // Create sample songs for testing if no songs available
                _createSampleSongs();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              child: Text('Create Sample Songs'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSongItem(Album song) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          // Return the selected song to the previous screen
          Navigator.pop(context, song);
        },
        contentPadding: EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 56,
            height: 56,
            color: Colors.grey[800],
            child: song.imageUrl != null
                ? Image.network(
                    song.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      Icon(Icons.music_note, color: Colors.white, size: 30),
                  )
                : Icon(Icons.music_note, color: Colors.white, size: 30),
          ),
        ),
        title: Text(
          song.name,
          style: GoogleFonts.firaSansCondensed(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          song.artist ?? 'Unknown Artist',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        trailing: Icon(
          Icons.play_circle_fill,
          color: Colors.greenAccent,
          size: 30,
        ),
      ),
    );
  }
  
  // Helper method to create sample songs for testing
  Future<void> _createSampleSongs() async {
    setState(() {
      _isLoading = true;
    });
    
    // Use sample audio URLs from public sources
    final sampleSongs = [
      {
        'id': 'sample_1',
        'name': 'Sample Song 1',
        'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'artist': 'SoundHelix',
      },
      {
        'id': 'sample_2',
        'name': 'Sample Song 2',
        'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        'artist': 'SoundHelix',
      },
      {
        'id': 'sample_3',
        'name': 'Sample Song 3',
        'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        'artist': 'SoundHelix',
      },
    ];
    
    List<Album> albums = sampleSongs.map((song) => Album(
      name: song['name']!,
      downloadUrl: song['url']!,
      imageUrl: 'https://picsum.photos/200?random=${song['id']}',
      id: song['id']!,
      artist: song['artist'],
    )).toList();
    
    setState(() {
      _availableSongs = albums;
      _filteredSongs = List.from(_availableSongs);
      _isLoading = false;
    });
  }
}