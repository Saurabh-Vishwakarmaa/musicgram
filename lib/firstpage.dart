import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class Firstpage extends StatefulWidget {
  const Firstpage({super.key});

  @override
  State<Firstpage> createState() => _FirstpageState();
}

class _FirstpageState extends State<Firstpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green, // Start color
              Colors.green, // End color
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: LottieBuilder.network(
                "https://lottie.host/31d5e76b-82f0-4c84-aeb6-e1f2c05577a6/liD4TQwfmH.json",
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Text(
                'Connect',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                    wordSpacing: 1.1,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3.0, left: 20.0, right: 20.0),
              child: Text(
                ' Share, and Celebrate Music Together!',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                   wordSpacing: 1.1,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20), // Add some spacing at the bottom
          ],
        ),
      ),
    );
  }
}
