import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:async';
import 'homie.dart';

class ExpandedMusicPlayer extends StatefulWidget {
  final Album album;
  final AudioPlayer audioPlayer;
  final just_audio.AudioPlayer? justAudioPlayer;
  final VoidCallback? onNextSong;
  final VoidCallback? onPreviousSong;
  final VoidCallback? onTogglePlayPause;
  final bool isPlaying;

  ExpandedMusicPlayer({
    required this.album, 
    required this.audioPlayer,
    this.justAudioPlayer,
    this.onNextSong,
    this.onPreviousSong,
    this.onTogglePlayPause,
    this.isPlaying = false,
  });

  @override
  _ExpandedMusicPlayerState createState() => _ExpandedMusicPlayerState();
}

class _ExpandedMusicPlayerState extends State<ExpandedMusicPlayer> {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _songDuration = Duration.zero;
  
  // Add these subscription variables
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _justAudioPositionSubscription;
  StreamSubscription? _justAudioDurationSubscription;
  StreamSubscription? _justAudioPlayingSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Get initial state from parent
    _isPlaying = widget.isPlaying;
    
    // Store subscriptions for later cleanup
    _positionSubscription = widget.audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {  // Check if widget is still in the tree
        setState(() {
          _currentPosition = position;
        });
      }
    });
    
    _durationSubscription = widget.audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _songDuration = duration;
        });
      }
    });
    
    // Set up listeners for just_audio if available
    if (widget.justAudioPlayer != null) {
      _justAudioPositionSubscription = widget.justAudioPlayer!.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });
      
      _justAudioDurationSubscription = widget.justAudioPlayer!.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _songDuration = duration;
          });
        }
      });
      
      _justAudioPlayingSubscription = widget.justAudioPlayer!.playingStream.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions when widget is disposed
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _justAudioPositionSubscription?.cancel();
    _justAudioDurationSubscription?.cancel();
    _justAudioPlayingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top app bar with back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      // Show options menu
                      _showOptionsMenu(context);
                    },
                  ),
                ],
              ),
            ),
            
            // Album artwork
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Hero(
                  tag: 'album_image_${widget.album.name}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      widget.album.imageUrl ?? 'https://via.placeholder.com/300',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.music_note,
                            size: 120,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            
            // Song information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Artist Name', // Replace with actual artist name
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            
            // Progress bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Seekable progress slider
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Colors.greenAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.greenAccent.withOpacity(0.3),
                    ),
                    child: Slider(
                      min: 0,
                      max: _songDuration.inSeconds.toDouble(),
                      value: _currentPosition.inSeconds.toDouble().clamp(0, _songDuration.inSeconds.toDouble()),
                      onChanged: (value) {
                        // Seek to the position
                        _seekTo(Duration(seconds: value.toInt()));
                      },
                    ),
                  ),
                  
                  // Time indicators
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          _formatDuration(_songDuration),
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Playback controls
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.shuffle, color: Colors.white70, size: 30),
                    onPressed: () {
                      // Implement shuffle functionality
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: Colors.white, size: 40),
                    onPressed: () {
                      // Play previous song
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 40,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.white, size: 40),
                    onPressed: () {
                      // Play next song
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.repeat, color: Colors.white70, size: 30),
                    onPressed: () {
                      // Implement repeat functionality
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePlayPause() {
    // Use the callback if provided, otherwise handle locally
    if (widget.onTogglePlayPause != null) {
      widget.onTogglePlayPause!();
      // Update local state to match parent's state
      setState(() {
        _isPlaying = !_isPlaying;
      });
    } else {
      // Fall back to local handling
      if (_isPlaying) {
        widget.justAudioPlayer?.pause();
        widget.audioPlayer.pause();
      } else {
        if (widget.justAudioPlayer != null && 
            widget.justAudioPlayer!.processingState != just_audio.ProcessingState.idle) {
          widget.justAudioPlayer!.play();
        } else {
          widget.audioPlayer.resume();
        }
      }
      
      setState(() {
        _isPlaying = !_isPlaying;
      });
    }
  }

  void _seekTo(Duration position) {
    // Check if max value is valid to prevent errors
    if (_songDuration.inSeconds <= 0) return;
    
    // Update UI immediately
    setState(() {
      _currentPosition = position;
    });
    
    // Apply to both players to ensure at least one works
    widget.justAudioPlayer?.seek(position);
    widget.audioPlayer.seek(position);
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.playlist_add, color: Colors.white),
              title: Text('Add to playlist', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Add to playlist functionality
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.white),
              title: Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Share functionality
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: Colors.white),
              title: Text('Download', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Download functionality
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}