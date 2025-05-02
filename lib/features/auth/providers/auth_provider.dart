import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';
import '../../admin/services/admin_service.dart';
import '../../admin/models/admin_role.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;
  String? _userId;
  String? _lastError;
  bool _isOfflineMode = false;
  AdminRole? _adminRole;
  bool _isCheckingAdmin = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userId => _userId;
  String? get lastError => _lastError;
  bool get isOfflineMode => _isOfflineMode;
  AdminRole? get adminRole => _adminRole;
  bool get isAdmin => _adminRole != null;
  bool get isCheckingAdmin => _isCheckingAdmin;

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
        
        // Check admin status without setting isCheckingAdmin
        try {
          _adminRole = await AdminService.getUserRole();
          notifyListeners();
        } catch (e) {
          debugPrint('Error checking admin status: $e');
          _adminRole = null;
        }
        
        return true;
      }
      _lastError = 'Invalid email or password';
      notifyListeners();
      return false;
    } catch (e) {
      String errorMessage = e.toString();
      
      // Format error messages to be more user-friendly
      if (errorMessage.contains('Invalid login credentials')) {
        _lastError = 'Invalid email or password';
      } else if (errorMessage.contains('not initialized') || 
                 errorMessage.contains('network') ||
                 errorMessage.contains('connection')) {
        _lastError = 'Unable to connect to the server. Please check your internet connection and try again.';
      } else if (errorMessage.contains('too many requests')) {
        _lastError = 'Too many login attempts. Please wait a few minutes and try again.';
      } else if (errorMessage.contains('email not confirmed')) {
        _lastError = 'Please verify your email address before logging in.';
      } else {
        _lastError = 'An unexpected error occurred. Please try again.';
        debugPrint('Login error: $errorMessage');
      }
      
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      
      return {'success': true};
    } catch (e) {
      _lastError = e.toString();
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String token) async {
    try {
      final response = await SupabaseService.verifyEmail(
        email: email,
        token: token,
      );
      
      return {'success': true};
    } catch (e) {
      _lastError = e.toString();
      return {
        'success': false,
        'error': e.toString(),
      };
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
      _adminRole = null;
      
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
    if (_isCheckingAdmin) return; // Prevent multiple simultaneous checks
    
    _isCheckingAdmin = true;
    notifyListeners();

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
        
        // Check admin status without setting isCheckingAdmin again
        try {
          _adminRole = await AdminService.getUserRole();
          notifyListeners();
        } catch (e) {
          debugPrint('Error checking admin status: $e');
          _adminRole = null;
        }
      } else {
        _isAuthenticated = false;
        _adminRole = null;
      }
    } catch (e) {
      debugPrint('Error in checkLoginStatus: $e');
      _lastError = e.toString();
      _isAuthenticated = false;
      _adminRole = null;
    } finally {
      _isCheckingAdmin = false;
      notifyListeners();
    }
  }

  Future<void> checkAdminStatus() async {
    if (_isCheckingAdmin) return; // Prevent multiple simultaneous checks
    
    _isCheckingAdmin = true;
    notifyListeners();

    try {
      _adminRole = await AdminService.getUserRole();
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      _adminRole = null;
    } finally {
      _isCheckingAdmin = false;
      notifyListeners();
    }
  }

  void updateUserName(String newName) {
    _userName = newName;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('userName', newName);
    });
    notifyListeners();
  }
} 