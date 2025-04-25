// // // TAKE 2

// // import 'package:flutter/material.dart';
// // import 'package:firebase_storage/firebase_storage.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'dart:convert';


// // const String pixelFont = 'PressStart2P';


// // class HomePage extends StatefulWidget {
// //   final Function(Album) onPlaySong;

// //   HomePage({required this.onPlaySong});

// //   @override
// //   _HomePageState createState() => _HomePageState();
// // }

// // class _HomePageState extends State<HomePage> {
// //   List<Album> albums = [];
// //   Set<Album> _recentlyPlayed = {};
// //   static const int _maxRecentlyPlayed = 5;

// //   @override
// //   void initState() {
// //     super.initState();
// //     fetchSongsFromFirebase();
// //     loadRecentlyPlayed();
// //   }

// //   Future<void> fetchSongsFromFirebase() async {
// //     final storageRef = FirebaseStorage.instance.ref().child('music');
// //     final ListResult result = await storageRef.listAll();

// //     final List<Album> fetchedAlbums = await Future.wait(result.items.map((item) async {
// //       String downloadUrl = await item.getDownloadURL();
// //       String name = item.name.replaceAll('.mp3', '');
      
// //       return Album(name, downloadUrl);
// //     }).toList());

// //     setState(() {
// //       albums = fetchedAlbums;
// //     });
// //   }

// //   Future<void> loadRecentlyPlayed() async {
// //     SharedPreferences prefs = await SharedPreferences.getInstance();
// //     List<String> recentlyPlayedJson = prefs.getStringList('recently_played') ?? [];
// //     setState(() {
// //       _recentlyPlayed = recentlyPlayedJson
// //           .map((json) => Album.fromJson(jsonDecode(json)))
// //           .toSet();
// //     });
// //   }

// //   Future<void> saveRecentlyPlayed() async {
// //     SharedPreferences prefs = await SharedPreferences.getInstance();
// //     List<String> recentlyPlayedJson = _recentlyPlayed
// //         .map((album) => jsonEncode(album.toJson()))
// //         .toList();
// //     await prefs.setStringList('recently_played', recentlyPlayedJson);
// //   }

// //   void addToRecentlyPlayed(Album album) {
// //     setState(() {
// //       _recentlyPlayed = {album, ..._recentlyPlayed}.take(_maxRecentlyPlayed).toSet();
// //     });
// //     saveRecentlyPlayed();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       body: CustomScrollView(
// //         slivers: <Widget>[
// //           SliverAppBar(
// //             backgroundColor: Colors.red,
// //             expandedHeight: 120.0,
// //             floating: false,
// //             pinned: true,
// //             flexibleSpace: FlexibleSpaceBar(
// //               title: Text(
// //                 'Good morning, User',
// //                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black),
// //               ),
// //               background: Container(
// //                 decoration: BoxDecoration(
// //                   gradient: LinearGradient(
// //                     begin: Alignment.topCenter,
// //                     end: Alignment.bottomCenter,
// //                     colors: [Colors.green, Colors.green.shade800],
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ),
// //           SliverPadding(
// //             padding: EdgeInsets.all(16.0),
// //             sliver: SliverList(
// //               delegate: SliverChildListDelegate([
// //                 Text(
// //                   'Recently played',
// //                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
// //                 ),
// //                 SizedBox(height: 16),
// //                 _buildRecentlyPlayed(),
// //                 SizedBox(height: 32),
// //                 Text(
// //                   'All Songs',
// //                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
// //                 ),
// //                 SizedBox(height: 16),
// //                 _buildAllSongs(),
// //               ]),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildRecentlyPlayed() {
// //     return Container(
// //       height: 200,
// //       child: ListView.builder(
// //         scrollDirection: Axis.horizontal,
// //         itemCount: _recentlyPlayed.length,
// //         itemBuilder: (context, index) {
// //           return _buildRecentlyPlayedItem(_recentlyPlayed.elementAt(index));
// //         },
// //       ),
// //     );
// //   }

