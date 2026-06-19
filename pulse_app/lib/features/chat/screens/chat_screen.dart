import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String userId;
  const ChatScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Chat Screen')),
    );
  }
}