import 'package:flutter/material.dart';

class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? technicalDetails;
  final VoidCallback onRetry;
  final VoidCallback onContinueOffline;
  
  const ErrorScreen({
    Key? key,
    required this.title,
    required this.message,
    this.technicalDetails,
    required this.onRetry,
    required this.onContinueOffline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (technicalDetails != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Technical Details:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        technicalDetails!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Retry Connection'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onContinueOffline,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Continue in Offline Mode (Limited Functionality)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 