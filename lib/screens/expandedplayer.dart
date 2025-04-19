import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:musicgram4/services/audio_player_service.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'homie.dart';

class ExpandedMusicPlayer extends StatefulWidget {
  final Album album;
  final AudioPlayerService audioService;
  final VoidCallback? onNextSong;
  final VoidCallback? onPreviousSong;
  final VoidCallback? onTogglePlayPause;
  final bool isPlaying;

  ExpandedMusicPlayer({
    required this.album,
    required this.audioService,
    this.onNextSong,
    this.onPreviousSong,
    this.onTogglePlayPause,
    this.isPlaying = false,
  });

  @override
  _ExpandedMusicPlayerState createState() => _ExpandedMusicPlayerState();
}

class _ExpandedMusicPlayerState extends State<ExpandedMusicPlayer> with SingleTickerProviderStateMixin {
  // State variables
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _songDuration = Duration.zero;
  bool _showLyrics = false;
  bool _showVisualizer = false;
  bool _motionControlEnabled = false;
  int _currentVisualizerMode = 0;
  double _volume = 1.0;
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  
  // Audio visualization data
  List<double> _visualizerData = List.generate(30, (_) => 0);
  Timer? _visualizerTimer;
  
  // Animation controllers
  late AnimationController _animationController;
  late StreamSubscription _accelerometerSubscription;
  
  // Mock lyrics for demo
  final List<Map<String, dynamic>> _lyrics = [

  ];
  String _currentLyricLine = "";
  
  // For motion gestures
  double _tiltThreshold = 10.0;
  
  // Subscription variables
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playingSubscription;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    
    // Get initial state from parent
    _isPlaying = widget.isPlaying;
    if (_isPlaying) {
      _animationController.forward();
      _startVisualizer();
    }
    
    // Get current volume
    _volume = widget.audioService.volume;
    
