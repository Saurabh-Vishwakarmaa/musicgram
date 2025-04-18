// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class RewardsPage extends StatefulWidget {
//   @override
//   _RewardsPageState createState() => _RewardsPageState();
// }

// class _RewardsPageState extends State<RewardsPage> {
//   final List<Reward> rewards = [
//     Reward('Free month of Premium', 'Listen for 100 minutes', 100, 0),
//     Reward('Exclusive playlist', 'Listen for 50 minutes', 50, 0),
//     Reward('Early access to new releases', 'Listen for 200 minutes', 200, 0),
//     Reward('Virtual concert ticket', 'Listen for 300 minutes', 300, 0),
//     Reward('Custom playlist cover', 'Listen for 25 minutes', 25, 0),
//   ];

//   int _totalListeningTimeMinutes = 0; // Store total listening time in minutes

//   @override
//   void initState() {
//     super.initState();
//     _loadListeningTime(); // Load the total listening time on start
//   }

//   // Load the total listening time from SharedPreferences
//   Future<void> _loadListeningTime() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
//     });

//     // Update current hours for rewards based on total listening time
//     for (var reward in rewards) {
//       reward.currentHours = _totalListeningTimeMinutes;
//     }
//   }

//   // Method to convert minutes to hours for display purposes
//   String get listeningTimeInMinutes => '${_totalListeningTimeMinutes} minutes';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Rewards',
//           style: GoogleFonts.firaSansCondensed(
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: Colors.red,
//       ),
//       body: Container(
//         color: Colors.red,
//         child: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Text(
//                 'Your Listening Time: $listeningTimeInMinutes',
//                 style: GoogleFonts.firaSansCondensed(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: rewards.length,
//                 itemBuilder: (context, index) {
//                   return _buildRewardCard(rewards[index]);
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRewardCard(Reward reward) {
//     double progress = reward.currentHours / reward.requiredHours;
//     return Card(
//       margin: const EdgeInsets.all(16.0),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(10.0),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               reward.name,
//               style: GoogleFonts.firaSansCondensed(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               reward.description,
//               style: GoogleFonts.firaSansCondensed(
//                 fontSize: 16,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 16),
//             LinearProgressIndicator(
//               value: progress,
//               backgroundColor: Colors.grey[300],
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               '${reward.currentHours}/${reward.requiredHours} minutes',
//               style: GoogleFonts.firaSansCondensed(
//                 fontSize: 16,
//                 color: Colors.black54,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class Reward {
//   final String name;
//   final String description;
//   final int requiredHours; // This is in minutes now
//   int currentHours; // Current hours also in minutes

//   Reward(this.name, this.description, this.requiredHours, this.currentHours);
// }









//TAKE 1
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class RewardsPage extends StatefulWidget {
//   @override
//   _RewardsPageState createState() => _RewardsPageState();
// }

// class _RewardsPageState extends State<RewardsPage> {
//   final List<Reward> rewards = [
//     Reward('Free month of Premium', 'Listen for 100 minutes', 100, 0),
//     Reward('Exclusive playlist', 'Listen for 50 minutes', 50, 0),
//     Reward('Early access to new releases', 'Listen for 200 minutes', 200, 0),
//     Reward('Virtual concert ticket', 'Listen for 300 minutes', 300, 0),
//     Reward('Custom playlist cover', 'Listen for 25 minutes', 25, 0),
//   ];

//   int _totalListeningTimeMinutes = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadListeningTime();
//   }

//   Future<void> _loadListeningTime() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
//       for (var reward in rewards) {
//         reward.currentHours = _totalListeningTimeMinutes;
//       }
//     });
//   }

//   String get listeningTimeInMinutes => '$_totalListeningTimeMinutes minutes';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage('assets/pixel_background.png'), // Add a pixelated background image
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildPixelatedAppBar(),
//               _buildListeningTimeDisplay(),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: rewards.length,
//                   itemBuilder: (context, index) {
//                     return _buildPixelatedRewardCard(rewards[index]);
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPixelatedAppBar() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.7),
//         border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
//       ),
//       child: Row(
//         children: [
//           Text(
//             'REWARDS',
//             style: GoogleFonts.pressStart2p(
//               fontSize: 20,
//               color: Colors.white,
//             ),
//           ),
//           Spacer(),
//           Icon(Icons.star, color: Colors.yellow, size: 24),
//         ],
//       ),
//     );
//   }

//   Widget _buildListeningTimeDisplay() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.7),
//         border: Border.all(color: Colors.white, width: 2),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.headphones, color: Colors.white, size: 24),
//           SizedBox(width: 8),
//           Text(
//             listeningTimeInMinutes,
//             style: GoogleFonts.pressStart2p(
//               fontSize: 16,
//               color: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPixelatedRewardCard(Reward reward) {
//     double progress = reward.currentHours / reward.requiredHours;
//     bool isUnlocked = progress >= 1;

//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: isUnlocked ? Colors.green.withOpacity(0.7) : Colors.black.withOpacity(0.7),
//         border: Border.all(color: Colors.white, width: 2),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   reward.name,
//                   style: GoogleFonts.pressStart2p(
//                     fontSize: 14,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   reward.description,
//                   style: GoogleFonts.pressStart2p(
//                     fontSize: 10,
//                     color: Colors.white70,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           _buildPixelatedProgressBar(progress),
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: Text(
//               '${reward.currentHours}/${reward.requiredHours} minutes',
//               style: GoogleFonts.pressStart2p(
//                 fontSize: 10,
//                 color: Colors.white70,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPixelatedProgressBar(double progress) {
//     return Container(
//       height: 20,
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.white, width: 2),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             flex: (progress * 100).round(),
//             child: Container(color: Colors.yellow),
//           ),
//           Expanded(
//             flex: ((1 - progress) * 100).round(),
//             child: Container(color: Colors.grey.withOpacity(0.3)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class Reward {
//   final String name;
//   final String description;
//   final int requiredHours;
//   int currentHours;

//   Reward(this.name, this.description, this.requiredHours, this.currentHours);
// }


//TAKE 2
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class RewardsPage extends StatefulWidget {
//   @override
//   _RewardsPageState createState() => _RewardsPageState();
// }

// class _RewardsPageState extends State<RewardsPage> {
//   final List<Reward> rewards = [
//     Reward('Free month of Premium', 'Listen for 100 minutes', 500, 0),
//     Reward('Exclusive playlist', 'Listen for 50 minutes', 50, 0),
//     Reward('Early access to new release', 'Listen for 200 minutes', 200, 0),
//     Reward('Virtual concert ticket', 'Listen for 300 minutes', 300, 0),
//     Reward('Custom playlist cover', 'Listen for 25 minutes', 25, 0),
//   ];

//   int _totalListeningTimeMinutes = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadListeningTime();
//   }

//   Future<void> _loadListeningTime() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
//       for (var reward in rewards) {
//         reward.currentHours = _totalListeningTimeMinutes;
//       }
//     });
//   }

//   String get listeningTimeInMinutes => '$_totalListeningTimeMinutes minutes';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           // Change the background to a dark blue color
//           color: Color(0xFF0A2342), // Dark blue color
//           image: DecorationImage(
//             image: AssetImage('assets/pixel_overlay.png'), // Optional: Add a subtle pixel overlay
//             fit: BoxFit.cover,
//             repeat: ImageRepeat.repeat,
//             opacity: 0.1, // Make the overlay very subtle
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildPixelatedAppBar(),
//               _buildListeningTimeDisplay(),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: rewards.length,
//                   itemBuilder: (context, index) {
//                     return _buildPixelatedRewardCard(rewards[index]);
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPixelatedAppBar() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.5),
//         border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
//       ),
//       child: Row(
//         children: [
//           Text(
//             'REWARDS',
//             style: GoogleFonts.pressStart2p(
//               fontSize: 20,
//               color: Colors.white,
//             ),
//           ),
//           Spacer(),
//           Icon(Icons.star, color: Colors.yellow, size: 24),
//         ],
//       ),
//     );
//   }

//   Widget _buildListeningTimeDisplay() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.5),
//         border: Border.all(color: Colors.white, width: 2),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.headphones, color: Colors.white, size: 24),
//           SizedBox(width: 8),
//           Text(
//             listeningTimeInMinutes,
//             style: GoogleFonts.pressStart2p(
//               fontSize: 16,
//               color: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPixelatedRewardCard(Reward reward) {
//     double progress = reward.currentHours / reward.requiredHours;
//     bool isUnlocked = progress >= 1;

//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: isUnlocked ? Color(0xFF1E7145).withOpacity(0.7) : Colors.black.withOpacity(0.5),
//         border: Border.all(color: Colors.white, width: 2),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   reward.name,
//                   style: GoogleFonts.pressStart2p(
//                     fontSize: 14,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   reward.description,
//                   style: GoogleFonts.pressStart2p(
//                     fontSize: 10,
//                     color: Colors.white70,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           _buildPixelatedProgressBar(progress),
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: Text(
//               '${reward.currentHours}/${reward.requiredHours} minutes',
//               style: GoogleFonts.pressStart2p(
//                 fontSize: 10,
//                 color: Colors.white70,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPixelatedProgressBar(double progress) {
//     return Container(
//       height: 20,
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.white, width: 2),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             flex: (progress * 100).round(),
//             child: Container(color: Color(0xFFFFA500)), // Orange color for progress
//           ),
//           Expanded(
//             flex: ((1 - progress) * 100).round(),
//             child: Container(color: Colors.grey.withOpacity(0.3)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class Reward {
//   final String name;
//   final String description;
//   final int requiredHours;
//   int currentHours;

//   Reward(this.name, this.description, this.requiredHours, this.currentHours);
// }

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class RewardsPage extends StatefulWidget {
//   @override
//   _RewardsPageState createState() => _RewardsPageState();
// }

// class _RewardsPageState extends State<RewardsPage> {
//   final List<Reward> rewards = [
//     Reward('Free month of Premium', 'Listen for 100 minutes', 500, 0),
//     Reward('Exclusive playlist', 'Listen for 50 minutes', 50, 0),
//     Reward('Early access to new release', 'Listen for 200 minutes', 200, 0),
//     Reward('Virtual concert ticket', 'Listen for 300 minutes', 300, 0),
//     Reward('Custom playlist cover', 'Listen for 25 minutes', 25, 0),
//   ];

//   int _totalListeningTimeMinutes = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadListeningTime();
//   }

//   Future<void> _loadListeningTime() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
//       for (var reward in rewards) {
//         reward.currentHours = _totalListeningTimeMinutes;
//       }
//     });
//   }

//   String get listeningTimeInMinutes => '$_totalListeningTimeMinutes minutes';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.green,
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildAppBar(),
//             _buildListeningTimeDisplay(),
//             Expanded(
//               child: ListView.builder(
//                 padding: EdgeInsets.symmetric(vertical: 10),
//                 itemCount: rewards.length,
//                 itemBuilder: (context, index) {
//                   return _buildRewardCard(rewards[index]);
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAppBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.green,
//         border: Border(
//           bottom: BorderSide(color: Colors.black, width: 2),
//         ),
//       ),
//       child: Row(
//         children: [
//           Text(
//             'REWARDS',
//             style: GoogleFonts.firaSansCondensed(
//               fontSize: 22,
//               color: Colors.black,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           Spacer(),
//           Icon(Icons.star, color: Colors.black, size: 24),
//         ],
//       ),
//     );
//   }

//   Widget _buildListeningTimeDisplay() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.8),
//         border: Border.all(color: Colors.black, width: 2),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.headphones, color: Colors.black, size: 24),
//           SizedBox(width: 8),
//           Text(
//             listeningTimeInMinutes,
//             style: GoogleFonts.firaSansCondensed(
//               fontSize: 16,
//               color: Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRewardCard(Reward reward) {
//     double progress = reward.currentHours / reward.requiredHours;
//     bool isUnlocked = progress >= 1;

//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isUnlocked ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.9),
//         border: Border.all(color: Colors.black, width: 2),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             reward.name,
//             style: GoogleFonts.firaSansCondensed(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.black,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             reward.description,
//             style: GoogleFonts.firaSansCondensed(
//               fontSize: 14,
//               color: Colors.black87,
//             ),
//           ),
//           SizedBox(height: 16),
//           _buildProgressBar(progress),
//           SizedBox(height: 8),
//           Text(
//             '${reward.currentHours}/${reward.requiredHours} minutes',
//             style: GoogleFonts.firaSansCondensed(
//               fontSize: 12,
//               color: Colors.black87,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildProgressBar(double progress) {
//     return Container(
//       height: 12,
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.black, width: 1),
//       ),
//       child: FractionallySizedBox(
//         widthFactor: progress.clamp(0, 1),
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class Reward {
//   final String name;
//   final String description;
//   final int requiredHours;
//   int currentHours;

//   Reward(this.name, this.description, this.requiredHours, this.currentHours);
// }


// take 5

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:lottie/lottie.dart';

// class RewardsPage extends StatefulWidget {
//   @override
//   _RewardsPageState createState() => _RewardsPageState();
// }

// class _RewardsPageState extends State<RewardsPage> {
//   final List<Reward> rewards = [
//     Reward('Free Month of Premium', 'Listen for 100 minutes', 100),
//     Reward('Exclusive Playlist', 'Listen for 50 minutes', 50),
//     Reward('Early Access to New Releases', 'Listen for 200 minutes', 200),
//     Reward('Virtual Concert Ticket', 'Listen for 300 minutes', 300),
//     Reward('Custom Playlist Cover', 'Listen for 25 minutes', 25),
//   ];

//   int _totalListeningTimeMinutes = 0;
//   int _userLevel = 1;

//   @override
//   void initState() {
//     super.initState();
//     _loadListeningTime();
//   }

//   Future<void> _loadListeningTime() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
//       _userLevel = (prefs.getInt('user_level') ?? 1);
//       for (var reward in rewards) {
//         reward.currentProgress = _totalListeningTimeMinutes;
//       }
//     });
//   }

//   Future<void> _saveUserLevel() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('user_level', _userLevel);
//   }

//   void _levelUp() {
//     setState(() {
//       _userLevel++;
//       _saveUserLevel();
//     });
//   }

//   String get listeningTimeInMinutes => '$_totalListeningTimeMinutes minutes';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.greenAccent,
//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildAppBar(),
//             _buildUserStats(),
//             Expanded(
//               child: ListView.builder(
//                 padding: EdgeInsets.symmetric(vertical: 10),
//                 itemCount: rewards.length,
//                 itemBuilder: (context, index) {
//                   return _buildRewardCard(rewards[index]);
//                 },
//               ),
//             ),
//             _buildDailyChallenges(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAppBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: [Colors.green, Colors.teal]),
//         border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
//       ),
//       child: Row(
//         children: [
//           Text(
//             'REWARDS',
//             style: GoogleFonts.firaSansCondensed(
//               fontSize: 24,
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           Spacer(),
//           Icon(Icons.star, color: Colors.yellowAccent, size: 30),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserStats() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
//         ],
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Level $_userLevel',
//                     style: GoogleFonts.firaSansCondensed(
//                       fontSize: 18,
//                       color: Colors.black,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   Text(
//                     listeningTimeInMinutes,
//                     style: GoogleFonts.firaSansCondensed(
//                       fontSize: 16,
//                       color: Colors.grey[700],
//                     ),
//                   ),
//                 ],
//               ),
//               IconButton(
//                 icon: Icon(Icons.arrow_upward, color: Colors.green, size: 32),
//                 onPressed: _levelUp,
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//           LinearProgressIndicator(
//             value: (_userLevel / 10).clamp(0.0, 1.0),
//             backgroundColor: Colors.grey[300],
//             color: Colors.green,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRewardCard(Reward reward) {
//     double progress = reward.currentProgress / reward.requiredProgress;
//     bool isUnlocked = progress >= 1;

//     return GestureDetector(
//       onTap: isUnlocked ? (){} : (){
     
//       }, // Add functionality for unlocked rewards
//       child: Container(
//         margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         padding: EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: isUnlocked
//                 ? [Colors.green, Colors.lightGreen]
//                 : [Colors.grey[300]!, Colors.grey[400]!],
//           ),
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       reward.name,
//                       style: GoogleFonts.firaSansCondensed(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: isUnlocked ? Colors.white : Colors.black87,
//                       ),
//                     ),
//                     Text(
//                       reward.description,
//                       style: GoogleFonts.firaSansCondensed(
//                         fontSize: 14,
//                         color: isUnlocked ? Colors.white70 : Colors.black54,
//                       ),
//                     ),
//                   ],
//                 ),
//                 if (isUnlocked)
//                   Icon(Icons.lock_open, color: Colors.white, size: 28)
//                 else
//                   Icon(Icons.lock, color: Colors.black54, size: 28),
//               ],
//             ),
//             SizedBox(height: 12),
//             LinearProgressIndicator(
//               value: progress.clamp(0.0, 1.0),
//               backgroundColor: Colors.white24,
//               color: Colors.yellowAccent,
//             ),
//             SizedBox(height: 8),
//             Text(
//               '${reward.currentProgress}/${reward.requiredProgress} minutes',
//               style: GoogleFonts.firaSansCondensed(
//                 fontSize: 12,
//                 color: isUnlocked ? Colors.white : Colors.black54,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDailyChallenges() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrangeAccent]),
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(12),
//           topRight: Radius.circular(12),
//         ),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             'Daily Challenge: Listen for 20 min',
//             style: GoogleFonts.firaSansCondensed(
//               fontSize: 16,
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: () {}, // Add functionality for challenges
//             child: Text(
//               'Claim',
//               style: GoogleFonts.firaSansCondensed(
//                 fontSize: 14,
//                 color: Colors.orange,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class Reward {
//   final String name;
//   final String description;
//   final int requiredProgress;
//   int currentProgress;

//   Reward(this.name, this.description, this.requiredProgress, [this.currentProgress = 0]);
// }


// the real take part 1
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RewardsPage extends StatefulWidget {
  @override
  _RewardsPageState createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final List<Reward> rewards = [
    Reward('Free Month of Premium', 'Listen for 100 minutes', 100),
    Reward('Exclusive Playlist', 'Listen for 50 minutes', 50),
    Reward('Early Access to New Releases', 'Listen for 200 minutes', 200),
    Reward('Virtual Concert Ticket', 'Listen for 300 minutes', 300),
    Reward('Custom Playlist Cover', 'Listen for 25 minutes', 25),
  ];

  int _totalListeningTimeMinutes = 0;
  int _userLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadListeningTime();
  }

  Future<void> _loadListeningTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalListeningTimeMinutes = prefs.getInt('listening_time') ?? 0;
      _userLevel = (prefs.getInt('user_level') ?? 1);
      for (var reward in rewards) {
        reward.currentProgress = _totalListeningTimeMinutes;
      }
    });
  }

  Future<void> _saveUserLevel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_level', _userLevel);
  }

  void _levelUp() {
    setState(() {
      _userLevel++;
      _saveUserLevel();
    });
  }

  String get listeningTimeInMinutes => '$_totalListeningTimeMinutes minutes';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(),
            _buildUserStats(),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 10),
                itemCount: rewards.length,
                itemBuilder: (context, index) {
                  return _buildRewardCard(rewards[index]);
                },
              ),
            ),
            _buildDailyChallenges(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            'REWARDS',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Icon(Icons.star, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  Widget _buildUserStats() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $_userLevel',
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    listeningTimeInMinutes,
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.arrow_upward, color: Colors.white, size: 32),
                onPressed: _levelUp,
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_userLevel / 10).clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Reward reward) {
    double progress = reward.currentProgress / reward.requiredProgress;
    bool isUnlocked = progress >= 1;

    return GestureDetector(
      onTap: isUnlocked ? () {} : () {}, // Add functionality for unlocked rewards
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.name,
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.white : Colors.white70,
                      ),
                    ),
                    Text(
                      reward.description,
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isUnlocked ? Icons.lock_open : Icons.lock,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
            SizedBox(height: 8),
            Text(
              '${reward.currentProgress}/${reward.requiredProgress} minutes',
              style: GoogleFonts.firaSansCondensed(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChallenges() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Daily Challenge: Listen for 20 min',
            style: GoogleFonts.firaSansCondensed(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {}, // Add functionality for challenges
            child: Text(
              'Claim',
              style: GoogleFonts.firaSansCondensed(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Reward {
  final String name;
  final String description;
  final int requiredProgress;
  int currentProgress;

  Reward(this.name, this.description, this.requiredProgress, [this.currentProgress = 0]);
}
