import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class Thirdpage extends StatefulWidget {
  const Thirdpage({super.key});

  @override
  State<Thirdpage> createState() => _ThirdpageState();
}

class _ThirdpageState extends State<Thirdpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
      children: [
        Container(
          height: 752,
          width: 500,
 decoration: BoxDecoration(
  color: Colors.green,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 150,
            ),
            LottieBuilder.network('https://lottie.host/c7d5730f-bccd-4fcb-acd1-210050a3234a/JPF9vJrfAk.json'),
            Padding( padding: const EdgeInsets.only(left: 10.0),
              child: Text("Earn Exciting Rewards", style: GoogleFonts.firaSansCondensed(
                fontWeight: FontWeight.bold,
                fontSize: 44,
              ),
               textAlign: TextAlign.center,
              ),
            )
          ],
        ),
      
        )
      ],
     ),
    );
  }
}