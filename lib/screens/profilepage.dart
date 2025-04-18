// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class ProfilePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: <Widget>[
//           SliverAppBar(
//             expandedHeight: 200.0,
//             floating: false,
//             pinned: true,
//             flexibleSpace: FlexibleSpaceBar(
//               title: Text(
//                 'John Doe',
//                 style: GoogleFonts.firaSansCondensed(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black,
//                   fontSize: 24,
//                 ),
//               ),
//               background: Image.network(
//                 'https://picsum.photos/200',
//                 fit: BoxFit.cover,
//               ),
//             ),
//             backgroundColor: Colors.green, // Match the color scheme
//           ),
//           SliverList(
//             delegate: SliverChildListDelegate([
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Stats',
//                       style: GoogleFonts.firaSansCondensed(
//                         fontSize: 26,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceAround,
//                       children: [
//                         _buildStatColumn('Followers', '1,234'),
//                         _buildStatColumn('Following', '567'),
//                         _buildStatColumn('Playlists', '23'),
//                       ],
//                     ),
//                     const SizedBox(height: 32),
//                     Text(
//                       'Top Artists',
//                       style: GoogleFonts.firaSansCondensed(
//                         fontSize: 26,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     _buildHorizontalList(),
//                     const SizedBox(height: 32),
//                     Text(
//                       'Recent Activity',
//                       style: GoogleFonts.firaSansCondensed(
//                         fontSize: 26,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     _buildActivityList(),
//                   ],
//                 ),
//               ),
//             ]),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatColumn(String label, String value) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: GoogleFonts.firaSansCondensed(
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//         Text(
//           label,
//           style: GoogleFonts.firaSansCondensed(
//             fontSize: 18,
//             color: Colors.black54,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildHorizontalList() {
//     return Container(
//       height: 120,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: 5,
//         itemBuilder: (context, index) {
//           return Container(
//             width: 100,
//             margin: const EdgeInsets.only(right: 16),
//             decoration: BoxDecoration(
//               color: Colors.grey[300],
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Center(
//               child: Text(
//                 'Artist $index',
//                 style: GoogleFonts.firaSansCondensed(
//                   color: Colors.black,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildActivityList() {
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: 5,
//       itemBuilder: (context, index) {
//         return ListTile(
//           leading: const Icon(Icons.music_note, color: Colors.black),
//           title: Text(
//             'Listened to Song $index',
//             style: GoogleFonts.firaSansCondensed(
//               color: Colors.black,
//             ),
//           ),
//           subtitle: Text(
//             '2 hours ago',
//             style: GoogleFonts.firaSansCondensed(
//               color: Colors.black54,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }


//TAKE 1
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class ProfilePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: <Widget>[
//           SliverAppBar(
//             expandedHeight: 200.0,
//             floating: false,
//             pinned: true,
//             flexibleSpace: FlexibleSpaceBar(
//               title: Text(
//                 'John Doe',
//                 style: GoogleFonts.pressStart2p(
//                   color: Colors.greenAccent,
//                   fontSize: 16, // Pixelated font tends to be small
//                 ),
//               ),
//               background: Container(
//                 decoration: BoxDecoration(
//                   image: DecorationImage(
//                     image: NetworkImage('https://picsum.photos/200'),
//                     fit: BoxFit.cover,
//                     colorFilter: ColorFilter.mode(
//                       Colors.black.withOpacity(0.5),
//                       BlendMode.darken,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             backgroundColor: Colors.black, // Dark background for contrast
//           ),
//           SliverList(
//             delegate: SliverChildListDelegate([
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildSectionTitle('Stats'),
//                     const SizedBox(height: 16),
//                     _buildStatRow(),
//                     const SizedBox(height: 32),
//                     _buildSectionTitle('Top Artists'),
//                     const SizedBox(height: 16),
//                     _buildHorizontalList(),
//                     const SizedBox(height: 32),
//                     _buildSectionTitle('Recent Activity'),
//                     const SizedBox(height: 16),
//                     _buildActivityList(),
//                   ],
//                 ),
//               ),
//             ]),
//           ),
//         ],
//       ),
//     );
//   }

//   // Method to build section titles with a pixelated style
//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: GoogleFonts.pressStart2p(
//         fontSize: 16,
//         fontWeight: FontWeight.bold,
//         color: Colors.greenAccent,
//       ),
//     );
//   }

//   // Method to build the row of stats with pixel borders
//   Widget _buildStatRow() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceAround,
//       children: [
//         _buildStatColumn('Followers', '1,234'),
//         _buildStatColumn('Following', '567'),
//         _buildStatColumn('Playlists', '23'),
//       ],
//     );
//   }

//   // Method to build the stat column with pixelated font
//   Widget _buildStatColumn(String label, String value) {
//     return Column(
//       children: [
//         Container(
//           padding: EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.greenAccent, width: 2),
//             borderRadius: BorderRadius.circular(5),
//           ),
//           child: Text(
//             value,
//             style: GoogleFonts.pressStart2p(
//               fontSize: 14,
//               color: Colors.white,
//             ),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           label,
//           style: GoogleFonts.pressStart2p(
//             fontSize: 12,
//             color: Colors.greenAccent,
//           ),
//         ),
//       ],
//     );
//   }

//   // Horizontal list of top artists with pixelated containers
//   Widget _buildHorizontalList() {
//     return Container(
//       height: 120,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: 5,
//         itemBuilder: (context, index) {
//           return Container(
//             width: 100,
//             margin: const EdgeInsets.only(right: 16),
//             decoration: BoxDecoration(
//               color: Colors.black,
//               borderRadius: BorderRadius.circular(5),
//               border: Border.all(color: Colors.greenAccent, width: 2),
//             ),
//             child: Center(
//               child: Text(
//                 'Artist $index',
//                 style: GoogleFonts.pressStart2p(
//                   color: Colors.greenAccent,
//                   fontSize: 12,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // List of recent activities with pixelated icons and text
//   Widget _buildActivityList() {
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: 5,
//       itemBuilder: (context, index) {
//         return ListTile(
//           leading: Icon(Icons.music_note, color: Colors.greenAccent, size: 30),
//           title: Text(
//             'Listened to Song $index',
//             style: GoogleFonts.pressStart2p(
//               fontSize: 12,
//               color: Colors.greenAccent,
//             ),
//           ),
//           subtitle: Text(
//             '2 hours ago',
//             style: GoogleFonts.pressStart2p(
//               fontSize: 10,
//               color: Colors.white,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }



//TAKE 2

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class ProfilePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           // Dark blue background for a retro-gamified theme
//           color: Color(0xFF0A2342), 
//           image: DecorationImage(
//             image: AssetImage('assets/pixel_overlay.png'), // Optional: Pixelated overlay image
//             fit: BoxFit.cover,
//             repeat: ImageRepeat.repeat,
//             opacity: 0.1, // Subtle pixel overlay effect
//           ),
//         ),
//         child: SafeArea(
//           child: CustomScrollView(
//             slivers: <Widget>[
//               SliverAppBar(
//                 expandedHeight: 200.0,
//                 floating: false,
//                 pinned: true,
//                 flexibleSpace: FlexibleSpaceBar(
//                   title: Text(
//                     'John Doe',
//                     style: GoogleFonts.pressStart2p(
//                       color: Colors.greenAccent, // Neon green for a retro feel
//                       fontSize: 18,
//                     ),
//                   ),
//                   background: Container(
//                     decoration: BoxDecoration(
//                       image: DecorationImage(
//                         image: NetworkImage('https://picsum.photos/200'),
//                         fit: BoxFit.cover,
//                         colorFilter: ColorFilter.mode(
//                           Colors.black.withOpacity(0.5), 
//                           BlendMode.darken,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 backgroundColor: Color(0xFF0A2342), // Match the background theme
//               ),
//               SliverList(
//                 delegate: SliverChildListDelegate([
//                   Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Stats',
//                           style: GoogleFonts.pressStart2p(
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.greenAccent,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceAround,
//                           children: [
//                             _buildStatColumn('Followers', '1,234'),
//                             _buildStatColumn('Following', '567'),
//                             _buildStatColumn('Playlists', '23'),
//                           ],
//                         ),
//                         const SizedBox(height: 32),
//                         Text(
//                           'Top Artists',
//                           style: GoogleFonts.pressStart2p(
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.greenAccent,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         _buildHorizontalList(),
//                         const SizedBox(height: 32),
//                         Text(
//                           'Recent Activity',
//                           style: GoogleFonts.pressStart2p(
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.greenAccent,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         _buildActivityList(),
//                       ],
//                     ),
//                   ),
//                 ]),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatColumn(String label, String value) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: GoogleFonts.pressStart2p(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: Colors.greenAccent,
//           ),
//         ),
//         Text(
//           label,
//           style: GoogleFonts.pressStart2p(
//             fontSize: 12,
//             color: Colors.white70,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildHorizontalList() {
//     return Container(
//       height: 120,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: 5,
//         itemBuilder: (context, index) {
//           return Container(
//             width: 100,
//             margin: const EdgeInsets.only(right: 16),
//             decoration: BoxDecoration(
//               color: Color(0xFF1A1A1A),
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: Colors.greenAccent, width: 2),
//             ),
//             child: Center(
//               child: Text(
//                 'Artist $index',
//                 style: GoogleFonts.pressStart2p(
//                   color: Colors.white,
//                   fontSize: 12,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildActivityList() {
//     return ListView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: 5,
//       itemBuilder: (context, index) {
//         return ListTile(
//           leading: const Icon(Icons.music_note, color: Colors.greenAccent),
//           title: Text(
//             'Listened to Song $index',
//             style: GoogleFonts.pressStart2p(
//               color: Colors.white,
//               fontSize: 12,
//             ),
//           ),
//           subtitle: Text(
//             '2 hours ago',
//             style: GoogleFonts.pressStart2p(
//               color: Colors.white70,
//               fontSize: 10,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }




//take 3 -- till now it was the best 23/1/25

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class ProfilePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Profile Header
//             Container(
//               height: 180,
//               color: Colors.green[800],
//               padding: const EdgeInsets.all(16),
//               child: Row(
//                 children: [
//                   CircleAvatar(
//                     radius: 40,
//                     backgroundImage: NetworkImage('https://picsum.photos/200'),
//                   ),
//                   const SizedBox(width: 16),
//                   Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'John Doe',
//                         style: GoogleFonts.firaSansCondensed(
//                           color: Colors.white,
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         'Music Enthusiast',
//                         style: GoogleFonts.firaSansCondensed(
//                           color: Colors.white70,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),
            
//             // Stats Section
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Stats',
//                     style: GoogleFonts.firaSansCondensed(
//                       fontSize: 20,
//                       color: Colors.greenAccent,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     children: [
//                       _buildStatColumn('Followers', '1,234'),
//                       _buildStatColumn('Following', '567'),
//                       _buildStatColumn('Playlists', '23'),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),
            
//             // Top Artists Section
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Text(
//                 'Top Artists',
//                 style: GoogleFonts.firaSansCondensed(
//                   fontSize: 20,
//                   color: Colors.greenAccent,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             _buildHorizontalList(),
//             const SizedBox(height: 20),
            
//             // Recent Activity Section
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Text(
//                 'Recent Activity',
//                 style: GoogleFonts.firaSansCondensed(
//                   fontSize: 20,
//                   color: Colors.greenAccent,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Expanded(child: _buildActivityList()),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatColumn(String label, String value) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: GoogleFonts.firaSansCondensed(
//             fontSize: 16,
//             color: Colors.greenAccent,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: GoogleFonts.firaSansCondensed(
//             fontSize: 12,
//             color: Colors.white70,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildHorizontalList() {
//     return Container(
//       height: 100,
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: 5,
//         itemBuilder: (context, index) {
//           return Container(
//             width: 80,
//             margin: const EdgeInsets.only(right: 16),
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: Colors.green[800],
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Center(
//               child: Text(
//                 'Artist $index',
//                 style: GoogleFonts.firaSansCondensed(
//                   color: Colors.white,
//                   fontSize: 14,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildActivityList() {
//     return ListView.builder(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       shrinkWrap: true,
//       physics: const AlwaysScrollableScrollPhysics(),
//       itemCount: 5,
//       itemBuilder: (context, index) {
//         return Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8),
//           child: ListTile(
//             contentPadding: EdgeInsets.zero,
//             leading: Icon(Icons.music_note, color: Colors.greenAccent),
//             title: Text(
//               'Listened to Song $index',
//               style: GoogleFonts.firaSansCondensed(
//                 color: Colors.white,
//                 fontSize: 14,
//               ),
//             ),
//             subtitle: Text(
//               '2 hours ago',
//               style: GoogleFonts.firaSansCondensed(
//                 color: Colors.white70,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }


// this take is going to be awesome
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Section with Premium Banner
              Stack(
                children: [
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade900, Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage('https://picsum.photos/200'),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.shade800,
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'John Doe',
                              style: GoogleFonts.firaSansCondensed(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Music Enthusiast',
                              style: GoogleFonts.firaSansCondensed(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Premium Badge
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.shade600,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.black, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            'Premium',
                            style: GoogleFonts.firaSansCondensed(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Stats Section with 3D Card Effect
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stats',
                      style: GoogleFonts.firaSansCondensed(
                        fontSize: 20,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _build3DStatCard('Followers', '1,234'),
                        _build3DStatCard('Following', '567'),
                        _build3DStatCard('Playlists', '23'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Top Artists Section with Horizontal Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Top Artists',
                  style: GoogleFonts.firaSansCondensed(
                    fontSize: 20,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildHorizontalArtistList(),

              const SizedBox(height: 20),

              // Recent Activity Section with Detailed Items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Recent Activity',
                  style: GoogleFonts.firaSansCondensed(
                    fontSize: 20,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildRecentActivityList(),

              // Placeholder for Future Features (e.g., Premium)
              const SizedBox(height: 20),
              _buildFutureFeatureSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DStatCard(String label, String value) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade800,
            blurRadius: 15,
            offset: Offset(-4, -4),
          ),
          BoxShadow(
            color: Colors.grey.shade700,
            blurRadius: 15,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 18,
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.firaSansCondensed(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalArtistList() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade900, Colors.greenAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: Offset(5, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Artist $index',
                style: GoogleFonts.firaSansCondensed(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade800,
                blurRadius: 8,
                offset: Offset(-4, -4),
              ),
              BoxShadow(
                color: Colors.grey.shade700,
                blurRadius: 8,
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.music_note, color: Colors.greenAccent),
            title: Text(
              'Listened to Song $index',
              style: GoogleFonts.firaSansCondensed(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '2 hours ago',
              style: GoogleFonts.firaSansCondensed(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFutureFeatureSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple, Colors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.5),
              blurRadius: 10,
              offset: Offset(5, 5),
            ),
          ],
        ),
        child: Text(
          'Coming Soon: Premium Features like ad-free listening and high-quality streaming!',
          style: GoogleFonts.firaSansCondensed(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class ProfilePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Profile Header
//             Stack(
//               children: [
//                 Container(
//                   height: 200,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Colors.green.shade900, Colors.black],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   top: 20,
//                   left: 16,
//                   child: Row(
//                     children: [
//                       CircleAvatar(
//                         radius: 45,
//                         backgroundImage: NetworkImage('https://picsum.photos/200'),
//                       ),
//                       const SizedBox(width: 16),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             'John Doe',
//                             style: GoogleFonts.firaSansCondensed(
//                               color: Colors.white,
//                               fontSize: 28,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Text(
//                             'Basic User', // Placeholder for premium
//                             style: GoogleFonts.firaSansCondensed(
//                               color: Colors.greenAccent,
//                               fontSize: 14,
//                               fontWeight: FontWeight.w400,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 Positioned(
//                   right: 16,
//                   bottom: 20,
//                   child: ElevatedButton(
//                     onPressed: () {},
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
//                     ),
//                     child: Text(
//                       'Upgrade to Premium',
//                       style: GoogleFonts.firaSansCondensed(
//                         fontSize: 14,
//                         color: Colors.black,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),

//             // Stats Section
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Stats',
//                     style: GoogleFonts.firaSansCondensed(
//                       fontSize: 20,
//                       color: Colors.greenAccent,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     children: [
//                       _buildStatColumn('Followers', '1,234'),
//                       _buildStatColumn('Following', '567'),
//                       _buildStatColumn('Playlists', '23'),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Top Artists Section
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Top Artists',
//                     style: GoogleFonts.firaSansCondensed(
//                       fontSize: 20,
//                       color: Colors.greenAccent,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: () {},
//                     child: Text(
//                       'See All',
//                       style: GoogleFonts.firaSansCondensed(
//                         color: Colors.green,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//             _buildTopArtists(),
//             const SizedBox(height: 20),

//             // Recent Activity Section
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Recent Activity',
//                     style: GoogleFonts.firaSansCondensed(
//                       fontSize: 20,
//                       color: Colors.greenAccent,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: () {},
//                     child: Text(
//                       'View More',
//                       style: GoogleFonts.firaSansCondensed(
//                         color: Colors.green,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//             Expanded(child: _buildRecentActivity()),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatColumn(String label, String value) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: GoogleFonts.firaSansCondensed(
//             fontSize: 16,
//             color: Colors.greenAccent,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: GoogleFonts.firaSansCondensed(
//             fontSize: 12,
//             color: Colors.white70,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTopArtists() {
//     return Container(
//       height: 100,
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: 5,
//         itemBuilder: (context, index) {
//           return Container(
//             width: 100,
//             margin: const EdgeInsets.only(right: 16),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12),
//               gradient: LinearGradient(
//                 colors: [Colors.greenAccent, Colors.black],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.green.withOpacity(0.5),
//                   blurRadius: 8,
//                   offset: Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: Center(
//               child: Text(
//                 'Artist ${index + 1}',
//                 style: GoogleFonts.firaSansCondensed(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildRecentActivity() {
//     return ListView.builder(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       itemCount: 5,
//       itemBuilder: (context, index) {
//         return Container(
//           margin: const EdgeInsets.only(bottom: 12),
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.black54,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.greenAccent.withOpacity(0.7)),
//           ),
//           child: Row(
//             children: [
//               Icon(
//                 Icons.music_note,
//                 color: Colors.greenAccent,
//                 size: 30,
//               ),
//               const SizedBox(width: 16),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Listened to Song ${index + 1}',
//                     style: GoogleFonts.firaSansCondensed(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   Text(
//                     '${index + 1} hours ago',
//                     style: GoogleFonts.firaSansCondensed(
//                       color: Colors.white70,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
