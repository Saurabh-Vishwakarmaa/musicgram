import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:musicgram4/authpages/loginpage.dart';
import 'package:musicgram4/main.dart'; // For global Appwrite instances

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool passwordVisible = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phonenoController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phonenoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
         color: Color.fromARGB(255, 251, 62, 56), // Changed to a solid background color
        child: ListView(
          scrollDirection: Axis.vertical, // Align left for a cleaner look
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Text(
                'New User?',
                style: GoogleFonts.firaSansCondensed(
                  fontWeight: FontWeight.bold,
                  fontSize: 60,
                  letterSpacing: 0.2,
                  color: Colors.black, // Black text instead of white
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: Text(
                'Create an account to get started',
                style: TextStyle(color: Colors.black54, fontSize: 26,fontWeight: FontWeight.bold), // Black text
                textAlign: TextAlign.left, // Left align text
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 20),
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
                    suffix: IconButton(
                      icon: Icon(
                        passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          passwordVisible = !passwordVisible;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    icon: Icons.lock,
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phonenoController,
                    hintText: 'Phone Number',
                    icon: Icons.phone,
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
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildActionButton('Register', true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionButton('Sign In', false),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
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
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black), // Black text instead of white
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black54), // Black hint text
        prefixIcon: Icon(icon, color: Colors.black),
        suffixIcon: suffix,
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
        contentPadding: const EdgeInsets.symmetric(vertical: 22.0, horizontal: 15.0),
      ),
    );
  }

  Widget _buildActionButton(String text, bool isPrimary) {
    return ElevatedButton(
      onPressed: () {
        if (isPrimary) {
          signup();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: isPrimary ? Colors.white : Colors.black, 
        backgroundColor: isPrimary ? Colors.black : Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: Colors.black54),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: isPrimary ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  void signup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Get values from controllers
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;
    String phone = _phonenoController.text.trim();

    // Validation
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = "Please fill in all fields";
        _isLoading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = "Passwords do not match";
        _isLoading = false;
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _errorMessage = "Password must be at least 8 characters";
        _isLoading = false;
      });
      return;
    }

    try {
      // Create user in Appwrite
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

      // Create user preferences in the database (optional)
      try {
        await databases.createDocument(
          databaseId: 'your-database-id', // Replace with your actual database ID
          collectionId: 'users', // Replace with your collection ID
          documentId: ID.unique(),
          data: {
            'user_id': user.$id,
            'name': name,
            'email': email,
            'phone': phone,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        print("Error creating user preferences: $e");
        // Continue anyway since the user is created
      }

      print("User successfully created with ID: ${user.$id}");
      
      setState(() {
        _isLoading = false;
      });

      // Navigate to login page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } on AppwriteException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Registration failed";
        _isLoading = false;
      });
      print("Appwrite error: ${e.message}");
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred";
        _isLoading = false;
      });
      print("Error during registration: $e");
    }
  }
}
