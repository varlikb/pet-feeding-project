import 'package:flutter/material.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

enum PasswordResetStage {
  requestOTP,
  enterOTP,
  setNewPassword,
  success,
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  PasswordResetStage _currentStage = PasswordResetStage.requestOTP;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestOTP() async {
    setState(() {
      _errorMessage = null;
    });
    
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await SupabaseService.sendOTPForPasswordReset(
        email: _emailController.text,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStage = PasswordResetStage.enterOTP;
          _errorMessage = null;
        });
        
        // Show a snackbar to inform user about the OTP
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A verification code has been sent to your email. Please check your inbox and spam folder.'),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        
        // Format the error message to be more user-friendly
        if (errorMsg.contains('No user found')) {
          errorMsg = 'No account found with this email address';
        } else if (errorMsg.contains('invalid email')) {
          errorMsg = 'Please enter a valid email address';
        }
        
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
      }
    }
  }

  Future<void> _verifyOTPAndSetPassword() async {
    setState(() {
      _errorMessage = null;
    });
    
    if (_otpController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code sent to your email';
      });
      return;
    }

    if (_currentStage == PasswordResetStage.setNewPassword) {
      // Validate passwords
      if (_passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a new password';
        });
        return;
      }
      
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }
      
      if (_passwordController.text.length < 6) {
        setState(() {
          _errorMessage = 'Password must be at least 6 characters';
        });
        return;
      }
    }

    setState(() => _isLoading = true);
    
    try {
      if (_currentStage == PasswordResetStage.enterOTP) {
        // Just validate the OTP code format here
        if (_otpController.text.length < 6) {
          throw Exception('Please enter the complete verification code');
        }
        
        // Move to password setting stage
        setState(() {
          _isLoading = false;
          _currentStage = PasswordResetStage.setNewPassword;
        });
        return;
      }
      
      // Final verification and password update
      await SupabaseService.verifyOTPAndUpdatePassword(
        email: _emailController.text,
        token: _otpController.text,
        newPassword: _passwordController.text,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStage = PasswordResetStage.success;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password has been successfully reset!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Request OTP Stage
              if (_currentStage == PasswordResetStage.requestOTP) ...[
                const Text(
                  'Forgot your password?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter your email address and we\'ll send you a verification code to reset your password.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _requestOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Send Verification Code'),
                ),
              ],
              
              // Enter OTP Stage
              if (_currentStage == PasswordResetStage.enterOTP) ...[
                const Text(
                  'Check your inbox',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'ve sent a verification code to:\n${_emailController.text}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTPAndSetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify Code'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading 
                    ? null 
                    : () => setState(() => _currentStage = PasswordResetStage.requestOTP),
                  child: const Text('Back to Email Entry'),
                ),
              ],
              
              // Set New Password Stage
              if (_currentStage == PasswordResetStage.setNewPassword) ...[
                const Text(
                  'Create new password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTPAndSetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Update Password'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading 
                    ? null 
                    : () => setState(() => _currentStage = PasswordResetStage.enterOTP),
                  child: const Text('Back to Verification'),
                ),
              ],
              
              // Success Stage
              if (_currentStage == PasswordResetStage.success) ...[
                const Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Password Reset Successfully!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your password has been updated. You can now log in with your new password.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back to Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 