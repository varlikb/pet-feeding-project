import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  // Check if a device exists and is available for pairing
  static Future<Map<String, dynamic>?> checkDeviceAvailability(String deviceKey) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('Please sign in to verify a device');
      }

      // Check if the device exists and is available
      final device = await SupabaseService.client
          .from('devices')
          .select()
          .eq('device_key', deviceKey)
          .eq('is_paired', false)
          .maybeSingle();
      
      if (device == null) {
        throw Exception('Device not found or not available for pairing.');
      }
      
      return device;
    } catch (e) {
      debugPrint('Error checking device availability: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unable to verify device. Please try again later.');
    }
  }

  // Pair a device with a user
  static Future<Map<String, dynamic>> pairDevice(String deviceKey) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Call the verify_device RPC function
      final response = await SupabaseService.client
          .rpc('verify_device', params: {'p_device_key': deviceKey})
          .select()
          .single();

      if (response['success'] == false) {
        throw Exception(response['message']);
      }

      return response['device_info'];
    } catch (e) {
      debugPrint('Error pairing device: $e');
      rethrow;
    }
  }

  // Unpair a device
  static Future<void> unpairDevice(String deviceKey) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // First check if any pets are using this device
      final petsUsingDevice = await SupabaseService.client
          .from('pets')
          .select('id, name')
          .eq('device_key', deviceKey)
          .eq('user_id', userId);
          
      if (petsUsingDevice.isNotEmpty) {
        final petNames = (petsUsingDevice as List).map((p) => p['name']).join(', ');
        throw Exception('Cannot unpair device. It is being used by: $petNames');
      }

      await SupabaseService.client
          .from('devices')
          .update({
            'is_paired': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('device_key', deviceKey);
    } catch (e) {
      debugPrint('Error unpairing device: $e');
      rethrow;
    }
  }

  // Get user's paired devices
  static Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      return await SupabaseService.getUserDevices();
    } catch (e) {
      debugPrint('Error getting user devices: $e');
      return [];
    }
  }

  // Get available devices for pairing
  static Future<List<Map<String, dynamic>>> getAvailableDevices() async {
    try {
      return await SupabaseService.getAvailableDevices();
    } catch (e) {
      debugPrint('Error getting available devices: $e');
      return [];
    }
  }

  // Get a specific device by key
  static Future<Map<String, dynamic>> getDeviceByKey(String deviceKey) async {
    try {
      final response = await SupabaseService.client
          .from('devices')
          .select()
          .eq('device_key', deviceKey)
          .single();
      return response;
    } catch (e) {
      throw Exception('Error getting device: $e');
    }
  }

  // Admin: Add new device to the system
  static Future<Map<String, dynamic>> addDevice(Map<String, dynamic> deviceData) async {
    try {
      // Validate required fields
      if (deviceData['name'] == null || deviceData['name'].toString().trim().isEmpty) {
        throw Exception('Device name is required');
      }
      if (deviceData['device_key'] == null || deviceData['device_key'].toString().trim().isEmpty) {
        throw Exception('Device key is required');
      }

      // Only include essential fields for device creation
      final newDevice = {
        'name': deviceData['name'],
        'device_key': deviceData['device_key'],
        'food_level': deviceData['food_level'] ?? 1000, // Default to 1000g
        'is_paired': false,
      };

      final response = await SupabaseService.client
          .from('devices')
          .insert(newDevice)
          .select()
          .single();

      return response;
    } catch (e) {
      if (e.toString().contains('devices_device_key_key')) {
        throw Exception('A device with this key already exists');
      }
      debugPrint('Error adding device: $e');
      rethrow;
    }
  }

  // Admin: Get all devices
  static Future<List<Map<String, dynamic>>> getAllDevices() async {
    try {
      final response = await SupabaseService.client
          .from('devices')
          .select('''
            *,
            pets (
              id,
              name,
              user_id
            )
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting all devices: $e');
      return [];
    }
  }
} 