// //   Widget _buildRecentlyPlayedItem(Album album) {
// //     return GestureDetector(
// //       onTap: () {
// //         widget.onPlaySong(album);
// //         addToRecentlyPlayed(album);
// //       },
// //       child: Container(
// //         width: 150,
// //         margin: EdgeInsets.only(right: 16),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Container(
// //               width: 150,
// //               height: 150,
// //               decoration: BoxDecoration(
// //                 color: Colors.grey[300],
// //                 borderRadius: BorderRadius.circular(8),
// //               ),
// //               child: Center(
// //                 child: Icon(
// //                   Icons.music_note,
// //                   size: 50,
// //                   color: Colors.black54,
// //                 ),
// //               ),
// //             ),
// //             SizedBox(height: 8),
// //             Text(
// //               album.name,
// //               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
// //               overflow: TextOverflow.ellipsis,
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildAllSongs() {
// //     return ListView.builder(
// //       shrinkWrap: true,
// //       physics: NeverScrollableScrollPhysics(),
// //       itemCount: albums.length,
// //       itemBuilder: (context, index) {
// //         return _buildAlbumItem(albums[index]);
// //       },
// //     );
// //   }

// //   Widget _buildAlbumItem(Album album) {
// //     return GestureDetector(
// //       onTap: () {
// //         widget.onPlaySong(album);
// //         addToRecentlyPlayed(album);
// //       },
// //       child: Container(
// //         margin: EdgeInsets.symmetric(vertical: 8),
// //         child: Row(
// //           children: [
// //             Container(
// //               width: 80,
// //               height: 80,
// //               decoration: BoxDecoration(
// //                 color: Colors.grey[300],
// //                 borderRadius: BorderRadius.circular(8),
// //               ),
// //               child: Center(
// //                 child: Icon(
// //                   Icons.music_note,
// //                   size: 50,
// //                   color: Colors.black54,
// //                 ),
// //               ),
// //             ),
// //             SizedBox(width: 16),
// //             Expanded(
// //               child: Text(
// //                 album.name,
// //                 style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
// //                 overflow: TextOverflow.ellipsis,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // class Album {
// //   final String name;
// //   final String url;

// //   Album(this.name, this.url);

// //   // Add these methods for JSON serialization
// //   Map<String, dynamic> toJson() => {
// //     'name': name,
// //     'url': url,
// //   };

// //   factory Album.fromJson(Map<String, dynamic> json) => Album(
// //     json['name'] as String,
// //     json['url'] as String,
// //   );

// //   @override
// //   bool operator ==(Object other) =>
// //       identical(this, other) ||
// //       other is Album &&
// //           runtimeType == other.runtimeType &&
// //           name == other.name &&
// //           url == other.url;

// //   @override
// //   int get hashCode => name.hashCode ^ url.hashCode;
// // }

// //TAKE 2

// import 'package:flutter/material.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';

// class HomePage extends StatefulWidget {
//   final Function(Album) onPlaySong;

//   HomePage({required this.onPlaySong});

//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   List<Album> albums = [];
//   Set<Album> _recentlyPlayed = {};
//   static const int _maxRecentlyPlayed = 5;

//   @override
//   void initState() {
//     super.initState();
//     fetchSongsFromFirebase();
//     loadRecentlyPlayed();
//   }

//   Future<void> fetchSongsFromFirebase() async {
//     final storageRef = FirebaseStorage.instance.ref().child('music');
//     final ListResult result = await storageRef.listAll();

//     final List<Album> fetchedAlbums = await Future.wait(result.items.map((item) async {
//       String downloadUrl = await item.getDownloadURL();
//       String name = item.name.replaceAll('.mp3', '');
      
//       return Album(name, downloadUrl);
//     }).toList());

//     setState(() {
//       albums = fetchedAlbums;
//     });
//   }

//   Future<void> loadRecentlyPlayed() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> recentlyPlayedJson = prefs.getStringList('recently_played') ?? [];
//     setState(() {
//       _recentlyPlayed = recentlyPlayedJson
//           .map((json) => Album.fromJson(jsonDecode(json)))
//           .toSet();
//     });
//   }

//   Future<void> saveRecentlyPlayed() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> recentlyPlayedJson = _recentlyPlayed
//         .map((album) => jsonEncode(album.toJson()))
//         .toList();
//     await prefs.setStringList('recently_played', recentlyPlayedJson);
//   }

//   void addToRecentlyPlayed(Album album) {
//     setState(() {
//       _recentlyPlayed = {album, ..._recentlyPlayed}.take(_maxRecentlyPlayed).toSet();
//     });
//     saveRecentlyPlayed();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white38,
//       body: CustomScrollView(
//         slivers: <Widget>[
//           SliverAppBar(
//             backgroundColor: Colors.red,
//             expandedHeight: 120.0,
//             floating: false,
//             pinned: true,
//             flexibleSpace: FlexibleSpaceBar(
//               title: Text(
//                 'Good morning, User',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black),
//               ),
//               background: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [Colors.green, Colors.green.shade800],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           SliverPadding(
//             padding: EdgeInsets.all(16.0),
//             sliver: SliverList(
//               delegate: SliverChildListDelegate([
//                 Text(
//                   'Recently Played',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
//                 ),
//                 SizedBox(height: 16),
//                 _buildRecentlyPlayed(),
//                 SizedBox(height: 32),
//                 Text(
//                   'All Songs',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
//                 ),
//                 SizedBox(height: 16),
//                 _buildAllSongs(),
//               ]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRecentlyPlayed() {
//     return Container(
//       height: 200,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: _recentlyPlayed.length,
//         itemBuilder: (context, index) {
//           return _buildRecentlyPlayedItem(_recentlyPlayed.elementAt(index));
//         },
//       ),
//     );
//   }

//   Widget _buildRecentlyPlayedItem(Album album) {
//     return GestureDetector(
//       onTap: () {
//         widget.onPlaySong(album);
//         addToRecentlyPlayed(album);
//       },
//       child: Container(
//         width: 150,
//         margin: EdgeInsets.only(right: 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 150,
//               height: 150,
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Center(
//                 child: Icon(
//                   Icons.music_note,
//                   size: 50,
//                   color: Colors.black54,
//                 ),
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               album.name,
//               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAllSongs() {
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       itemCount: albums.length,
//       itemBuilder: (context, index) {
//         return _buildAlbumItem(albums[index]);
//       },
//     );
//   }

//   Widget _buildAlbumItem(Album album) {
//     return GestureDetector(
//       onTap: () {
//         widget.onPlaySong(album);
//         addToRecentlyPlayed(album);
//       },
//       child: Container(
//         margin: EdgeInsets.symmetric(vertical: 8),
//         child: Row(
//           children: [
//             Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Center(
//                 child: Icon(
//                   Icons.music_note,
//                   size: 50,
//                   color: Colors.black54,
//                 ),
//               ),
//             ),
//             SizedBox(width: 16),
//             Expanded(
//               child: Text(
//                 album.name,
//                 style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class Album {
//   final String name;
//   final String url;

//   Album(this.name, this.url);

//   // Add these methods for JSON serialization
//   Map<String, dynamic> toJson() => {
//     'name': name,
//     'url': url,
//   };

//   factory Album.fromJson(Map<String, dynamic> json) => Album(
//     json['name'] as String,
//     json['url'] as String,
//   );

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is Album &&
//           runtimeType == other.runtimeType &&
//           name == other.name &&
//           url == other.url;

//   @override
//   int get hashCode => name.hashCode ^ url.hashCode;
// }

// //TAKE 3 iske baad ka sab ui game wala h

// import 'package:flutter/material.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import 'package:google_fonts/google_fonts.dart';

// class HomePage extends StatefulWidget {
//   final Function(Album) onPlaySong;

//   HomePage({required this.onPlaySong});

//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   List<Album> albums = [];
//   Set<Album> _recentlyPlayed = {};
//   static const int _maxRecentlyPlayed = 5;

//   @override
//   void initState() {
//     super.initState();
//     fetchSongsFromFirebase();
//     loadRecentlyPlayed();
//   }

//   Future<void> fetchSongsFromFirebase() async {
//     final storageRef = FirebaseStorage.instance.ref().child('music');
//     final ListResult result = await storageRef.listAll();

//     final List<Album> fetchedAlbums = await Future.wait(result.items.map((item) async {
//       String downloadUrl = await item.getDownloadURL();
//       String name = item.name.replaceAll('.mp3', '');
//       return Album(name, downloadUrl);
//     }).toList());

//     setState(() {
//       albums = fetchedAlbums;
//     });
//   }

//   Future<void> loadRecentlyPlayed() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> recentlyPlayedJson = prefs.getStringList('recently_played') ?? [];
//     setState(() {
//       _recentlyPlayed = recentlyPlayedJson
//           .map((json) => Album.fromJson(jsonDecode(json)))
//           .toSet();
//     });
//   }

//   Future<void> saveRecentlyPlayed() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> recentlyPlayedJson = _recentlyPlayed
//         .map((album) => jsonEncode(album.toJson()))
//         .toList();
//     await prefs.setStringList('recently_played', recentlyPlayedJson);
//   }

//   void addToRecentlyPlayed(Album album) {
//     setState(() {
//       _recentlyPlayed = {album, ..._recentlyPlayed}.take(_maxRecentlyPlayed).toSet();
//     });
//     saveRecentlyPlayed();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color.fromARGB(255, 0, 60, 110),
//       body: CustomScrollView(
//         slivers: <Widget>[
//           SliverAppBar(
//             backgroundColor: Colors.black, // Black background for the app bar
//             expandedHeight: 120.0,
//             floating: false,
//             pinned: true,
//             flexibleSpace: FlexibleSpaceBar(
//               title: Text(
//                 'Good morning, User',
//                 style: GoogleFonts.pressStart2p(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.yellow),
//               ),
//               background: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [Colors.blue, Colors.blueAccent], // Blue gradient for the background
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           SliverPadding(
//             padding: EdgeInsets.all(16.0),
//             sliver: SliverList(
//               delegate: SliverChildListDelegate([
//                 Text(
//                   'Recently played',
//                   style: GoogleFonts.pressStart2p(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.yellow),
//                 ),
//                 SizedBox(height: 16),
//                 _buildRecentlyPlayed(),
//                 SizedBox(height: 32),
//                 Text(
//                   'All Songs',
//                   style: GoogleFonts.pressStart2p(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.yellow),
//                 ),
//                 SizedBox(height: 16),
//                 _buildAllSongs(),
//               ]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRecentlyPlayed() {
//     return Container(
//       height: 200,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: _recentlyPlayed.length,
//         itemBuilder: (context, index) {
//           return _buildRecentlyPlayedItem(_recentlyPlayed.elementAt(index));
//         },
//       ),
//     );
//   }

//   Widget _buildRecentlyPlayedItem(Album album) {
//     return GestureDetector(
//       onTap: () {
//         widget.onPlaySong(album);
//         addToRecentlyPlayed(album);
//       },
//       child: Container(
//         width: 150,
//         margin: EdgeInsets.only(right: 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 150,
//               height: 150,
//               decoration: BoxDecoration(
//                 color: Colors.blue, // Blue background for album cover
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Center(
//                 child: Icon(
//                   Icons.music_note,
//                   size: 50,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               album.name,
//               style: GoogleFonts.pressStart2p(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.yellow),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAllSongs() {
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       itemCount: albums.length,
//       itemBuilder: (context, index) {
//         return _buildAlbumItem(albums[index]);
//       },
//     );
//   }

//   Widget _buildAlbumItem(Album album) {
//     return GestureDetector(
//       onTap: () {
//         widget.onPlaySong(album);
//         addToRecentlyPlayed(album);
//       },
//       child: Container(
//         margin: EdgeInsets.symmetric(vertical: 8),
//         child: Row(
//           children: [
//             Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 color: Colors.blue, // Blue background for album cover
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Center(
//                 child: Icon(
//                   Icons.music_note,
//                   size: 50,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//             SizedBox(width: 16),
//             Expanded(
//               child: Text(
//                 album.name,
//                 style: GoogleFonts.pressStart2p(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.yellow),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class Album {
//   final String name;
//   final String url;

//   Album(this.name, this.url);

//   // Add these methods for JSON serialization
//   Map<String, dynamic> toJson() => {
//         'name': name,
//         'url': url,
//       };

//   factory Album.fromJson(Map<String, dynamic> json) => Album(
//         json['name'] as String,
//         json['url'] as String,
//       );

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is Album &&
//           runtimeType == other.runtimeType &&
//           name == other.name &&
//           url == other.url;

//   @override
//   int get hashCode => name.hashCode ^ url.hashCode;
// }


//TAKE 4
// import 'package:flutter/material.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import 'dart:math';
// import 'package:google_fonts/google_fonts.dart';

// class HomePage extends StatefulWidget {
//   final Function(Album) onPlaySong;

//   HomePage({required this.onPlaySong});

//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
//   List<Album> albums = [];
//   Set<Album> _recentlyPlayed = {};
//   static const int _maxRecentlyPlayed = 5;
//   String userName = "User";
//   ScrollController _scrollController = ScrollController();
//   double _scrollOffset = 0;
//   bool _greetingVisible = true;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: Duration(milliseconds: 1000),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
//     );
//     _animationController.forward();

//     fetchSongsFromFirebase();
//     loadRecentlyPlayed();
//     fetchUserName();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   Future<void> fetchUserName() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String email = prefs.getString('user_email') ?? '';
//     setState(() {
//       userName = email.split('@')[0].replaceFirst(email[0], email[0].toUpperCase());
//     });
//   }

//   Future<void> fetchSongsFromFirebase() async {
//     try {
//       final storageRef = FirebaseStorage.instance.ref().child('music');
//       final ListResult result = await storageRef.listAll();

//       final List<Album> fetchedAlbums = await Future.wait(result.items.map((item) async {
//         String downloadUrl = await item.getDownloadURL();
//         String name = item.name.replaceAll('.mp3', '');
//         return Album(name, downloadUrl, await getImageUrl(item.name));
//       }).toList());

//       setState(() {
//         albums = fetchedAlbums;
//       });
//     } catch (e) {
//       print('Error fetching songs: $e');
//     }
//   }

//   Future<String?> getImageUrl(String songName) async {
//     try {
//       final imageRef = FirebaseStorage.instance
//           .ref()
//           .child('images')
//           .child('${songName.replaceAll('.mp3', '')}.jpg');
//       return await imageRef.getDownloadURL();
//     } catch (e) {
//       print('No image found for $songName: $e');
//       return null;
//     }
//   }

//   Future<void> loadRecentlyPlayed() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> recentlyPlayedJson = prefs.getStringList('recently_played') ?? [];
//     setState(() {
//       _recentlyPlayed = recentlyPlayedJson
//           .map((json) => Album.fromJson(jsonDecode(json)))
//           .toSet();
//     });
//   }

//   Future<void> saveRecentlyPlayed() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> recentlyPlayedJson = _recentlyPlayed
//         .map((album) => jsonEncode(album.toJson()))
//         .toList();
//     await prefs.setStringList('recently_played', recentlyPlayedJson);
//   }

//   void addToRecentlyPlayed(Album album) {
//     setState(() {
//       _recentlyPlayed = {album, ..._recentlyPlayed}.take(_maxRecentlyPlayed).toSet();
//     });
//     saveRecentlyPlayed();
//   }

//   String _getGreeting() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return "Good morning, ";
//     if (hour < 18) return "Good afternoon, ";
//     return "Good evening, ";
//   }

//   Widget _buildGreetingBanner() {
//     if (!_greetingVisible) return SizedBox.shrink();

//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: Container(
//         color: Colors.black87,
//         padding: EdgeInsets.all(16),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '${_getGreeting()}$userName',
//                   style: GoogleFonts.poppins(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 24,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Text(
//                   "Let's explore some music!",
//                   style: GoogleFonts.poppins(
//                     fontSize: 16,
//                     color: Colors.white70,
//                   ),
//                 ),
//               ],
//             ),
//             IconButton(
//               icon: Icon(Icons.close, color: Colors.white),
//               onPressed: () {
//                 setState(() {
//                   _greetingVisible = false;
//                 });
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFunctionTiles() {
//     return Column(
//       children: [
//         ListTile(
//           leading: Icon(Icons.playlist_play, color: Colors.white),
//           title: Text(
//             "Playlists",
//             style: GoogleFonts.poppins(color: Colors.white),
//           ),
//           onTap: () {},
//         ),
//         ListTile(
//           leading: Icon(Icons.favorite, color: Colors.redAccent),
//           title: Text(
//             "Favorites",
//             style: GoogleFonts.poppins(color: Colors.white),
//           ),
//           onTap: () {},
//         ),
//         ListTile(
//           leading: Icon(Icons.settings, color: Colors.grey),
//           title: Text(
//             "Settings",
//             style: GoogleFonts.poppins(color: Colors.white),
//           ),
//           onTap: () {},
//         ),
//       ],
//     );
//   }

//   Widget _buildAlbumSlider() {
//     return Container(
//       height: 300,
//       child: PageView.builder(
//         controller: PageController(viewportFraction: 0.8),
//         itemCount: albums.length,
//         itemBuilder: (context, index) {
//           final album = albums[index];
//           return GestureDetector(
//             onTap: () {
//               widget.onPlaySong(album);
//               addToRecentlyPlayed(album);
//             },
//             child: AnimatedContainer(
//               duration: Duration(milliseconds: 500),
//               margin: EdgeInsets.symmetric(horizontal: 10),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Color(0xFF1DB954), Colors.black],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black26,
//                     blurRadius: 10,
//                     offset: Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   ClipRRect(
//                     borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//                     child: Image.network(
//                       album.imageUrl ?? 'https://via.placeholder.com/180',
//                       height: 180,
//                       width: double.infinity,
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Container(
//                           height: 180,
//                           color: Colors.grey[900],
//                           child: Icon(Icons.music_note, color: Colors.white54, size: 48),
//                         );
//                       },
//                     ),
//                   ),
//                   Padding(
//                     padding: EdgeInsets.all(8.0),
//                     child: Text(
//                       album.name,
//                       style: GoogleFonts.poppins(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                         color: Colors.white,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildGreetingBanner(),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Text(
//                 "Home",
//                 style: GoogleFonts.poppins(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 32,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//             Expanded(
//               child: ListView(
//                 controller: _scrollController,
//                 children: [
//                   _buildFunctionTiles(),
//                   SizedBox(height: 16),
//                   Text(
//                     "Recommended Albums",
//                     style: GoogleFonts.poppins(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 24,
//                       color: Colors.white,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   SizedBox(height: 8),
//                   _buildAlbumSlider(),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class Album {
//   final String name;
//   final String downloadUrl;
//   final String? imageUrl;

//   Album(this.name, this.downloadUrl, this.imageUrl);

//   Map<String, dynamic> toJson() => {
//         'name': name,
//         'downloadUrl': downloadUrl,
//         'imageUrl': imageUrl,
//       };

//   static Album fromJson(Map<String, dynamic> json) => Album(
//         json['name'],
//         json['downloadUrl'],
//         json['imageUrl'],
//       );
// }


// the take reborn
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/main.dart'; // Import for global Appwrite instances


class HomePage extends StatefulWidget {
  final Function(Album) onPlaySong;

  HomePage({required this.onPlaySong});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<Album> albums = [];
  Set<Album> _recentlyPlayed = {};
  static const int _maxRecentlyPlayed = 5;
  String userName = "User";
  ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _greetingVisible = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    fetchSongsFromAppwrite();
    loadRecentlyPlayed();
    fetchUserName();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchUserName() async {
    try {
      // Get current user from Appwrite
      final currentUser = await account.get();
      
      // Try to get the user's display name from Appwrite
      String displayName = currentUser.name;
      
      if (displayName.isEmpty) {
        // If no name available, fall back to stored email
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String email = prefs.getString('user_email') ?? '';
        displayName = email.split('@')[0].replaceFirst(
          email.isNotEmpty ? email[0] : '', 
          email.isNotEmpty ? email[0].toUpperCase() : ''
        );
      }
      
      setState(() {
        userName = displayName;
      });
      
      // You can also fetch additional user data from the database if needed
      try {
        final documents = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: 'users',
          queries: [
            Query.equal('user_id', currentUser.$id),
          ],
        );
        
        if (documents.documents.isNotEmpty) {
          // If user profile exists in database, use that name instead
          final userProfile = documents.documents.first;
          if (userProfile.data.containsKey('name') && 
              userProfile.data['name'] != null &&
              userProfile.data['name'].toString().isNotEmpty) {
            setState(() {
              userName = userProfile.data['name'];
            });
          }
        }
      } catch (e) {
        print('Error fetching user profile from database: $e');
        // Continue with the already set userName
      }
    } catch (e) {
      print('Error fetching user data from Appwrite: $e');
      // Fall back to SharedPreferences as before
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String email = prefs.getString('user_email') ?? '';
      setState(() {
        userName = email.split('@')[0].replaceFirst(
          email.isNotEmpty ? email[0] : '', 
          email.isNotEmpty ? email[0].toUpperCase() : ''
        );
      });
    }
  }

  Future<void> fetchSongsFromAppwrite() async {
    try {
      // List all files in the bucket
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
      );
      
      final List<Album> fetchedAlbums = await Future.wait(
        result.files.where((file) => file.name.endsWith('.mp3')).map((file) async {
          // Create the URL for the audio file
          String downloadUrl = await getFileViewUrl(file.$id);
          String name = file.name.replaceAll('.mp3', '');
          
          // Try to find a matching image file
          String? imageUrl = await getImageUrl(name);
          
          return Album(name, downloadUrl, imageUrl);
        }).toList()
      );

      setState(() {
        albums = fetchedAlbums;
      });
    } catch (e) {
      print('Error fetching songs from Appwrite: $e');
    }
  }

  // Helper method to get a view URL for a file
  Future<String> getFileViewUrl(String fileId) async {
    // Using download endpoint which works better with media players
    return '${AppConfig.endpoint}/storage/buckets/${AppConfig.storageId}/files/$fileId/download?project=${AppConfig.projectId}';
  }

  Future<String?> getImageUrl(String songName) async {
    try {
      // List all files in the bucket to find matching image
      final result = await storage.listFiles(
        bucketId: AppConfig.storageId,
        queries: [
          Query.equal('name', '$songName.jpg'), // Try exact match first
        ],
      );
      
      if (result.files.isNotEmpty) {
        // Found exact match
        return getFileViewUrl(result.files.first.$id);
      }
      
      // Try with .png extension
      final resultPng = await storage.listFiles(
        bucketId: AppConfig.storageId,
        queries: [
          Query.equal('name', '$songName.png'),
        ],
      );
      
      if (resultPng.files.isNotEmpty) {
        return getFileViewUrl(resultPng.files.first.$id);
      }
      
      // No image found
      print('No image found for $songName');
      return null;
    } catch (e) {
      print('Error fetching image for $songName: $e');
      return null;
    }
  }

  Future<void> loadRecentlyPlayed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recentlyPlayedJson = prefs.getStringList('recently_played') ?? [];
    setState(() {
      _recentlyPlayed = recentlyPlayedJson
          .map((json) => Album.fromJson(jsonDecode(json)))
          .toSet();
    });
  }

  Future<void> saveRecentlyPlayed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> recentlyPlayedJson = _recentlyPlayed
        .map((album) => jsonEncode(album.toJson()))
        .toList();
    await prefs.setStringList('recently_played', recentlyPlayedJson);
  }

  void addToRecentlyPlayed(Album album) {
    setState(() {
      _recentlyPlayed = {album, ..._recentlyPlayed}.take(_maxRecentlyPlayed).toSet();
    });
    saveRecentlyPlayed();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, ";
    if (hour < 18) return "Good afternoon, ";
    return "Good evening, ";
  }

  Widget _buildGreetingBanner() {
    if (!_greetingVisible) return SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black87,
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}$userName',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Let's explore some music!",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _greetingVisible = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionTiles() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.playlist_play, color: Colors.white),
          title: Text(
            "Playlists",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          onTap: () {},
        ),
        ListTile(
          leading: Icon(Icons.favorite, color: Colors.redAccent),
          title: Text(
            "Favorites",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          onTap: () {},
        ),
        ListTile(
          leading: Icon(Icons.settings, color: Colors.grey),
          title: Text(
            "Settings",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          onTap: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
      ],
    );
  }
  
  Widget _buildRecommendedAlbums() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recommended Albums",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          GridView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1, // Square cards for symmetry
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () {
                  widget.onPlaySong(album);
                  addToRecentlyPlayed(album);
                },
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(
                            album.imageUrl ?? 'https://via.placeholder.com/200',
                          ),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {
                            print('Error loading image: $exception');
                          },
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black87.withOpacity(0.7),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Artist Name", // Replace with actual artist data if available
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting banner - made flexible with constraints
            if (_greetingVisible)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.black87,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}$userName',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: screenSize.width < 360 ? 20 : 24,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Let's explore some music!",
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width < 360 ? 14 : 16,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _greetingVisible = false;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              
            // Page heading
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                "Home",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: screenSize.width < 360 ? 28 : 32,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Main scrollable content
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: BouncingScrollPhysics(),
                children: [
                  _buildFunctionTiles(),
                  
                  // Recommended albums section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      "Recommended Albums",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  // Albums grid with responsive sizing
                  _buildResponsiveAlbumGrid(screenSize),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New method for responsive album grid
  Widget _buildResponsiveAlbumGrid(Size screenSize) {
    // Calculate ideal item width based on screen size
    final crossAxisCount = screenSize.width < 600 ? 2 : 3;
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8, // Slightly taller than wide for better text display
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return _buildAlbumCard(album);
        },
      ),
    );
  }

  // Album card with error handling for images
  Widget _buildAlbumCard(Album album) {
    return GestureDetector(
      onTap: () {
        widget.onPlaySong(album);
        addToRecentlyPlayed(album);
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.grey[900],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Album image with error handling
              Expanded(
                flex: 3,
                child: album.imageUrl != null
                    ? Image.network(
                        album.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: Icon(Icons.music_note, size: 40, color: Colors.white70),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: Icon(Icons.music_note, size: 40, color: Colors.white70),
                        ),
                      ),
              ),
              
              // Album info
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.black45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        album.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (album.artist != null && album.artist!.isNotEmpty)
                        Text(
                          album.artist!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Update the Album class to include ID and artist name

class Album {
  final String id;  // Add ID field
  final String name;
  final String downloadUrl;
  final String? imageUrl;
  final String? artist;  // Add artist field
  
  Album(
    this.name,
    this.downloadUrl,
    this.imageUrl, {
    this.id = 'default_song',  // Default value
    this.artist,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'downloadUrl': downloadUrl,
        'imageUrl': imageUrl,
        'artist': artist,
      };

  static Album fromJson(Map<String, dynamic> json) => Album(
        json['name'],
        json['downloadUrl'],
        json['imageUrl'],
        id: json['id'],
        artist: json['artist'],
      );
}