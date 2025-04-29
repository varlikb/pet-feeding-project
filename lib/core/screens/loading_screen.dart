import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  final String message;
  
  const LoadingScreen({
    super.key,
    this.message = 'Initializing...',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
} 