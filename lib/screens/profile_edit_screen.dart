import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:musicgram4/database/social_database_service.dart';
import 'package:musicgram4/social/models/user_profile.dart';
import 'package:musicgram4/services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserProfile userProfile;
  final SocialDatabaseService socialService;

  const ProfileEditScreen({
    Key? key,
    required this.userProfile,
    required this.socialService,
  }) : super(key: key);

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  
  File? _imageFile;
  bool _isLoading = false;
  bool _usernameChanged = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.userProfile.username);
    _displayNameController = TextEditingController(text: widget.userProfile.displayName);
    _bioController = TextEditingController(text: widget.userProfile.bio);
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }
  
  Future<void> _saveChanges() async {
    // Validate inputs
    if (_displayNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Display name cannot be empty";
      });
      return;
    }
    
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Username cannot be empty";
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      String? newAvatarUrl;
      
      // Upload new profile image if selected
      if (_imageFile != null) {
        try {
          print('Preparing to upload profile image...');
          
          // Read the file bytes
          final bytes = await _imageFile!.readAsBytes();
          
          // Create MultipartFile using InputFile directly
          final fileData = MultipartFile(
            'file',
            Stream.fromIterable([bytes]),
            bytes.length,
            filename: 'profile_${widget.userProfile.userId}.jpg',
          );
          
          // Upload the file using the updated method
          final uploadResult = await widget.socialService.uploadProfileImage(
            fileData,
            widget.userProfile.userId,
          );
          
          // Get the file ID for profile update
          newAvatarUrl = uploadResult.$id;
          print('File uploaded successfully with ID: $newAvatarUrl');
        } catch (e) {
          print('Error uploading image: $e');
          // Continue with other updates even if image upload fails
        }
      }
      
      // Check if username was changed and needs checking for uniqueness
      if (_usernameChanged) {
        try {
          // Check if username is already taken
          final isUsernameTaken = await widget.socialService.isUsernameTaken(
            _usernameController.text.trim(),
            widget.userProfile.userId,
          );
          
          if (isUsernameTaken) {
            setState(() {
              _isLoading = false;
              _errorMessage = "Username is already taken";
            });
            return;
          }
        } catch (e) {
          print('Error checking username: $e');
        }
      }
      
      // Update user profile
      await widget.socialService.updateUserProfile(
        userId: widget.userProfile.userId,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarFileId: newAvatarUrl ?? widget.userProfile.avatarFileId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error updating profile: $e";
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.firaSansCondensed(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile image
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!)
                          : widget.userProfile.avatarFileId != null
                            ? NetworkImage(widget.userProfile.avatarFileId!)
                            : null,
                        backgroundColor: Colors.grey[800],
                        child: (_imageFile == null && widget.userProfile.avatarFileId == null)
                          ? Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.firaSansCondensed(
                        color: Colors.red,
                      ),
                    ),
                  ),
                
                // Username field
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'Enter username',
                  prefixIcon: Icons.alternate_email,
                  onChanged: (value) {
                    setState(() {
                      _usernameChanged = true;
                    });
                  },
                ),
                SizedBox(height: 16),
                
                // Display name field
                _buildTextField(
                  controller: _displayNameController,
                  label: 'Display Name',
                  hint: 'Enter display name',
                  prefixIcon: Icons.person,
                ),
                SizedBox(height: 16),
                
                // Bio field
                _buildTextField(
                  controller: _bioController,
                  label: 'Bio',
                  hint: 'Tell us about yourself',
                  prefixIcon: Icons.info_outline,
                  maxLines: 3,
                ),
                SizedBox(height: 32),
                
                // Save button
                ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.firaSansCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaSansCondensed(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.firaSansCondensed(
              color: Colors.white,
            ),
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.firaSansCondensed(
                color: Colors.grey[600],
              ),
              prefixIcon: Icon(
                prefixIcon,
                color: Colors.grey[600],
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}