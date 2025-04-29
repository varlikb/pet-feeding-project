import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;
  String? _userId;
  String? _lastError;
  bool _isOfflineMode = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userId => _userId;
  String? get lastError => _lastError;
  bool get isOfflineMode => _isOfflineMode;

  Future<bool> login(String email, String password) async {
    try {
      // Normal Supabase authentication
      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );
      
      final user = response.user;
      if (user != null) {
        _isAuthenticated = true;
        _userEmail = user.email;
        _userName = user.userMetadata?['name'] as String? ?? email.split('@')[0];
        _userId = user.id;
        _lastError = null;
        _isOfflineMode = false;
        
        // Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', _userEmail ?? '');
        await prefs.setString('userName', _userName ?? '');
        await prefs.setString('userId', _userId ?? '');
        await prefs.setBool('isOfflineMode', false);
        
        notifyListeners();
        return true;
      }
      _lastError = 'Invalid credentials';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      
      if (e.toString().contains('not initialized') || 
          e.toString().contains('network') ||
          e.toString().contains('connection')) {
        // Only fall back to offline mode if explicitly allowed
        debugPrint('Connection issue: $e');
        return false;
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      // Normal Supabase registration
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      
      final user = response.user;
      if (user != null) {
        _isAuthenticated = true;
        _userEmail = user.email;
        _userName = name;
        _userId = user.id;
        _lastError = null;
        _isOfflineMode = false;
        
        // Save registration state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', _userEmail ?? '');
        await prefs.setString('userName', _userName ?? '');
        await prefs.setString('userId', _userId ?? '');
        await prefs.setBool('isOfflineMode', false);
        
        notifyListeners();
        return {'success': true};
      }
      _lastError = 'Registration failed';
      notifyListeners();
      return {'success': false, 'error': 'Registration failed'};
    } catch (e) {
      _lastError = e.toString();
      
      // Format the error message to be more user-friendly
      String errorMessage = e.toString();
      
      if (errorMessage.contains('not initialized') || 
          errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        // Network connectivity issue
        errorMessage = 'No internet connection. Please check your network and try again.';
      } else if (errorMessage.contains('User already registered')) {
        errorMessage = 'Email is already registered. Try logging in instead.';
      } else if (errorMessage.contains('Password should be at least')) {
        errorMessage = 'Password is too short. It should be at least 6 characters.';
      } else if (errorMessage.contains('invalid email')) {
        errorMessage = 'Please enter a valid email address.';
      }
      
      notifyListeners();
      return {'success': false, 'error': errorMessage};
    }
  }

  Future<void> logout() async {
    try {
      if (!_isOfflineMode) {
        await SupabaseService.signOut();
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isAuthenticated = false;
      _userEmail = null;
      _userName = null;
      _userId = null;
      _isOfflineMode = false;
      
      // Clear saved login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isAuthenticated');
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.remove('userId');
      await prefs.remove('isOfflineMode');
      
      notifyListeners();
    }
  }
  
  // Check if user is already logged in from previous session
  Future<void> checkLoginStatus() async {
    try {
      // Try to get session from Supabase first
      try {
        final currentUser = SupabaseService.getCurrentUser();
        if (currentUser != null) {
          _isAuthenticated = true;
          _userEmail = currentUser.email;
          _userName = currentUser.userMetadata?['name'] as String? ?? 
                      currentUser.email?.split('@')[0] ?? 'User';
          _userId = currentUser.id;
          _lastError = null;
          _isOfflineMode = false;
          
          // Update SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAuthenticated', true);
          await prefs.setString('userEmail', _userEmail ?? '');
          await prefs.setString('userName', _userName ?? '');
          await prefs.setString('userId', _userId ?? '');
          await prefs.setBool('isOfflineMode', false);
          
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Supabase auth check failed: $e');
        // If Supabase auth fails, we don't authenticate the user
        _isAuthenticated = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in checkLoginStatus: $e');
      _lastError = e.toString();
      _isAuthenticated = false;
      notifyListeners();
    }
  }
} 