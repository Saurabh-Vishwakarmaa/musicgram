import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'homie.dart'; // Import your HomePage and Album class

class SearchPage extends StatefulWidget {
  final List<Album> albums; // Pass albums from HomePage

  SearchPage({required this.albums}); // Accept albums as a parameter

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Album> _searchResults = [];

  void _performSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = []; // Clear results if the query is empty
      } else {
        // Filter the albums based on the search query
        _searchResults = widget.albums.where((album) {
          return album.name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.green,
        child: Column(
          children: [
            SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Text(
                'Search',
                style: GoogleFonts.firaSansCondensed(
                  fontWeight: FontWeight.bold,
                  fontSize: 60,
                  letterSpacing: 0.2,
                  color: Colors.black,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: Text(
                'Find your favorite songs, artists, and more',
                style: TextStyle(color: Colors.black54, fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.left,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: _buildTextField(
                controller: _searchController,
                hintText: 'Search for songs, artists, users, or communities',
                icon: Icons.search,
                onChanged: _performSearch,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_searchResults[index].name, style: TextStyle(color: Colors.black)),
                    onTap: () {
                      // Handle tapping on a search result
                      print('Tapped on: ${_searchResults[index].name}');
                      // You can add code to play the song here if needed
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: Colors.black),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: Colors.black),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 15.0),
      ),
    );
  }
}

