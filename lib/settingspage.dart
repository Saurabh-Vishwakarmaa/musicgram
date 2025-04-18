import 'package:flutter/material.dart';
import 'package:musicgram4/pageesviews.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settingspage extends StatefulWidget {
  const Settingspage({super.key});

  @override
  State<Settingspage> createState() => _SettingspageState();
}

class _SettingspageState extends State<Settingspage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SizedBox(
            height: 100,
          ),
          Row(
            children: [
              SizedBox( width: 40,),
              GestureDetector(
                onTap: () async{
  final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Clear login state

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Pageesviews()),
    );
                },
                child: Icon(Icons.logout ,
                color: Colors.white,),
              ),
               SizedBox( width: 40,),
              Text("Logout",style: TextStyle(
                color: Colors.white,
                fontSize: 15,

              ),),
               SizedBox( width: 40,),
            ],
          )
          
        ],
      ),
    );
  }
}