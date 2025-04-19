import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:musicgram4/authpages/loginpage.dart';
import 'package:musicgram4/authpages/registerpage.dart';

import 'package:musicgram4/configs/appwritecongif.dart';
import 'package:musicgram4/notifications/media_notifications.dart';
import 'package:musicgram4/pageesviews.dart';
import 'package:musicgram4/practice/youtubeapi.dart';
import 'package:musicgram4/screens/homepage.dart';
import 'package:musicgram4/services/audio_player_service.dart';
import 'package:musicgram4/settingspage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global client to reuse across the app
late Client client;
late Account account;
late Databases databases;
late Storage storage;

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

   

     // Initialize the media notification service
  await MediaNotificationService().init();
    final audioService = AudioPlayerService();
    
    // Initialize Appwrite
    client = Client()
      .setEndpoint(AppConfig.endpoint)
      .setProject(AppConfig.projectId)
      .setSelfSigned(status: true); // Remove in production
    
    // Initialize Appwrite services
    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    
    print('Appwrite initialization successful');
  } catch (e) {
    print('Error during Appwrite initialization: $e');
  }
  
  runApp(const MyApp());
}




class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Musicgram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Musicgram'),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const SignupPage(),
        '/home': (context) => MainScreen(),
        '/settings': (context) => Settingspage(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return SplashScreen();
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Check if user is logged in with Appwrite
      final currentUser = await account.get();
      
      // User is logged in, navigate to main screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    } catch (e) {
      // User is not logged in, navigate to auth screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Pageesviews()),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 150),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trending Music Videos'),
      ),
      body: YouTubeVideosWidget(
        apiKey: "AIzaSyBaPp2VHZU5vrG6n4a0XhTgQa5LXkwAE3E",
      ),
    );
  }
}