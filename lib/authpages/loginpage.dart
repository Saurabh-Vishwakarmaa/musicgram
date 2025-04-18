import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:musicgram4/authpages/registerpage.dart';
import 'package:musicgram4/screens/homepage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the global Appwrite instance
import 'package:musicgram4/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool passwordVisible = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.green, // Use a solid background color
        child: ListView(
          scrollDirection: Axis.vertical,
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Text(
                'Login!',
                style: GoogleFonts.firaSansCondensed(
                  fontWeight: FontWeight.bold,
                  fontSize: 60,
                  letterSpacing: 0.2,
                  color: Colors.black, // Black text
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: Text(
                'Welcome back! Please log in to your account.',
                style: TextStyle(color: Colors.black54, fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Email',
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    icon: Icons.lock,
                    obscureText: !passwordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          passwordVisible = !passwordVisible;
                        });
                      },
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 40),
                  _isLoading 
                    ? CircularProgressIndicator()
                    : _buildActionButton('Login', true),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage()));
                    },
                    child: const Text(
                      'Don\'t have an account? Register',
                      style: TextStyle(color: Colors.black, fontSize: 16,fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black), // Black text
      decoration: InputDecoration(
        hintText: hintText,
        
        hintStyle: const TextStyle(color: Colors.black54), // Black hint text
        prefixIcon: Icon(icon, color: Colors.black),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[200], // Slightly gray background for text fields
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: Colors.black),
          
        ),
          contentPadding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 15.0), // Increased vertical padding
      ),
    );
  }

  Widget _buildActionButton(String text, bool isPrimary) {
    return ElevatedButton(
      onPressed: () {
        if (isPrimary) {
          _signIn();
        }
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 25,horizontal: 45),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  void _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = "Email and password cannot be empty";
          _isLoading = false;
        });
        return;
      }
      
      // Use correct Appwrite method for authentication
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      
      // Save login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('user_email', email);
      
      print("User logged in successfully with session ID: ${session.$id}");
      
      // Navigate to main screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
      
    } on AppwriteException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Login failed. Please check your credentials.";
        _isLoading = false;
      });
      print("Appwrite error: ${e.message}");
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred";
        _isLoading = false;
      });
      print("Error during login: $e");
    }
  }
}