import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class Fourthpage extends StatefulWidget {
  const Fourthpage({super.key});

  @override
  State<Fourthpage> createState() => _FourthpageState();
}

class _FourthpageState extends State<Fourthpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 251, 62, 56),
               Color.fromARGB(255, 251, 62, 56),
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
                'https://lottie.host/c38b6e41-6a5f-4868-87ca-a27fcfb27521/EOqGtTGdWD.json',
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0, left: 20.0),
              child: Text(
                'Searching for the Music app that don’t get you bored',
                style: GoogleFonts.firaSansCondensed(
                  fontSize:40,
                  fontWeight: FontWeight.bold,
                  wordSpacing: 1.1,
                  letterSpacing: 0.2,
                  color: Colors.black87,
                  
                ),
                
              ),
            ),
          ],
        ),
      ),
    );
  }
}
