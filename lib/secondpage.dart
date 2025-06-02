import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:musicgram4/authpages/registerpage.dart';


class Secondpage extends StatefulWidget {
  const Secondpage({super.key});

  @override
  State<Secondpage> createState() => _SecondpageState();
}

class _SecondpageState extends State<Secondpage> {
  @override
  
  Widget build(BuildContext context) {
  

    return Scaffold(
   
      body: Column(
        
      children: [
        Container(
          height: 752,
          width: 500,
           decoration: BoxDecoration(
        color:  Colors.orange
        ),
        child: Column(
          children: [
            Container(
              height: 200,
              width: 500,
              color:   Colors.orange,

            ),
          GestureDetector(
            onTap: ()=>{
             Navigator.push(context, MaterialPageRoute(builder: (context)=>SignupPage()))  
            },
            child: LottieBuilder.network('https://lottie.host/98ad2444-7c6f-4248-96a2-3f93da39b278/ptZLBoUhWp.json')),
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text("Let's Dive into the world of music",  style: GoogleFonts.firaSansCondensed(
               
                fontWeight: FontWeight.bold,
                fontSize: 40,
              ),),
            )
          ],
        ),

        )
      ],
     ),
    );
  }
}
