import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;
  
  // Hard-coded test accounts
  final Map<String, Map<String, String>> _fakeAccounts = {
    'test@example.com': {
      'password': 'password123',
      'name': 'Test User'
    },
    'admin@example.com': {
      'password': 'admin123',
      'name': 'Admin User'
    }
  };

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  Future<bool> login(String email, String password) async {
    // Check if the email exists in our fake accounts
    if (_fakeAccounts.containsKey(email)) {
      // Check if password matches
      if (_fakeAccounts[email]!['password'] == password) {
        _isAuthenticated = true;
        _userEmail = email;
        _userName = _fakeAccounts[email]!['name'];
        notifyListeners();
        
        // Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userName', _userName!);
        
        return true;
      }
    }
    
    // Allow any login during development (comment this out for stricter testing)
    _isAuthenticated = true;
    _userEmail = email;
    _userName = email.split('@')[0];
    notifyListeners();
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    // Add the new account to our fake accounts
    _fakeAccounts[email] = {
      'password': password,
      'name': name
    };
    
    _isAuthenticated = true;
    _userEmail = email;
    _userName = name;
    notifyListeners();
    
    // Save registration state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', true);
    await prefs.setString('userEmail', email);
    await prefs.setString('userName', name);
    
    return true;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _userEmail = null;
    _userName = null;
    
    // Clear saved login state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    
    notifyListeners();
  }
  
  // Check if user is already logged in from previous session
  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    if (_isAuthenticated) {
      _userEmail = prefs.getString('userEmail');
      _userName = prefs.getString('userName');
      notifyListeners();
    }
  }
} 