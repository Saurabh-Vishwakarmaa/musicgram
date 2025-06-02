// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class MusicgramDashboard extends StatefulWidget {
//   const MusicgramDashboard({super.key});

//   @override
//   State<MusicgramDashboard> createState() => _MusicgramDashboardState();
// }

// class _MusicgramDashboardState extends State<MusicgramDashboard> {
//   List<Map<String, dynamic>> recentlyPlayed = [];
//   String userName = "";

// @override

//  void initState() {
//     super.initState();
//     fetchRecentlyPlayed();
//     fetchUserName();
//   }

//   Future<void> fetchRecentlyPlayed() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String>? songs = prefs.getStringList('recentlyPlayed');
//     if (songs != null){
//       setState(() {
//         recentlyPlayed = songs.map((song) => {'title':song}).toList();
//       });
//     }
//   }

//   Future<void> fetchUserName() async {
//     User? user = FirebaseAuth.instance.currentUser;
//     if(user ! = null){
      
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     // TODO: implement build
//     throw UnimplementedError();
//   }
 
// }