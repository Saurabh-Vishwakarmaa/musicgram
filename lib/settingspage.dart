import 'package:flutter/material.dart';
import 'package:musicgram4/pageesviews.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Settingspage extends StatefulWidget {
  const Settingspage({super.key});

  @override
  State<Settingspage> createState() => _SettingspageState();
}

class _SettingspageState extends State<Settingspage> {
  // Settings variables
  bool _darkMode = true;
  bool _autoPlay = true;
  bool _streamingOnly = false;
  bool _savePlaybackPosition = true;
  bool _enableEqualizer = false;
  String _audioQuality = "High";
  double _cacheSize = 0.0;
  int _totalListeningTime = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _calculateCacheSize();
    _loadListeningTime();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? true;
      _autoPlay = prefs.getBool('autoPlay') ?? true;
      _streamingOnly = prefs.getBool('streamingOnly') ?? false;
      _savePlaybackPosition = prefs.getBool('savePlaybackPosition') ?? true;
      _enableEqualizer = prefs.getBool('enableEqualizer') ?? false;
      _audioQuality = prefs.getString('audioQuality') ?? "High";
    });
  }

  Future<void> _loadListeningTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalListeningTime = prefs.getInt('listening_time') ?? 0;
    });
  }

  Future<void> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      int totalSize = 0;
      
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      // Convert to MB
      setState(() {
        _cacheSize = totalSize / (1024 * 1024);
      });
    } catch (e) {
      print('Error calculating cache size: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      await dir.delete(recursive: true);
      await dir.create();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cache cleared successfully'))
      );
      
      setState(() {
        _cacheSize = 0.0;
      });
    } catch (e) {
      print('Error clearing cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear cache: $e'))
      );
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Pageesviews()),
    );
  }

  Widget _buildSettingSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title, style: TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.greenAccent,
      ),
    );
  }

  Widget _buildSettingDropdown(String title, String subtitle, String value, List<String> options, Function(String?) onChanged) {
    return ListTile(
      title: Text(title, style: TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option, style: TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: Colors.grey[900],
          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
          underline: SizedBox(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Colors.grey[900],
      ),
      backgroundColor: Colors.black,
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader("Account"),
          ListTile(
            leading: CircleAvatar(
              backgroundImage: AssetImage('assets/default_avatar.png'),
              backgroundColor: Colors.grey[800],
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text("Your Account", style: TextStyle(color: Colors.white)),
            subtitle: Text("Manage your account details", style: TextStyle(color: Colors.white70)),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            onTap: () {
              // Navigate to account details
            },
          ),
          Divider(color: Colors.grey[800]),

          // Playback settings
          _buildSectionHeader("Playback"),
          _buildSettingSwitch(
            "Autoplay", 
            "Automatically play next song when current one ends",
            _autoPlay,
            (value) {
              setState(() {
                _autoPlay = value;
                _saveSetting('autoPlay', value);
              });
            }
          ),
          _buildSettingSwitch(
            "Save position",
            "Remember where you left off in each song",
            _savePlaybackPosition,
            (value) {
              setState(() {
                _savePlaybackPosition = value;
                _saveSetting('savePlaybackPosition', value);
              });
            }
          ),
          _buildSettingSwitch(
            "Enable equalizer",
            "Use audio equalizer for better sound",
            _enableEqualizer,
            (value) {
              setState(() {
                _enableEqualizer = value;
                _saveSetting('enableEqualizer', value);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Equalizer will be available in the next update'))
              );
            }
          ),
          _buildSettingDropdown(
            "Audio quality",
            "Higher quality uses more data",
            _audioQuality,
            ["Low", "Medium", "High", "Very High"],
            (value) {
              if (value != null) {
                setState(() {
                  _audioQuality = value;
                  _saveSetting('audioQuality', value);
                });
              }
            }
          ),
          Divider(color: Colors.grey[800]),

          // Appearance settings
          _buildSectionHeader("Appearance"),
          _buildSettingSwitch(
            "Dark mode",
            "Use dark theme throughout the app",
            _darkMode,
            (value) {
              setState(() {
                _darkMode = value;
                _saveSetting('darkMode', value);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Theme will change when you restart the app'))
              );
            }
          ),
          Divider(color: Colors.grey[800]),

          // Storage settings
          _buildSectionHeader("Storage"),
          _buildSettingSwitch(
            "Streaming only",
            "Don't save songs locally (reduces storage usage)",
            _streamingOnly,
            (value) {
              setState(() {
                _streamingOnly = value;
                _saveSetting('streamingOnly', value);
              });
            }
          ),
          ListTile(
            title: Text("Cache size", style: TextStyle(color: Colors.white)),
            subtitle: Text("${_cacheSize.toStringAsFixed(2)} MB used", style: TextStyle(color: Colors.white70)),
            trailing: TextButton(
              child: Text("CLEAR", style: TextStyle(color: Colors.redAccent)),
              onPressed: _clearCache,
            ),
          ),
          Divider(color: Colors.grey[800]),

          // Stats
          _buildSectionHeader("Statistics"),
          ListTile(
            title: Text("Total listening time", style: TextStyle(color: Colors.white)),
            subtitle: Text("$_totalListeningTime minutes", style: TextStyle(color: Colors.white70)),
          ),
          Divider(color: Colors.grey[800]),

          // About section
          _buildSectionHeader("About"),
          ListTile(
            title: Text("App version", style: TextStyle(color: Colors.white)),
            subtitle: Text("MusicGram 1.0.0", style: TextStyle(color: Colors.white70)),
          ),
          ListTile(
            title: Text("Terms of Service", style: TextStyle(color: Colors.white)),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            onTap: () {
              // Open Terms of Service
            },
          ),
          ListTile(
            title: Text("Privacy Policy", style: TextStyle(color: Colors.white)),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            onTap: () {
              // Open Privacy Policy
            },
          ),
          Divider(color: Colors.grey[800]),

          // Logout option
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text("Logout", style: TextStyle(color: Colors.redAccent)),
            onTap: _logout,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}