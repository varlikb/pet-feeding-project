import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;
  
  // Replace with a real public Supabase instance for development
  static const String _devSupabaseUrl = 'https://gsrjfkviwjukfnzyvnws.supabase.co';
  static const String _devSupabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdzcmpma3Zpd2p1a2Zuenl2bndzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY4Mzg3NjgsImV4cCI6MjA2MjQxNDc2OH0.noGHh9rvtBp0HcCh9hpxcwFDgjCQGP7IAjdu-Vnfzxg';
  
  // Flag to use offline mode directly
  static bool _forceOfflineMode = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Supabase already initialized');
      return;
    }
    
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
        debugPrint('Attempting to load .env file...');
        await dotenv.load().timeout(const Duration(seconds: 2));
        supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
        
        // If either value is empty, use development credentials
        if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
          debugPrint('Missing Supabase credentials in .env file, using development credentials');
          supabaseUrl = _devSupabaseUrl;
          supabaseKey = _devSupabaseKey;
        } else {
          debugPrint('Successfully loaded credentials from .env file');
        }
      } catch (e) {
        // If loading .env fails, use development credentials
        debugPrint('Error loading .env file, using development credentials: $e');
        supabaseUrl = _devSupabaseUrl;
        supabaseKey = _devSupabaseKey;
      }

      debugPrint('Initializing Supabase with URL: $supabaseUrl');

      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: kDebugMode,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection to Supabase timed out. Please check your internet connection.');
        },
      );
      
      _client = Supabase.instance.client;
      
      if (_client == null) {
        throw Exception('Failed to initialize Supabase client');
      }
      
      _isInitialized = true;
      debugPrint('Supabase initialized successfully');
    } on SocketException catch (e) {
      debugPrint('Network error during Supabase initialization: $e');
      throw Exception(
        'Unable to connect to the server. Please check your internet connection and try again.\n'
        'Error details: ${e.message}'
      );
    } on TimeoutException catch (e) {
      debugPrint('Timeout during Supabase initialization: $e');
      throw Exception(
        'Connection timed out. Please check your internet connection and try again.'
      );
    } catch (e) {
      debugPrint('Error in Supabase initialization: $e');
      throw Exception(
        'Failed to initialize connection to the server. Please try again later.\n'
        'Error details: $e'
      );
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
    Map<String, dynamic>? userMetadata,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Use offline login instead.');
    }
    
    try {
      debugPrint('Attempting to sign up with email: $email');
      
      // Check if client is initialized
      if (!_isInitialized) {
        debugPrint('Supabase client not initialized, attempting to initialize...');
        await initialize();
      }

      // Verify client is available
      if (_client == null) {
        throw Exception('Supabase client is not initialized properly');
      }

      debugPrint('Making sign up request...');
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
      );

      debugPrint('Sign up response received: ${response.user != null ? 'Success' : 'Failed'}');

      if (response.user != null) {
        // Create profile for the user
        try {
          await client.from('profiles').insert({
            'id': response.user!.id,
            'name': userMetadata?['name'],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint('Profile created successfully');
        } catch (e) {
          debugPrint('Error creating profile: $e');
          // Don't throw here, as the user is already created
        }
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('AuthException during sign up: ${e.message}');
      if (e.message.contains('User already registered')) {
        throw Exception('This email is already registered. Please sign in instead.');
      }
      rethrow;
    } on SocketException catch (e) {
      debugPrint('SocketException during sign up: ${e.message}');
      throw Exception('Network error. Please check your internet connection and try again.');
    } catch (e) {
      debugPrint('Unexpected error during sign up: $e');
      String message = e.toString();
      
      if (message.contains('host lookup')) {
        throw Exception('Unable to connect to the server. Please check your internet connection or try again later.');
      }
      
      throw Exception('Failed to sign up: $message');
    }
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Use offline login instead.');
    }
    
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Get user profile
      if (response.user != null) {
        final profile = await client
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .single();
            
        // Update user metadata with profile info
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'name': profile['name'],
              'avatar_url': profile['avatar_url'],
            },
          ),
        );
      }

      return response;
    } catch (e) {
      String message = e.toString();
      
      if (message.contains('Invalid login credentials')) {
        throw Exception('Invalid email or password.');
      } else if (message.contains('Email not confirmed')) {
        throw Exception('Please verify your email address before signing in.');
      }
      
      throw Exception('Failed to sign in: $message');
    }
  }

  static Future<AuthResponse> verifyEmail({
    required String email,
    required String token,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode.');
    }
    
    try {
      return await client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
    } catch (e) {
      throw Exception('Invalid or expired verification code. Please try again.');
    }
  }

  static Future<void> signOut() async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      await client.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  static User? getCurrentUser() {
    if (_forceOfflineMode) {
      return null; // Return null in offline mode
    }
    return client.auth.currentUser;
  }
  
  static Future<void> resetPassword({
    required String email,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Password reset not available.');
    }
    
    try {
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: null,  // Use OTP instead of redirect
      );
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  static Future<void> sendOTPForPasswordReset({
    required String email,
  }) async {
    if (_forceOfflineMode) {
      throw Exception('App is running in offline mode. Password reset not available.');
    }
    
    await client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
      emailRedirectTo: null,
      data: {'type': 'recovery'},  // This forces OTP instead of magic link
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
    
    try {
      // First verify the OTP
      final response = await client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      
      // If verification successful, update the password
      if (response.user != null) {
        await client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      } else {
        throw Exception('Verification failed. Please try again.');
      }
      
      return response;
    } catch (e) {
      throw Exception('Invalid or expired verification code. Please try again.');
    }
  }

  static Future<UserResponse> updateUser({
    String? email,
    String? password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await client.auth.updateUser(
        UserAttributes(
          email: email,
          password: password,
          data: data,
        ),
      );
      return response;
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
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
        .select('''
          *,
          devices!inner (
            device_key,
            food_level
          )
        ''')
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
        .select('''
          *,
          devices!inner (
            device_key,
            food_level
          )
        ''')
        .eq('id', id)
        .single();

    return response;
  }

  static Future<Map<String, dynamic>> addPet(Map<String, dynamic> petData) async {
    if (_forceOfflineMode) {
      return {}; // Return empty map in offline mode
    }
    
    try {
      // First check if device exists and is not already assigned
      final deviceKey = petData['device_key'];
      final existingDevice = await client
          .from('devices')
          .select('*')
          .eq('device_key', deviceKey)
          .single();
      
      if (existingDevice == null) {
        throw Exception('Device not found');
      }
      
      // Check if device is already assigned to another pet
      final existingAssignment = await client
          .from('pets')
          .select('id')
          .eq('device_key', deviceKey)
          .maybeSingle();
          
      if (existingAssignment != null) {
        throw Exception('Device is already assigned to another pet');
      }
      
      // Update device as paired
      await client
          .from('devices')
          .update({
            'is_paired': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('device_key', deviceKey);
      
      // Add the pet
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
    
    try {
      // If device_key is being updated, check if new device exists and is not assigned
      if (petData.containsKey('device_key')) {
        final deviceKey = petData['device_key'];
        final existingDevice = await client
            .from('devices')
            .select('*')
            .eq('device_key', deviceKey)
            .single();
        
        if (existingDevice == null) {
          throw Exception('Device not found');
        }
        
        // Check if device is already assigned to another pet
        final existingAssignment = await client
            .from('pets')
            .select('id')
            .eq('device_key', deviceKey)
            .neq('id', id) // Exclude current pet
            .maybeSingle();
            
        if (existingAssignment != null) {
          throw Exception('Device is already assigned to another pet');
        }
      }
      
      await client.from('pets').update(petData).eq('id', id);
    } catch (e) {
      debugPrint('Error updating pet: $e');
      throw Exception('Failed to update pet: $e');
    }
  }

  static Future<void> deletePet(String id) async {
    if (_forceOfflineMode) {
      return; // Just return in offline mode
    }
    
    try {
      // First, delete all related feeding schedules
      await client.from('feeding_schedules').delete().eq('pet_id', id);
      
      // Delete all feeding records
      await client.from('feeding_history').delete().eq('pet_id', id);
      
      // Finally, delete the pet
      await client.from('pets').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting pet: $e');
      throw Exception('Failed to delete pet: $e');
    }
  }

  // Feeding records
  static Future<List<Map<String, dynamic>>> fetchAllFeedingRecords() async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    final userId = getCurrentUser()?.id;
    if (userId == null) return [];
    
    try {
      final response = await client
          .from('feeding_history')
          .select('''
            *,
            devices (
              device_key
            ),
            pets!feeding_history_pet_id_fkey (
              name
            )
          ''')
          .eq('user_id', userId)  // Only get records for the current user's pets
          .order('feeding_time', ascending: false);
  
      return response;
    } catch (e) {
      debugPrint('Error fetching all feeding records: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFeedingRecords(
      String petId, {int limit = 50}) async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    try {
      final response = await client
          .from('feeding_history')
          .select('''
            *,
            devices (
              device_key
            ),
            pets!feeding_history_pet_id_fkey (
              name
            )
          ''')
          .eq('pet_id', petId)
          .order('feeding_time', ascending: false);
  
      return response;
    } catch (e) {
      debugPrint('Error fetching feeding records: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFeedingRecordsForDevice(
      String deviceKey, {int limit = 50}) async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    try {
      final response = await client
          .from('feeding_history')
          .select('''
            *,
            devices (
              device_key
            ),
            pets!feeding_history_pet_id_fkey (
              name
            )
          ''')
          .eq('device_key', deviceKey)
          .order('feeding_time', ascending: false);
  
      return response;
    } catch (e) {
      debugPrint('Error fetching feeding records: $e');
      return [];
    }
  }

  static Future<void> addFeedingRecord(Map<String, dynamic> recordData) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      // Timestamp'leri ISO 8601 formatına çevir
      if (recordData.containsKey('feeding_time')) {
        recordData['feeding_time'] = DateTime.now().toIso8601String();
      }
      if (recordData.containsKey('created_at')) {
        recordData['created_at'] = DateTime.now().toIso8601String();
      }
      if (recordData.containsKey('updated_at')) {
        recordData['updated_at'] = DateTime.now().toIso8601String();
      }
      
      await client
          .from('feeding_history')
          .insert(recordData);
          
      debugPrint('Feeding record added successfully');
    } catch (e) {
      debugPrint('Error adding feeding record: $e');
      throw Exception('Failed to add feeding record: $e');
    }
  }
  
  // Feeding schedules
  static Future<List<Map<String, dynamic>>> fetchFeedingSchedules(String petIdOrDeviceKey) async {
    if (_forceOfflineMode) {
      return []; // Return empty list in offline mode
    }
    
    try {
      debugPrint('Fetching feeding schedules for: $petIdOrDeviceKey');
      
      // Try first as device_key
      var response = await client
          .from('feeding_schedules')
          .select('*')
          .eq('device_key', petIdOrDeviceKey)
          .order('start_time', ascending: true);
      
      // If no results, try as pet_id
      if (response.isEmpty) {
        debugPrint('No schedules found for device_key, trying as pet_id');
        response = await client
            .from('feeding_schedules')
            .select('*')
            .eq('pet_id', petIdOrDeviceKey)
            .order('start_time', ascending: true);
      }
      
      debugPrint('Found ${response.length} feeding schedules');
      return response;
    } catch (e) {
      debugPrint('Error fetching feeding schedules: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>> addFeedingSchedule(Map<String, dynamic> scheduleData) async {
    if (_forceOfflineMode) {
      return {'id': DateTime.now().millisecondsSinceEpoch.toString()};
    }
    
    try {
      // Validate schedule data
      if (!scheduleData.containsKey('device_key')) {
        throw Exception('device_key is required');
      }
      if (!scheduleData.containsKey('start_date') || !scheduleData.containsKey('end_date')) {
        throw Exception('start_date and end_date are required');
      }
      if (!scheduleData.containsKey('frequency')) {
        throw Exception('frequency is required');
      }
      if (!scheduleData.containsKey('start_time')) {
        throw Exception('start_time is required');
      }
      if (!scheduleData.containsKey('amount')) {
        throw Exception('amount is required');
      }

      // Check if device exists
      final device = await getDevice(scheduleData['device_key']);
      if (device == null) {
        throw Exception('Device not found');
      }

      final response = await client
          .from('feeding_schedules')
          .insert(scheduleData)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error adding feeding schedule: $e');
      throw Exception('Failed to add feeding schedule: $e');
    }
  }
  
  static Future<void> updateFeedingSchedule(String id, Map<String, dynamic> scheduleData) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      // Validate schedule data
      if (scheduleData.containsKey('device_key')) {
        final device = await getDevice(scheduleData['device_key']);
        if (device == null) {
          throw Exception('Device not found');
        }
      }

      await client
          .from('feeding_schedules')
          .update(scheduleData)
          .eq('id', id);
    } catch (e) {
      debugPrint('Error updating feeding schedule: $e');
      throw Exception('Failed to update feeding schedule: $e');
    }
  }
  
  static Future<void> deleteFeedingSchedule(String id) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      await client
          .from('feeding_schedules')
          .delete()
          .eq('id', id);
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

  static Future<void> assignPetToDevice(String petId, String deviceKey, bool isPrimary) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      await client.from('pet_device_assignments').insert({
        'pet_id': petId,
        'device_key': deviceKey,
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
      // Check if device already exists
      final existingDevice = await findDeviceByKey(deviceData['device_key']);
      if (existingDevice != null) {
        throw Exception('Device already exists');
      }
      
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

  static Future<void> updateDevice(String deviceKey, Map<String, dynamic> data) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      // Timestamp'i ISO 8601 formatına çevir
      if (data.containsKey('updated_at')) {
        data['updated_at'] = DateTime.now().toIso8601String();
      }
      if (data.containsKey('last_feeding')) {
        data['last_feeding'] = DateTime.now().toIso8601String();
      }
      
      await client
          .from('devices')
          .update(data)
          .eq('device_key', deviceKey);
          
      debugPrint('Device updated successfully: $deviceKey');
    } catch (e) {
      debugPrint('Error updating device: $e');
      throw Exception('Failed to update device: $e');
    }
  }

  static Future<void> deleteDevice(String deviceKey) async {
    if (_forceOfflineMode) {
      return;
    }
    
    try {
      // First remove device from any pets
      await client
          .from('pets')
          .update({'device_key': null})
          .eq('device_key', deviceKey);
          
      // Then delete the device
      await client
          .from('devices')
          .delete()
          .eq('device_key', deviceKey);
    } catch (e) {
      debugPrint('Error deleting device: $e');
      throw Exception('Failed to delete device: $e');
    }
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
      // Önce pet'in device_key'ini al
      final pet = await client
          .from('pets')
          .select('device_key')
          .eq('id', petId)
          .single();
      
      if (pet == null || pet['device_key'] == null) {
        return null;
      }

      // Device_key ile cihaz detaylarını al
      final device = await client
          .from('devices')
          .select('*')
          .eq('device_key', pet['device_key'])
          .single();
      
      return device;
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
          .select('*, pets!inner(*)')
          .eq('id', scheduleId)
          .single();
      
      if (schedule == null) {
        throw Exception('Schedule not found');
      }

      // Get current device details
      final deviceKey = schedule['pets']['device_key'];
      final deviceDetails = await getDevice(deviceKey);
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
      await updateDevice(deviceKey, {'food_level': newFoodLevel});

      // Create the feeding record
      await client.from('feeding_records').insert({
        'pet_id': schedule['pets']['id'],
        'device_key': deviceKey,
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

  static Future<Map<String, dynamic>?> getDevice(String deviceKey) async {
    if (_forceOfflineMode) {
      return null;
    }
    
    try {
      debugPrint('Getting device details from Supabase for device key: $deviceKey');
      final response = await client
          .from('devices')
          .select('*')
          .eq('device_key', deviceKey)
          .single();
      
      debugPrint('Device response from Supabase: $response');
      
      // Add missing but important fields with default values if they don't exist
      if (response != null) {
        Map<String, dynamic> enhancedDevice = Map<String, dynamic>.from(response);
        
        // Make sure we have a network name value
        if (!enhancedDevice.containsKey('wifi_ssid') || enhancedDevice['wifi_ssid'] == null) {
          // Try to get network name from ESP32
          try {
            String? deviceIP = enhancedDevice['ip_address'];
            if (deviceIP != null && deviceIP.isNotEmpty) {
              // Only try to get ESP32 info if we have an IP
              final deviceInfo = await client.functions.invoke('get_device_info', 
                body: {'device_ip': deviceIP});
              
              if (deviceInfo.data != null && deviceInfo.data['ssid'] != null) {
                enhancedDevice['wifi_ssid'] = deviceInfo.data['ssid'];
                debugPrint('Updated wifi_ssid from ESP32: ${deviceInfo.data['ssid']}');
              }
            }
          } catch (e) {
            debugPrint('Error getting WiFi info from ESP32: $e');
          }
        }
        
        // Add default network name if still missing
        if (!enhancedDevice.containsKey('wifi_ssid') || enhancedDevice['wifi_ssid'] == null) {
          enhancedDevice['wifi_ssid'] = 'Unknown Network';
        }
        
        // Log the enhanced device data
        debugPrint('Enhanced device data: $enhancedDevice');
        return enhancedDevice;
      }
      
      return response;
    } catch (e) {
      debugPrint('Error getting device: $e');
      return null;
    }
  }

  // Profile operations
  static Future<Map<String, dynamic>> getProfile() async {
    if (_forceOfflineMode) {
      return {};
    }
    
    final userId = getCurrentUser()?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to get profile: $e');
    }
  }

  static Future<void> updateProfile({
    String? name,
    String? avatarUrl,
  }) async {
    if (_forceOfflineMode) {
      return;
    }
    
    final userId = getCurrentUser()?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (name != null) updates['name'] = name;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      
      // Update profile
      await client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
          
      // Update auth metadata
      await client.auth.updateUser(
        UserAttributes(
          data: {
            if (name != null) 'name': name,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Get available devices that are not paired
  static Future<List<Map<String, dynamic>>> getAvailableDevices() async {
    try {
      debugPrint('Fetching available devices...');
      final response = await client
          .from('devices')
          .select('''
            *,
            pets (
              id,
              name,
              user_id
            )
          ''')
          .eq('is_paired', false)
          .order('created_at', ascending: false);
      
      debugPrint('Available devices: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting available devices: $e');
      throw Exception('Error getting available devices: $e');
    }
  }

  // Get user's paired devices
  static Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('Fetching user devices...');
      final response = await client
          .from('devices')
          .select('''
            *,
            pets (
              id,
              name,
              user_id
            )
          ''')
          .eq('is_paired', true)
          .eq('pets.user_id', userId)
          .order('created_at', ascending: false);
      
      debugPrint('User devices: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting user devices: $e');
      throw Exception('Error getting user devices: $e');
    }
  }

  // Pair a device
  static Future<void> pairDevice(String deviceKey) async {
    try {
      debugPrint('Pairing device: $deviceKey');
      final userId = getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if device exists and is available
      final device = await client
          .from('devices')
          .select()
          .eq('device_key', deviceKey)
          .eq('is_paired', false)
          .maybeSingle();
      
      if (device == null) {
        throw Exception('Device not found or already paired');
      }

      // Update device as paired
      await client
          .from('devices')
          .update({
            'is_paired': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('device_key', deviceKey);
      
      debugPrint('Device paired successfully');
    } catch (e) {
      debugPrint('Error pairing device: $e');
      throw Exception('Failed to pair device: $e');
    }
  }
} 