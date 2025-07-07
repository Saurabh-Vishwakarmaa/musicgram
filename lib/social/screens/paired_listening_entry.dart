import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/services/appwrite_service.dart' as service;
import 'package:musicgram4/main.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:musicgram4/social/models/paired_session.dart';
import 'package:musicgram4/social/screens/paired_listening.dart';
import 'dart:math';

class PairedListeningEntryScreen extends StatelessWidget {
  const PairedListeningEntryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Paired Listening',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.greenAccent),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              
              // Header Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.greenAccent, Colors.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  size: 60,
                  color: Colors.black,
                ),
              ),
              
              SizedBox(height: 32),
              
              // Title
              Text(
                'Listen Together',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              SizedBox(height: 16),
              
              // Subtitle
              Text(
                'Share music experiences with friends\nJoin a room or create your own',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
              
              SizedBox(height: 60),
              
              // Create Room Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.greenAccent, Colors.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.add_circle_outline, color: Colors.black),
                  label: Text(
                    'Create New Room',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => _createRoom(context),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Join Room Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.login, color: Colors.greenAccent),
                  label: Text(
                    'Join with Code',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => _showJoinByCodeDialog(context),
                ),
              ),
              
              SizedBox(height: 40),
              
              // Features Section
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Features',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: Icons.sync,
                      title: 'Song Sharing',
                      subtitle: 'Share your favorite songs with friends',
                    ),
                    _buildFeatureItem(
                      icon: Icons.music_note,
                      title: 'Individual Control',
                      subtitle: 'Each person can play their own music',
                    ),
                    _buildFeatureItem(
                      icon: Icons.visibility,
                      title: 'Activity Sharing',
                      subtitle: 'See what your friends are listening to',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.greenAccent,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _createRoom(BuildContext context) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.greenAccent),
                SizedBox(height: 16),
                Text(
                  'Creating room...',
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
      
      final socialService = SocialDatabaseService(
        databases: databases,
        storage: storage,
        account: account,
      );
      
      // Generate random session code
      final sessionCode = _generateRandomCode();
      
      // Get current user
      final userAccount = await service.AppwriteService.account.get();
      
      // Create session with ALL required attributes based on your schema
      final session = await socialService.createDocument(
        collectionId: 'paired_sessions',
        data: {
          // Required attributes
          'host_user_id': userAccount.$id,
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
          'is_playing': false,
          'host_username': userAccount.name,
          'last_sync_time': DateTime.now().toIso8601String(),
          
          // Optional attributes (can be null)
          'guest_user_id': null,
          'song_id': null,
          'ended_at': null,
          'current_position': 0,
          'playbackPosition': 0.0,
          'guest_username': null,
          'host_avatar_id': null,
          'current_song_name': null,
          'current_artist_name': null,
          'album_art_url': null,
          'session_name': sessionCode,
          'chat_enabled': true,
        },
      );
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show success dialog with code
      _showRoomCreatedDialog(context, sessionCode, session.$id);
      
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print('Error creating room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating room: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRoomCreatedDialog(BuildContext context, String code, String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'Room Created!',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this code with your friends:',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: GoogleFonts.poppins(
                      color: Colors.greenAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.copy, color: Colors.greenAccent),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Code copied to clipboard'),
                          backgroundColor: Colors.greenAccent,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Later', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: Text('Start Session'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PairedListeningScreen(
                    sessionId: sessionId,
                    isHost: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showJoinByCodeDialog(BuildContext context) async {
    final codeController = TextEditingController();
    String? sessionId;
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.login, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text(
                'Join Room',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the 6-digit code provided by the host:',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: TextField(
                  controller: codeController,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    letterSpacing: 8,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'XXXXXX',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      letterSpacing: 8,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Z0-9]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              child: Text('Join'),
              onPressed: () async {
                if (codeController.text.length == 6) {
                  try {
                    final socialService = SocialDatabaseService(
                      databases: databases,
                      storage: storage,
                      account: account,
                    );
                    
                    final sessions = await socialService.listDocuments(
                      collectionId: 'paired_sessions',
                      queries: [
                        Query.equal('session_name', codeController.text.toUpperCase()),
                        Query.equal('status', 'active'),
                      ],
                    );
                    
                    if (sessions.documents.isNotEmpty) {
                      final session = sessions.documents.first;
                      
                      // Get current user
                      final userAccount = await service.AppwriteService.account.get();
                      
                      // Update session with guest info
                      await socialService.updateDocument(
                        collectionId: 'paired_sessions',
                        documentId: session.$id,
                        data: {
                          'guest_user_id': userAccount.$id,
                          'guest_username': userAccount.name,
                          'last_sync_time': DateTime.now().toIso8601String(),
                        },
                      );
                      
                      sessionId = session.$id;
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invalid code or session no longer available'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    print('Error finding session: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error joining session: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid 6-digit code'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
    
    if (sessionId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PairedListeningScreen(
            sessionId: sessionId!,
            isHost: false,
          ),
        ),
      );
    }
  }

  String _generateRandomCode() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code = '';
    
    for (int i = 0; i < 6; i++) {
      code += characters[random.nextInt(characters.length)];
    }
    
    return code;
  }
}