    // Set up position listener
    _positionSubscription = widget.audioService.player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _updateCurrentLyric();
        });
      }
    });
    
    // Set up duration listener
    _durationSubscription = widget.audioService.player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _songDuration = duration;
        });
      }
    });
    
    // Set up playing state listener
    _playingSubscription = widget.audioService.player.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing) {
            _animationController.forward();
            _startVisualizer();
          } else {
            _animationController.reverse();
            _stopVisualizer();
          }
        });
      }
    });
    
    // Setup motion controls (disabled by default)
    _setupMotionControls();
  }

  void _setupMotionControls() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      if (!_motionControlEnabled || !mounted) return;
      
      // Detect left/right tilt for previous/next song
      if (event.y.abs() > _tiltThreshold) {
        if (event.y > 0 && widget.onPreviousSong != null) {
          widget.onPreviousSong!();
          // Disable temporarily to prevent multiple triggers
          _motionControlEnabled = false;
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) setState(() => _motionControlEnabled = true);
          });
        } else if (event.y < 0 && widget.onNextSong != null) {
          widget.onNextSong!();
          _motionControlEnabled = false;
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) setState(() => _motionControlEnabled = true);
          });
        }
      }
      
      // Detect up/down tilt for volume control
      if (event.x.abs() > _tiltThreshold) {
        double newVolume = _volume;
        if (event.x > 0) {
          newVolume = (_volume - 0.05).clamp(0.0, 1.0);
        } else {
          newVolume = (_volume + 0.05).clamp(0.0, 1.0);
        }
        
        if (newVolume != _volume) {
          setState(() => _volume = newVolume);
          widget.audioService.setVolume(_volume);
        }
      }
    });
  }

  void _startVisualizer() {
    _visualizerTimer?.cancel();
    _visualizerTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!_isPlaying || !mounted) return;
      
      setState(() {
        for (int i = 0; i < _visualizerData.length; i++) {
          if (_isPlaying) {
            _visualizerData[i] = math.Random().nextDouble() * 0.8 + 0.2;
          } else {
            _visualizerData[i] = 0;
          }
        }
      });
    });
  }

  void _stopVisualizer() {
    _visualizerTimer?.cancel();
    if (mounted) {
      setState(() {
        for (int i = 0; i < _visualizerData.length; i++) {
          _visualizerData[i] = 0;
        }
      });
    }
  }

  void _updateCurrentLyric() {
    String lyricLine = "";
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (_currentPosition.inSeconds >= _lyrics[i]["time"]) {
        lyricLine = _lyrics[i]["text"];
        break;
      }
    }
    
    if (_currentLyricLine != lyricLine) {
      setState(() {
        _currentLyricLine = lyricLine;
      });
    }
  }

  void _toggleVisualizerMode() {
    setState(() {
      _currentVisualizerMode = (_currentVisualizerMode + 1) % 3;
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _visualizerTimer?.cancel();
    _accelerometerSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < -1000) {
            setState(() {
              _showLyrics = true;
              _showVisualizer = false;
            });
          } else if (details.primaryVelocity! > 1000) {
            setState(() {
              _showLyrics = false;
              _showVisualizer = false;
            });
          }
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 1000 && widget.onPreviousSong != null) {
            widget.onPreviousSong!();
          } else if (details.primaryVelocity! < -1000 && widget.onNextSong != null) {
            widget.onNextSong!();
          }
        },
        onDoubleTap: () {
          setState(() {
            _showVisualizer = !_showVisualizer;
            _showLyrics = false;
            if (_showVisualizer) {
              _startVisualizer();
            }
          });
        },
        onLongPress: () => _showSongInfoDialog(),
        child: Stack(
          children: [
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Top app bar with gestures
                  _buildMinimalAppBar(),
                  
                  // Main content area
                  Expanded(
                    child: _showLyrics
                        ? _buildLyricsView()
                        : _showVisualizer
                            ? _buildVisualizer()
                            : _buildAlbumView(),
                  ),
                  
                  // Bottom controls area
                  _buildMinimalControls(),
                ],
              ),
            ),
            
            // Gesture hint (only shows the first few times)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 60,
              child: _showHelpButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30, width: 1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
            ),
          ),
          
          // Motion control toggle
          InkWell(
            onTap: () {
              setState(() {
                _motionControlEnabled = !_motionControlEnabled;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _motionControlEnabled
                        ? "Motion controls: ON"
                        : "Motion controls: OFF",
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.grey[900],
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _motionControlEnabled ? Colors.white : Colors.white30,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.screen_rotation,
                color: _motionControlEnabled ? Colors.white : Colors.white30,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Album artwork with minimal design
        Hero(
          tag: 'album_image_${widget.album.name}',
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.album.imageUrl ?? 'https://via.placeholder.com/300',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[900],
                        child: Icon(Icons.music_note, size: 80, color: Colors.white24),
                      );
                    },
                  ),
                  // Subtle overlay to enhance text visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                        stops: [0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        SizedBox(height: 40),
        
        // Song information
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              // Song name
              Text(
                widget.album.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(duration: 600.ms).slide(begin: Offset(0, 0.1), end: Offset.zero),
              
              SizedBox(height: 8),
              
              // Artist name
              Text(
                'Artist Name',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slide(begin: Offset(0, 0.1), end: Offset.zero),
              
              // Lyrics preview
              if (_currentLyricLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10, width: 1),
                    ),
                    child: Text(
                      _currentLyricLine,
                      style: TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "LYRICS",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
            Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                itemCount: _lyrics.length,
                itemBuilder: (context, index) {
                  final lyric = _lyrics[index];
                  final bool isCurrentLyric =
                      _currentPosition.inSeconds >= lyric["time"] &&
                      (index == _lyrics.length - 1 ||
                       _currentPosition.inSeconds < _lyrics[index + 1]["time"]);
                  
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      lyric["text"],
                      style: TextStyle(
                        color: isCurrentLyric ? Colors.white : Colors.white60,
                        fontSize: isCurrentLyric ? 16 : 14,
                        fontWeight: isCurrentLyric ? FontWeight.w600 : FontWeight.normal,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizer() {
    switch (_currentVisualizerMode) {
      case 0:
        return _buildMinimalBarVisualizer();
      case 1:
        return _buildMinimalCircleVisualizer();
      case 2:
        return _buildMinimalWaveVisualizer();
      default:
        return _buildMinimalBarVisualizer();
    }
  }

  Widget _buildMinimalBarVisualizer() {
    return GestureDetector(
      onTap: _toggleVisualizerMode,
      child: Container(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "VISUALIZER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 40),
            Container(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_visualizerData.length, (index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 60),
                    width: 4,
                    height: 20 + _visualizerData[index] * 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7 + _visualizerData[index] * 0.3),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: 40),
            Text(
              "Tap to change style",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalCircleVisualizer() {
    return GestureDetector(
      onTap: _toggleVisualizerMode,
      child: Container(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "CIRCLE VISUALIZER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 40),
            Container(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: MinimalCircleVisualizer(
                  data: _visualizerData,
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: Colors.white24, width: 1),
                      image: widget.album.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.album.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.album.imageUrl == null
                        ? Icon(Icons.music_note, color: Colors.white24, size: 40)
                        : null,
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
            Text(
              "Tap to change style",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalWaveVisualizer() {
    return GestureDetector(
      onTap: _toggleVisualizerMode,
      child: Container(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "WAVE VISUALIZER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 40),
            Container(
              width: double.infinity,
              height: 200,
              child: CustomPaint(
                painter: MinimalWaveVisualizer(
                  data: _visualizerData,
                ),
              ),
            ),
            SizedBox(height: 40),
            Text(
              "Tap to change style",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalControls() {
    double progress = 0;
    if (_songDuration.inMilliseconds > 0) {
      progress = _currentPosition.inMilliseconds / _songDuration.inMilliseconds;
    }
    progress = progress.clamp(0.0, 1.0);

    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(bottom: 30, top: 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _formatDuration(_songDuration),
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          
          // Minimal progress bar
          Container(
            margin: EdgeInsets.fromLTRB(30, 8, 30, 20),
            height: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Background track
                    Container(
                      width: constraints.maxWidth,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    // Progress indicator
                    GestureDetector(
                      onHorizontalDragStart: (details) {
                        if (_isPlaying) {
                          widget.audioService.pause();
                        }
                      },
                      onHorizontalDragUpdate: (details) {
                        final RenderBox renderBox = context.findRenderObject() as RenderBox;
                        final position = renderBox.globalToLocal(details.globalPosition);
                        final percentage = (position.dx - 30) / (constraints.maxWidth);
                        if (percentage >= 0 && percentage <= 1.0) {
                          final newPosition = Duration(
                            milliseconds: (percentage * _songDuration.inMilliseconds).round()
                          );
                          setState(() {
                            _currentPosition = newPosition;
                          });
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        _seekTo(_currentPosition);
                        if (_isPlaying) {
                          widget.audioService.play();
                        }
                      },
                      onTapDown: (details) {
                        final RenderBox renderBox = context.findRenderObject() as RenderBox;
                        final position = renderBox.globalToLocal(details.globalPosition);
                        final percentage = (position.dx - 30) / (constraints.maxWidth);
                        if (percentage >= 0 && percentage <= 1.0) {
                          final newPosition = Duration(
                            milliseconds: (percentage * _songDuration.inMilliseconds).round()
                          );
                          _seekTo(newPosition);
                        }
                      },
                      child: Container(
                        width: progress * constraints.maxWidth,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                    // Drag handle
                    Positioned(
                      left: (progress * constraints.maxWidth) - 6,
                      top: -4.5,
                      child: GestureDetector(
                        onHorizontalDragStart: (details) {
                          if (_isPlaying) {
                            widget.audioService.pause();
                          }
                        },
                        onHorizontalDragUpdate: (details) {
                          final RenderBox renderBox = context.findRenderObject() as RenderBox;
                          final position = renderBox.globalToLocal(details.globalPosition);
                          final percentage = (position.dx - 30) / (constraints.maxWidth);
                          if (percentage >= 0 && percentage <= 1.0) {
                            final newPosition = Duration(
                              milliseconds: (percentage * _songDuration.inMilliseconds).round()
                            );
                            setState(() {
                              _currentPosition = newPosition;
                            });
                          }
                        },
                        onHorizontalDragEnd: (details) {
                          _seekTo(_currentPosition);
                          if (_isPlaying) {
                            widget.audioService.play();
                          }
                        },
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 3,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shuffle button
              IconButton(
                icon: Icon(
                  _isShuffleEnabled ? Icons.shuffle : Icons.shuffle,
                  color: _isShuffleEnabled ? Colors.white : Colors.white38,
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _isShuffleEnabled = !_isShuffleEnabled;
                  });
                  // Implement shuffle
                },
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              
              SizedBox(width: 10),
              
              // Previous button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.skip_previous, color: Colors.white, size: 30),
                  onPressed: widget.onPreviousSong,
                ),
              ),
              
              SizedBox(width: 20),
              
              // Play/pause button
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
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
              
              SizedBox(width: 20),
              
              // Next button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.skip_next, color: Colors.white, size: 30),
                  onPressed: widget.onNextSong,
                ),
              ),
              
              SizedBox(width: 10),
              
              // Repeat button
              IconButton(
                icon: Icon(
                  _isRepeatEnabled ? Icons.repeat_one : Icons.repeat,
                  color: _isRepeatEnabled ? Colors.white : Colors.white38,
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _isRepeatEnabled = !_isRepeatEnabled;
                  });
                  // Implement repeat
                },
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          
          // Extra controls for lyrics and visualizer
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMinimalIconButton(
                  icon: _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
                  isActive: _showLyrics,
                  onTap: () {
                    setState(() {
                      _showLyrics = !_showLyrics;
                      _showVisualizer = false;
                    });
                  },
                ),
                SizedBox(width: 30),
                _buildMinimalIconButton(
                  icon: _showVisualizer ? Icons.graphic_eq : Icons.graphic_eq_outlined,
                  isActive: _showVisualizer,
                  onTap: () {
                    setState(() {
                      _showVisualizer = !_showVisualizer;
                      _showLyrics = false;
                      if (_showVisualizer) {
                        _startVisualizer();
                      }
                    });
                  },
                ),
                SizedBox(width: 30),
                _buildMinimalIconButton(
                  icon: Icons.favorite_border,
                  isActive: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Added to favorites"),
                        backgroundColor: Colors.grey[900],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalIconButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isActive ? Colors.white : Colors.white24,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white60,
          size: 20,
        ),
      ),
    );
  }

  Widget _showHelpButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: InkWell(
        onTap: _showGestureGuide,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, color: Colors.white60, size: 16),
            SizedBox(width: 6),
            Text(
              "GESTURES",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGestureGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Gesture Controls",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _gestureItem(Icons.swipe, "Swipe up for lyrics"),
            _gestureItem(Icons.swipe, "Swipe left/right for previous/next track"),
            _gestureItem(Icons.touch_app, "Double tap for visualizer"),
            _gestureItem(Icons.touch_app_outlined, "Long press for song info"),
            _gestureItem(Icons.screen_rotation, "Tilt phone (when enabled) to control playback"),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              "Got it",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _gestureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    if (widget.onTogglePlayPause != null) {
      widget.onTogglePlayPause!();
    } else {
      if (_isPlaying) {
        widget.audioService.pause();
      } else {
        widget.audioService.play();
      }
    }
  }

  void _seekTo(Duration position) {
    if (_songDuration.inSeconds <= 0) return;
    
    setState(() {
      _currentPosition = position;
    });
    
    widget.audioService.seek(position);
  }

  void _showSongInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Song Information", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow("Title", widget.album.name),
            _infoRow("Artist", "Artist Name"),
            _infoRow("Album", "Album Name"),
            _infoRow("Duration", _formatDuration(_songDuration)),
            _infoRow("Release", "Unknown"),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Close", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

// Visualizer painters
class MinimalCircleVisualizer extends CustomPainter {
  final List<double> data;
  
  MinimalCircleVisualizer({required this.data});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw multiple circles
    for (int i = 0; i < 3; i++) {
      final double baseRadius = radius * (0.5 + (i * 0.15));
      final path = Path();
      
      for (int j = 0; j < data.length; j++) {
        final double angle = (j / data.length) * 2 * math.pi;
        final double r = baseRadius * (0.9 + data[j] * 0.2);
        final double x = center.dx + r * math.cos(angle);
        final double y = center.dy + r * math.sin(angle);
        
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      path.close();
      canvas.drawPath(path, paint..color = Colors.white.withOpacity(0.2 + (i * 0.2)));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MinimalWaveVisualizer extends CustomPainter {
  final List<double> data;
  
  MinimalWaveVisualizer({required this.data});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final path = Path();
    final width = size.width;
    final height = size.height;
    final segmentWidth = width / (data.length - 1);
    
    path.moveTo(0, height / 2);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * segmentWidth;
      final y = height / 2 + (data[i] - 0.5) * height * 0.7;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Use quadratic bezier for smoother curves
        final prevX = (i - 1) * segmentWidth;
        final prevY = height / 2 + (data[i - 1] - 0.5) * height * 0.7;
        final cpX = (x + prevX) / 2;
        final cpY = prevY;
        
        path.quadraticBezierTo(cpX, cpY, x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw bottom wave (mirrored)
    final bottomPath = Path();
    bottomPath.moveTo(0, height / 2);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * segmentWidth;
      final y = height / 2 - (data[i] - 0.5) * height * 0.7;
      
      if (i == 0) {
        bottomPath.moveTo(x, y);
      } else {
        // Use quadratic bezier for smoother curves
        final prevX = (i - 1) * segmentWidth;
        final prevY = height / 2 - (data[i - 1] - 0.5) * height * 0.7;
        final cpX = (x + prevX) / 2;
        final cpY = prevY;
        
        bottomPath.quadraticBezierTo(cpX, cpY, x, y);
      }
    }
    
    canvas.drawPath(bottomPath, paint..color = Colors.white.withOpacity(0.5));
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}