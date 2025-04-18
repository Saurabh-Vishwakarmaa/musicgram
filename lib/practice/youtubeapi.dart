// youtube_videos_widget.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

class YouTubeVideo {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;
  final String viewCount;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.viewCount,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    final statistics = json['statistics'] ?? {};
    return YouTubeVideo(
      id: json['id'] is String ? json['id'] : json['id']['videoId'],
      title: snippet['title'],
      thumbnailUrl: snippet['thumbnails']['medium']['url'],
      channelTitle: snippet['channelTitle'],
      viewCount: statistics['viewCount']?.toString() ?? '0',
    );
  }
}

class YouTubeVideosWidget extends StatefulWidget {
  final String apiKey;
  
  const YouTubeVideosWidget({
    Key? key,
    required this.apiKey,
  }) : super(key: key);

  @override
  _YouTubeVideosWidgetState createState() => _YouTubeVideosWidgetState();
}

class _YouTubeVideosWidgetState extends State<YouTubeVideosWidget> {
  List<YouTubeVideo> _videos = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTrendingVideos();
  }

  Future<void> _fetchTrendingVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos'
        '?part=snippet,statistics'
        '&chart=mostPopular'
        '&maxResults=20'
        '&videoCategoryId=10' // Music category
        '&key=${widget.apiKey}'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _videos = (data['items'] as List)
              .map((item) => YouTubeVideo.fromJson(item))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error fetching videos: $e');
    }
  }

  Widget _buildVideoCard(YouTubeVideo video) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              video.thumbnailUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(Icons.error_outline),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  video.channelTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      '${int.parse(video.viewCount).toString()} views',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(  // Added Material widget here
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: GoogleFonts.poppins(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchTrendingVideos,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchTrendingVideos,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) {
                      return _buildVideoCard(_videos[index]);
                    },
                  ),
                ),
    );
  }
}