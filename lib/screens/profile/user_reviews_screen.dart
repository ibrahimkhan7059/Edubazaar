import 'package:flutter/material.dart';

class UserReviewsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserReviewsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends State<UserReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Reviews'),
      ),
      body: const Center(
        child: Text('User Reviews Screen - Coming Soon'),
      ),
    );
  }
}
 