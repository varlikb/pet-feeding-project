import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;
  
  // Replace with a real public Supabase instance for development
  static const String _devSupabaseUrl = 'https://hnkclurwgwgksbqohsvd.supabase.co';
  static const String _devSupabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhua2NsdXJ3Z3dna3NicW9oc3ZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU5NDIzOTIsImV4cCI6MjA2MTUxODM5Mn0.y5v1edlixk480i2d8MH0P-qJJNj8eHpohjap9SCOREM';
  
  // Flag to use offline mode directly
  static bool _forceOfflineMode = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return; // Avoid initializing multiple times
    }
    
    // When force offline mode is enabled, don't even try to connect to Supabase
    if (_forceOfflineMode) {
      debugPrint('Forced offline mode is enabled. Skipping Supabase initialization.');
      _isInitialized = true;
      return;
    }
    
    try {
      String supabaseUrl;
      String supabaseKey;
      
      // First try to load from .env file
      try {
        await dotenv.load().timeout(const Duration(seconds: 2));
        supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
        
        // If either value is empty, use development credentials
        if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
          throw Exception('Missing Supabase credentials in .env file');
        }
      } catch (e) {
        // If loading .env fails, use development credentials
        debugPrint('Using development Supabase credentials: $e');
        supabaseUrl = _devSupabaseUrl;
        supabaseKey = _devSupabaseKey;
      }
      
      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
      
      _client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error in Supabase initialization: $e');
      throw Exception('Supabase client initialization failed: $e');
    }
  }

  static Future<void> createDummyConfig() async {
    // Skip actual Supabase initialization for development
    _isInitialized = true;
    debugPrint('Running in offline development mode - no Supabase connection');
    return;
  }

  static SupabaseClient get client {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Database operations not available.');
    }
    
    if (_client == null || !_isInitialized) {
      throw Exception('Supabase client not initialized. Call initialize() first.');
    }
    return _client!;
  }

  // Auth methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Use offline login instead.');
    }
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Use offline login instead.');
    }
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    await client.auth.signOut();
  }

  static User? getCurrentUser() {
    if (_forceOfflineMode) {
      return null; // Return null in offline mode
    }
    return client.auth.currentUser;
  }
  
  static Future<void> resetPassword({
    required String email,
    String? redirectUrl,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Password reset not available.');
    }
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectUrl,
    );
  }

  // Database operations
  static Future<List<Map<String, dynamic>>> fetchPets() async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    final userId = getCurrentUser()?.id;
    if (userId == null) return [];
    
    final response = await client
        .from('pets')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response;
  }

  static Future<Map<String, dynamic>> getPet(String id) async {
    if (_forceOfflineMode) {
      return {}; // Return empty map in offline mode
    }
    
    final response = await client
        .from('pets')
        .select('*')
        .eq('id', id)
        .single();

    return response;
  }

  static Future<void> addPet(Map<String, dynamic> petData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    try {
      await client.from('pets').insert(petData).select();
    } catch (e) {
      debugPrint('Error adding pet: $e');
      throw Exception('Failed to add pet: $e');
    }
  }

  static Future<void> updatePet(String id, Map<String, dynamic> petData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    await client.from('pets').update(petData).eq('id', id);
  }

  static Future<void> deletePet(String id) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    await client.from('pets').delete().eq('id', id);
  }

  // Feeding records
  static Future<List<Map<String, dynamic>>> fetchFeedingRecords(String petId) async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    final response = await client
        .from('feeding_records')
        .select('*')
        .eq('pet_id', petId)
        .order('feeding_time', ascending: false);

    return response;
  }

  static Future<void> addFeedingRecord(Map<String, dynamic> recordData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    await client.from('feeding_records').insert(recordData);
  }

  // Device management
  static Future<List<Map<String, dynamic>>> fetchDevices() async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    final userId = getCurrentUser()?.id;
    if (userId == null) return [];
    
    final response = await client
        .from('devices')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response;
  }

  static Future<void> addDevice(Map<String, dynamic> deviceData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    await client.from('devices').insert(deviceData);
  }

  static Future<void> updateDevice(String id, Map<String, dynamic> deviceData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    await client.from('devices').update(deviceData).eq('id', id);
  }

  static Future<void> deleteDevice(String id) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    await client.from('devices').delete().eq('id', id);
  }
} 