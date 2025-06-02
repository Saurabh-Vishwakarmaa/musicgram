import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class Fifthpage extends StatefulWidget {
  const Fifthpage({super.key});

  @override
  State<Fifthpage> createState() => _FifthpageState();
}

class _FifthpageState extends State<Fifthpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 251, 62, 56), // Background color
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 752,
              width: 500,
          
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                  ),
                  LottieBuilder.network(
                    'https://lottie.host/d327269e-de29-4bd1-b452-64cc462ac9de/OtSPKgvqzu.json',
                    fit: BoxFit.cover,
                  ),
                   Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10.0),
              child: Text(
                'Be Part of the Vibe',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Text color
                ),
                textAlign: TextAlign.center,
              ),
            ),
             Padding(
              padding: const EdgeInsets.only(top: 3.0, left: 20.0,),
              child: Text(
                ' Like',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                   wordSpacing: 1.1,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
              Padding(
              padding: const EdgeInsets.only(top: 3.0, left: 20.0,),
              child: Text(
                ' Follow',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                   wordSpacing: 1.1,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
              Padding(
              padding: const EdgeInsets.only(top: 3.0, left: 20.0),
              child: Text(
                ' Share',
                style: GoogleFonts.firaSansCondensed(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                   wordSpacing: 1.1,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
                ],
              ),
            ),
           
            // Add some spacing at the bottom
          ],
        ),
      ),
    );
  }
}
