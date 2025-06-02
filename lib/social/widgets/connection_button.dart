import 'package:flutter/material.dart';
import 'dart:convert';

class ConnectionButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onToggle;
  
  const ConnectionButton({
    Key? key,
    required this.isFollowing,
    required this.onToggle,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onToggle,
      style: OutlinedButton.styleFrom(
        foregroundColor: isFollowing ? Colors.grey : Theme.of(context).primaryColor,
        side: BorderSide(
          color: isFollowing ? Colors.grey : Theme.of(context).primaryColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(isFollowing ? 'Following' : 'Follow'),
    );
  }
}

// Option 1: Store metadata as a string and parse it
// In your database service:
