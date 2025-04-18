import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:musicgram4/fifthpage.dart';
import 'package:musicgram4/firstpage.dart';
import 'package:musicgram4/fourthpage.dart';
import 'package:musicgram4/secondpage.dart';
import 'package:musicgram4/thirdpage.dart';

class Pageesviews extends StatefulWidget {
  const Pageesviews({super.key});

  @override
  State<Pageesviews> createState() => _PageesviewsState();
}

class _PageesviewsState extends State<Pageesviews> {
  final LiquidController _liquidController = LiquidController();
  int _currentPage = 0;

  final pages = [
    const Fourthpage(),
    const Firstpage(),
    const Fifthpage(),
    const Thirdpage(),
    const Secondpage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // LiquidSwipe for page navigation
          Expanded(
            child: LiquidSwipe(
              pages: pages,
              liquidController: _liquidController,
              onPageChangeCallback: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              enableSideReveal: false,
              enableLoop: false, // Disable loop to stop at the last page.
            ),
          ),
          // Display button on the last page
        
        ],
      ),
    );
  }
}

// class SomeNewPage extends StatelessWidget {
//   const SomeNewPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("New Page")),
//       body: const Center(child: Text("You have moved ahead!")),
//     );
//   }
// }
