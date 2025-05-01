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

  static Future<void> sendOTPForPasswordReset({
    required String email,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Password reset not available.');
    }
    await client.auth.resetPasswordForEmail(
      email,
    );
  }
  
  static Future<AuthResponse> verifyOTPAndUpdatePassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Password reset not available.');
    }
    // First verify the OTP
    final response = await client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery, // Use recovery type instead of magiclink
    );
    
    // Then update the password
    await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    
    return response;
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

  static Future<Map<String, dynamic>> addPet(Map<String, dynamic> petData) async {
    if (_forceOfflineMode) {
      return {}; // Return empty map in offline mode
    }
    
    try {
      final response = await client
          .from('pets')
          .insert(petData)
          .select()
          .single();
      return response;
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
    
    try {
      // First, delete all related feeding schedules
      await client.from('feeding_schedules').delete().eq('pet_id', id);
      
      // Delete all feeding records
      await client.from('feeding_records').delete().eq('pet_id', id);
      
      // Delete all pet-device assignments
      await client.from('pet_device_assignments').delete().eq('pet_id', id);
      
      // Finally, delete the pet
    await client.from('pets').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting pet: $e');
      throw Exception('Failed to delete pet: $e');
    }
  }

  // Feeding records
  static Future<List<Map<String, dynamic>>> fetchFeedingRecords(String petId) async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    try {
      final response = await client
          .from('feeding_records')
          .select('*')
          .eq('pet_id', petId)
          .order('feeding_time', ascending: false);
  
      return response;
    } catch (e) {
      debugPrint('Error fetching feeding records: $e');
      return [];
    }
  }

  static Future<void> addFeedingRecord(Map<String, dynamic> recordData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    try {
      await client.from('feeding_records').insert(recordData);
    } catch (e) {
      debugPrint('Error adding feeding record: $e');
      throw Exception('Failed to record feeding: $e');
    }
  }
  
  // Feeding schedules
  static Future<List<Map<String, dynamic>>> fetchFeedingSchedules(String petId) async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    try {
      final response = await client
          .from('feeding_schedules')
          .select('*')
          .eq('pet_id', petId)
          .order('start_time', ascending: true);
  
      return response;
    } catch (e) {
      debugPrint('Error fetching feeding schedules: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>> addFeedingSchedule(Map<String, dynamic> scheduleData) async {
    if (_forceOfflineMode) {
      // Return a fake ID in offline mode
      return {'id': DateTime.now().millisecondsSinceEpoch.toString()};
    }
    
    try {
      final response = await client
          .from('feeding_schedules')
          .insert(scheduleData)
          .select('id')
          .single();
      return response;
    } catch (e) {
      debugPrint('Error adding feeding schedule: $e');
      throw Exception('Failed to add feeding schedule: $e');
    }
  }
  
  static Future<void> updateFeedingSchedule(String id, Map<String, dynamic> scheduleData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    try {
      await client.from('feeding_schedules').update(scheduleData).eq('id', id);
    } catch (e) {
      debugPrint('Error updating feeding schedule: $e');
      throw Exception('Failed to update feeding schedule: $e');
    }
  }
  
  static Future<void> deleteFeedingSchedule(String id) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    try {
      await client.from('feeding_schedules').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting feeding schedule: $e');
      throw Exception('Failed to delete feeding schedule: $e');
    }
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

  static Future<Map<String, dynamic>?> findDeviceByKey(String deviceKey) async {
    if (_forceOfflineMode) {
      return null;
    }
    
    try {
      final response = await client
          .from('devices')
          .select('*')
          .eq('device_key', deviceKey)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error finding device by key: $e');
      return null;
    }
  }

  static Future<void> assignPetToDevice(String petId, String deviceId, bool isPrimary) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      await client.from('pet_device_assignments').insert({
        'pet_id': petId,
        'device_id': deviceId,
        'is_primary': isPrimary,
      });
    } catch (e) {
      debugPrint('Error assigning pet to device: $e');
      throw Exception('Failed to assign pet to device: $e');
    }
  }

  static Future<Map<String, dynamic>> addDevice(Map<String, dynamic> deviceData) async {
    if (_forceOfflineMode) {
      return {};
    }
    
    try {
      final response = await client
          .from('devices')
          .insert(deviceData)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error adding device: $e');
      throw Exception('Failed to add device: $e');
    }
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

  // Debug utility to inspect tables
  static Future<String> getTableInfo(String tableName) async {
    if (_forceOfflineMode) {
      return "Offline mode - cannot inspect tables";
    }
    
    try {
      // Try to select a single row to see column errors
      final response = await client
          .from(tableName)
          .select('*')
          .limit(1);
      
      return "Table structure for $tableName appears valid. Sample data: $response";
    } catch (e) {
      // If there's an error, try to get more diagnostic info
      return "Error with table $tableName: $e";
    }
  }

  static Future<Map<String, dynamic>?> getPrimaryDeviceForPet(String petId) async {
    if (_forceOfflineMode) {
      return null;
    }
    
    try {
      final response = await client
          .from('pet_device_assignments')
          .select('*')
          .eq('pet_id', petId)
          .eq('is_primary', true)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error getting primary device for pet: $e');
      return null;
    }
  }

  static Future<void> recordScheduledFeeding(String scheduleId) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      // First get the schedule details
      final schedule = await client
          .from('feeding_schedules')
          .select('*, pets!inner(*), pet_device_assignments!inner(*)')
          .eq('id', scheduleId)
          .eq('pet_device_assignments.is_primary', true)
          .single();
      
      if (schedule == null) {
        throw Exception('Schedule not found');
      }

      // Get current device details
      final deviceId = schedule['pet_device_assignments']['device_id'];
      final deviceDetails = await getDevice(deviceId);
      if (deviceDetails == null) {
        throw Exception('Device not found');
      }

      // Check if there's enough food and calculate new level
      final amount = (schedule['amount'] as num).toDouble();
      final currentFoodLevel = (deviceDetails['food_level'] as num).toDouble();
      
      if (currentFoodLevel < amount) {
        throw Exception('Not enough food in device. Available: ${currentFoodLevel.toStringAsFixed(1)}g');
      }

      final newFoodLevel = currentFoodLevel - amount;

      // Update device food level
      await updateDevice(deviceId, {'food_level': newFoodLevel});

      // Create the feeding record
      await client.from('feeding_records').insert({
        'pet_id': schedule['pets']['id'],
        'device_id': deviceId,
        'amount': amount,
        'feeding_time': DateTime.now().toIso8601String(),
        'feeding_type': 'scheduled',
        'schedule_id': scheduleId,
        'user_id': schedule['pets']['user_id'],
      });
    } catch (e) {
      debugPrint('Error recording scheduled feeding: $e');
      throw Exception('Failed to record scheduled feeding: $e');
    }
  }

  static Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    if (_forceOfflineMode) {
      return null;
    }
    
    try {
      final response = await client
          .from('devices')
          .select('*')
          .eq('id', deviceId)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error getting device: $e');
      return null;
    }
  }

  // Profile operations
  static Future<Map<String, dynamic>> getProfile() async {
    if (_forceOfflineMode) {
      return {}; // Return empty map in offline mode
    }
    
    final userId = getCurrentUser()?.id;
    if (userId == null) return {};
    
    try {
      final response = await client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return {};
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> profileData) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    final userId = getCurrentUser()?.id;
    if (userId == null) return;
    
    try {
      // Update the profile
      await client
          .from('profiles')
          .update({
            ...profileData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      // If name is being updated, also update auth metadata
      if (profileData.containsKey('name')) {
        await client.auth.updateUser(
          UserAttributes(
            data: {'name': profileData['name']},
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }
} 