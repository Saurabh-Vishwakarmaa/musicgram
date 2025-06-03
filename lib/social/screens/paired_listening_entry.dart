import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/services/appwrite_service.dart' as service;
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:musicgram4/social/models/paired_session.dart';
import 'package:musicgram4/social/screens/paired_listening.dart';

class PairedListeningEntryScreen extends StatelessWidget {
  const PairedListeningEntryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Paired Listening',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header image
              Icon(
                Icons.headphones_rounded,
                size: 100,
                color: Colors.greenAccent,
              ),
              
              SizedBox(height: 32),
              
              Text(
                'Listen Together',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              SizedBox(height: 16),
              
              Text(
                'Create a room or join an existing one to sync music with friends',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              
              SizedBox(height: 64),
              
              // Create Room Button
              ElevatedButton.icon(
                icon: Icon(Icons.add_circle_outline),
                label: Text('Create New Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.firaSansCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PairedListeningScreen(),
                    ),
                  );
                },
              ),
              
              SizedBox(height: 16),
              
              // Join Room Button
              ElevatedButton.icon(
                icon: Icon(Icons.login),
                label: Text('Join with Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.firaSansCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  _showJoinByCodeDialog(context);
                },
              ),
            ],
          ),
        ),
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
          title: Text(
            'Join Listening Session',
            style: GoogleFonts.firaSansCondensed(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the 6-digit code provided by the host:',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),
              TextField(
                controller: codeController,
                style: TextStyle(color: Colors.white, letterSpacing: 8),
                decoration: InputDecoration(
                  fillColor: Colors.grey[800],
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(color: Colors.grey[600], letterSpacing: 8),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
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
                      databases: service.AppwriteService.databases,
                      storage: service.AppwriteService.storage,
                      account: service.AppwriteService.account,
                    );
                    
                    // Only search by session_name since that's what we're using
                    final sessions = await socialService.listDocuments(
                      collectionId: 'paired_sessions',
                      queries: [
                        Query.equal('session_name', codeController.text.toUpperCase()),
                        Query.equal('status', SessionStatus.waiting.value),
                      ],
                    );
                    
                    if (sessions.documents.isNotEmpty) {
                      sessionId = sessions.documents.first.$id;
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid code or session no longer available'))
                      );
                    }
                  } catch (e) {
                    print('Error finding session: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error joining session: $e'))
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid 6-digit code'))
                  );
                }
              },
            ),
          ],
        );
      },
    );
    
    // If we found a session, navigate to it
    if (sessionId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PairedListeningScreen(sessionId: sessionId),
        ),
      );
    }
  }
}