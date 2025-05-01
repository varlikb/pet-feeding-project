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
      final devices = await SupabaseService.client
          .from('devices')
          .select()
          .eq('device_key', deviceKey)
          .eq('is_paired', false)
          .filter('owner_id', 'is', null);
      
      if (devices.isEmpty) {
        throw Exception('Device not found or not available for pairing.');
      }
      
      return devices[0];
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

      // Check device availability first
      final device = await checkDeviceAvailability(deviceKey);
      if (device == null) {
        throw Exception('Device not found or not available for pairing');
      }

      // Pair the device
      final response = await SupabaseService.client
          .from('devices')
          .update({
            'owner_id': userId,
            'is_paired': true,
            'last_paired_at': DateTime.now().toIso8601String(),
          })
          .eq('device_key', deviceKey)
          .eq('is_paired', false) // Extra check to prevent race conditions
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error pairing device: $e');
      rethrow;
    }
  }

  // Unpair a device
  static Future<void> unpairDevice(String deviceId) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await SupabaseService.client
          .from('devices')
          .update({
            'owner_id': null,
            'is_paired': false,
            'last_paired_at': null,
          })
          .eq('id', deviceId)
          .eq('owner_id', userId); // Ensure user owns the device
    } catch (e) {
      debugPrint('Error unpairing device: $e');
      rethrow;
    }
  }

  // Get user's paired devices
  static Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('devices')
          .select()
          .eq('owner_id', userId)
          .eq('is_paired', true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting user devices: $e');
      return [];
    }
  }

  // Get a specific device by ID
  static Future<Map<String, dynamic>?> getDeviceById(String deviceId) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('devices')
          .select()
          .eq('id', deviceId)
          .eq('owner_id', userId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error getting device: $e');
      return null;
    }
  }

  // Admin: Add new device to the system
  static Future<Map<String, dynamic>> addDevice(Map<String, dynamic> deviceData) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is admin
      final isAdmin = await SupabaseService.client
          .from('admin_users')
          .select()
          .eq('user_id', userId)
          .single();

      if (isAdmin == null) {
        throw Exception('Only administrators can add devices');
      }

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
          .select('*')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting all devices: $e');
      return [];
    }
  }
} 