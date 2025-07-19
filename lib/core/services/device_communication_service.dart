import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceCommunicationService {
  static const String realtimeChannel = "device_channel";
  
  // Device status endpoints
  static const String _statusEndpoint = '/status';
  static const String _scheduleEndpoint = '/schedule';
  static const String _disableScheduleEndpoint = '/cancel-schedule';
  static const String _setTimeEndpoint = '/set-time';
  
  // SharedPreferences key for device IPs
  static const String _deviceIPsKey = 'device_ips';

  // Connect to device's WiFi access point
  static Future<bool> connectToDeviceAP(String apName) async {
    try {
      debugPrint('Attempting to connect to device AP: $apName');
      // In a real implementation, this would use platform-specific code to connect to WiFi
      // For now, we'll simulate success
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } catch (e) {
      debugPrint('Error connecting to device AP: $e');
      return false;
    }
  }

  // Send WiFi credentials through direct HTTP connection to ESP32
  static Future<bool> sendWifiCredentials(String deviceKey, String ssid, String password) async {
    try {
      debugPrint('Sending WiFi credentials to ESP32...');
      
      // ESP32's default IP address in AP mode
      const String esp32IP = '192.168.4.1';
      
      final response = await http.post(
        Uri.parse('http://$esp32IP/wifi'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'ssid': ssid,
          'password': password,
          'device_key': deviceKey,
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('ESP32 response status: ${response.statusCode}');
      debugPrint('ESP32 response body: ${response.body}');

      if (response.statusCode == 200) {
        // Wait a bit for the device to connect to new WiFi
        await Future.delayed(const Duration(seconds: 5));
        
        // Try to check if device is online through Supabase
        try {
          final device = await SupabaseService.getDevice(deviceKey);
          if (device != null && device['status'] == 'online') {
            debugPrint('Device connected successfully and is online in Supabase');
            return true;
          }
        } catch (e) {
          debugPrint('Error checking device status in Supabase: $e');
          // Even if Supabase check fails, we still return true if ESP32 accepted the credentials
          return true;
        }
      }
      
      debugPrint('Failed to send WiFi credentials to ESP32');
      return false;
    } catch (e) {
      debugPrint('Error sending WiFi credentials: $e');
      return false;
    }
  }

  // Send feed now command through direct HTTP request to device
  static Future<Map<String, dynamic>> feedNow(String deviceKey, double amount) async {
    try {
      debugPrint('========= FEED NOW COMMAND =========');
      debugPrint('Device Key: $deviceKey');
      debugPrint('Amount: ${amount}g');
      
      // First try getting device details from Supabase to get the most up-to-date IP address
      final device = await SupabaseService.getDevice(deviceKey);
      if (device == null) {
        debugPrint('ERROR: Device not found in database');
        return {
          'success': false,
          'message': 'Device not found',
          'error': 'DEVICE_NOT_FOUND'
        };
      }

      // Get device IP - first from Supabase then fallback to local storage
      String? deviceIP = device['ip_address'];
      
      // If IP is missing from Supabase, try local storage
      if (deviceIP == null || deviceIP.isEmpty) {
        deviceIP = await getDeviceIP(deviceKey);
        
        if (deviceIP == null || deviceIP.isEmpty) {
          debugPrint('ERROR: Device IP address not available');
          return {
            'success': false,
            'message': 'Device IP address not available',
            'error': 'IP_NOT_AVAILABLE'
          };
        }
      } else {
        // Save the IP from Supabase to local storage for future use
        await saveDeviceIP(deviceKey, deviceIP);
      }
      
      debugPrint('Using device IP: $deviceIP');

      // Test connection to device before trying to feed
      final isConnected = await testDeviceConnection(deviceIP);
      if (!isConnected) {
        debugPrint('ERROR: Cannot connect to device');
        return {
          'success': false,
          'message': 'Cannot connect to device at $deviceIP',
          'error': 'CONNECTION_FAILED'
        };
      }

      debugPrint('Device connection test successful');

      // Get current food level from device itself instead of relying on Supabase data
      final status = await getDeviceStatus(deviceIP);
      final double currentFoodLevel = status != null ? 
        (status['food_level'] is int ? (status['food_level'] as int).toDouble() : (status['food_level'] ?? 0.0)) : 0.0;
      
      debugPrint('Current food level from device: ${currentFoodLevel}%');
      debugPrint('Device status response: $status');

      // Update device info in database with latest data from ESP32
      if (status != null) {
        try {
          Map<String, dynamic> updates = {
            'food_level': currentFoodLevel,
            'last_online': DateTime.now().toIso8601String(),
          };
          
          // Update WiFi network name if we got it
          if (status.containsKey('ssid') && status['ssid'] != null) {
            updates['wifi_ssid'] = status['ssid'];
            debugPrint('Updating WiFi SSID in database: ${status['ssid']}');
          }
          
          await SupabaseService.updateDevice(deviceKey, updates);
          debugPrint('Updated device info in database with latest ESP32 data');
        } catch (e) {
          debugPrint('Error updating device info in database: $e');
          // Continue with feeding even if database update fails
        }
      }

      // Temporarily disable food level check for testing
      // TODO: Re-enable this check once food level measurement is working properly
      /*
      if (status != null && currentFoodLevel < 10) { // Check if food level is below 10%
        debugPrint('WARNING: Low food level detected');
        return {
          'success': false,
          'message': 'Not enough food. Current level: ${currentFoodLevel.toStringAsFixed(1)}%',
          'error': 'INSUFFICIENT_FOOD'
        };
      }
      */
      
      debugPrint('Food level check bypassed for testing');
      
      // Send feed command directly to the device
      final uri = Uri.parse('http://$deviceIP/feed');
      debugPrint('Sending POST request to: $uri');
      debugPrint('Request body: amount=${amount}');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'amount': amount.toString(),
        },
      ).timeout(const Duration(seconds: 15)); // Increased timeout for feeding process

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Try to parse the response
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('Feed command response parsed successfully');
          debugPrint('Response data: $responseData');
          
          if (responseData['success'] == true) {
            debugPrint('✅ Feed command sent successfully - ESP confirmed start');
            
            return {
              'success': true,
              'message': 'Feed now command sent successfully',
              'type': responseData['type'] ?? 'feed_now',
              'amount': responseData['amount'] ?? amount,
            };
          } else {
            debugPrint('❌ ESP returned error: ${responseData['error']}');
            return {
              'success': false,
              'message': responseData['error'] ?? 'Unknown error from device',
              'error': 'DEVICE_ERROR'
            };
          }
        } catch (e) {
          // If response is not JSON, treat it as success if status code is 200
          debugPrint('Response not JSON, treating as success: $e');
          return {
            'success': true,
            'message': 'Feed command sent successfully',
            'response_body': response.body,
          };
        }
      } else {
        debugPrint('❌ Feed command failed with HTTP error');
        return {
          'success': false,
          'message': 'Feed command failed. HTTP Status: ${response.statusCode}',
          'error': 'HTTP_ERROR',
          'status_code': response.statusCode,
          'response_body': response.body,
        };
      }
    } catch (e) {
      debugPrint('❌ Exception in feedNow: $e');
      return {
        'success': false,
        'message': 'Error sending feed command: $e',
        'error': 'SYSTEM_ERROR'
      };
    }
  }

  // Test device connection
  static Future<bool> testDeviceConnection(String deviceIP) async {
    try {
      debugPrint('Testing connection to device at $deviceIP...');
      
      final uri = Uri.parse('http://$deviceIP$_statusEndpoint');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Status check timed out');
        },
      );

      debugPrint('Status check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error testing device connection: $e');
      return false;
    }
  }

  // Send scheduled feeding command through direct HTTP request
  static Future<bool> sendScheduleCommand(String deviceKey, {
    required String frequency,
    required double amount,
    required String startTime,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('==========================================================');
      debugPrint('SENDING SCHEDULE COMMAND TO ESP32');
      debugPrint('Device Key: $deviceKey');
      debugPrint('Frequency: $frequency');
      debugPrint('Amount: $amount grams');
      debugPrint('Start Time: $startTime');
      debugPrint('Start Date: ${startDate?.toIso8601String() ?? "Not specified"}');
      debugPrint('End Date: ${endDate?.toIso8601String() ?? "Not specified"}');
      debugPrint('==========================================================');
      
      // Get device IP from local storage
      String? deviceIP = await getDeviceIP(deviceKey);
      if (deviceIP == null || deviceIP.isEmpty) {
        // Get device details from database to check if IP is available there
        final device = await SupabaseService.getDevice(deviceKey);
        if (device == null) {
          debugPrint('Device not found');
          return false;
        }

        deviceIP = device['ip_address'];
        if (deviceIP == null || deviceIP.isEmpty) {
          debugPrint('Device IP address not available');
          return false;
        }
        
        // Save the IP for future use
        await saveDeviceIP(deviceKey, deviceIP);
      }
      
      // Parse time string to get hour and minute
      final timeParts = startTime.split(':');
      if (timeParts.length != 2) {
        debugPrint('Invalid time format: $startTime');
        return false;
      }
      
      int hour = int.tryParse(timeParts[0]) ?? 0;
      int minute = int.tryParse(timeParts[1]) ?? 0;
      
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        debugPrint('Invalid time components: hour=$hour, minute=$minute');
        return false;
      }
      
      // Prepare request body
      Map<String, String> requestBody = {};
      
      // Handle minute-based schedules differently - direct approach
      if (frequency == 'minute') {
        debugPrint('SPECIAL CONFIGURATION FOR MINUTE-BASED SCHEDULE');
        
        // Explicitly configure ESP for minute-based feeding
        requestBody = {
          'interval_mode': 'true',          // Tell ESP32 this is an interval-based schedule
          'interval_seconds': '60',         // Set interval to 60 seconds
          'interval_unit': 'seconds',       // Specify unit as seconds
          'display_format': 'seconds',      // Force display as seconds
          'auto_reset': 'true',             // Reset timer after each feeding
          'amount': amount.toString(),      // Amount to feed in grams
          'frequency': 'minute',            // Keep frequency info for database
        };
        
        debugPrint('Sending RAW interval configuration to ESP32:');
        requestBody.forEach((key, value) {
          debugPrint('  $key: $value');
        });
        
        // Send direct HTTP command to ESP32
        final uri = Uri.parse('http://$deviceIP/set_interval_feed');
        debugPrint('Sending request to: $uri');
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: requestBody,
        ).timeout(const Duration(seconds: 10));
        
        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        
        return response.statusCode == 200;
      } 
      // Regular schedule (daily/hourly)
      else {
        requestBody = {
          'hour': hour.toString(),
          'minute': minute.toString(),
          'amount': amount.toString(),
          'frequency': frequency,
        };
        
        // Add start date if provided
        if (startDate != null) {
          requestBody['start_date'] = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
        }
        
        // Add end date if provided
        if (endDate != null) {
          requestBody['end_date'] = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
        }
        
        // Send schedule command directly to the device
        final uri = Uri.parse('http://$deviceIP/schedule');
        debugPrint('Sending request to: $uri');
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: requestBody,
        ).timeout(const Duration(seconds: 10));

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        
        return response.statusCode == 200;
      }
    } catch (e) {
      debugPrint('Error sending schedule command: $e');
      return false;
    }
  }
  
  // Disable schedule
  static Future<bool> disableSchedule(String? deviceIP) async {
    try {
      if (deviceIP == null || deviceIP.isEmpty) {
        debugPrint('Cannot disable schedule: Device IP is null or empty');
        return false;
      }
      
      debugPrint('Disabling schedule on device at $deviceIP...');
      
      final uri = Uri.parse('http://$deviceIP$_disableScheduleEndpoint');
      debugPrint('Sending cancel schedule request to: $uri');
      
      final response = await http.post(
        uri,
      ).timeout(const Duration(seconds: 5));

      debugPrint('Disable schedule response status: ${response.statusCode}');
      debugPrint('Disable schedule response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('Schedule disabled successfully');
        return true;
      } else {
        debugPrint('Failed to disable schedule. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error disabling schedule: $e');
      return false;
    }
  }
  
  // Get device status
  static Future<Map<String, dynamic>?> getDeviceStatus(String ipAddress) async {
    try {
      debugPrint('Getting device status from $ipAddress...');
      
      final uri = Uri.parse('http://$ipAddress$_statusEndpoint');
      debugPrint('Device status request URL: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      
      debugPrint('Device status response status code: ${response.statusCode}');
      debugPrint('Device status response body: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          debugPrint('Successfully parsed device status response: $jsonData');
          
          // Create a standardized status map with defaults for missing values
          final Map<String, dynamic> statusMap = {
            'ip': ipAddress,
            'connected': true,
            'current_time': DateTime.now().toString(),
          };
          
          // Only override defaults if the response contains the values
          if (jsonData is Map<String, dynamic>) {
            if (jsonData.containsKey('device_key')) statusMap['device_key'] = jsonData['device_key'];
            if (jsonData.containsKey('food_level')) statusMap['food_level'] = jsonData['food_level'];
            if (jsonData.containsKey('wifi_signal')) statusMap['wifi_signal'] = jsonData['wifi_signal'];
            if (jsonData.containsKey('rssi')) statusMap['rssi'] = jsonData['rssi'];
            if (jsonData.containsKey('ip_address')) statusMap['ip_address'] = jsonData['ip_address'];
            if (jsonData.containsKey('ssid') && jsonData['ssid'] != null && jsonData['ssid'].toString() != 'Unknown') {
              statusMap['ssid'] = jsonData['ssid'];
            }
            if (jsonData.containsKey('current_time')) statusMap['current_time'] = jsonData['current_time'];
            if (jsonData.containsKey('is_paired')) statusMap['is_paired'] = jsonData['is_paired'];
            if (jsonData.containsKey('connected')) statusMap['connected'] = jsonData['connected'];
            if (jsonData.containsKey('device_uptime_seconds')) {
              statusMap['device_uptime_seconds'] = jsonData['device_uptime_seconds'];
            }
          }
          
          debugPrint('Returning standardized status map: $statusMap');
          return statusMap;
        } catch (e) {
          debugPrint('Error parsing device status JSON: $e');
          // Return a basic status object on parsing error
          return {
            'ip': ipAddress,
            'connected': true,
            'ssid': 'JSON Error: ${e.toString().substring(0, 50)}...',
            'current_time': DateTime.now().toString(),
            'error': 'JSON_PARSE_ERROR'
          };
        }
      } else {
        debugPrint('Failed to get device status. HTTP Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting device status: $e');
      return null;
    }
  }
  
  // Set device timezone
  static Future<bool> setDeviceTimezone(String? deviceIP, {int timezone = 3}) async {
    try {
      if (deviceIP == null || deviceIP.isEmpty) {
        debugPrint('Cannot set timezone: Device IP is null or empty');
        return false;
      }
      
      debugPrint('Setting device timezone to UTC+$timezone...');
      
      final uri = Uri.parse('http://$deviceIP$_setTimeEndpoint');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timezone': timezone,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('Timezone set successfully');
        return true;
      } else {
        debugPrint('Failed to set timezone. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error setting timezone: $e');
      return false;
    }
  }

  // Save device IP
  static Future<void> saveDeviceIP(String deviceKey, String ipAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceIPs = prefs.getString(_deviceIPsKey);
      
      Map<String, dynamic> ipMap = {};
      if (deviceIPs != null) {
        ipMap = jsonDecode(deviceIPs) as Map<String, dynamic>;
      }
      
      ipMap[deviceKey] = ipAddress;
      
      await prefs.setString(_deviceIPsKey, jsonEncode(ipMap));
      debugPrint('Device IP saved: $deviceKey -> $ipAddress');
    } catch (e) {
      debugPrint('Error saving device IP: $e');
    }
  }

  // Get device IP
  static Future<String?> getDeviceIP(String deviceKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceIPs = prefs.getString(_deviceIPsKey);
      
      if (deviceIPs != null) {
        final ipMap = jsonDecode(deviceIPs) as Map<String, dynamic>;
        return ipMap[deviceKey] as String?;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting device IP: $e');
      return null;
    }
  }
  
  // Get schedule status
  static Future<Map<String, dynamic>?> getScheduleStatus(String? deviceIP) async {
    try {
      if (deviceIP == null || deviceIP.isEmpty) {
        debugPrint('Cannot get schedule status: Device IP is null or empty');
        return null;
      }
      
      debugPrint('Getting schedule status from $deviceIP...');
      
      // First try to get interval status (for minute-based feeding)
      try {
        final intervalUri = Uri.parse('http://$deviceIP/interval_status');
        debugPrint('Trying interval status request URL: $intervalUri');
        
        final intervalResponse = await http.get(intervalUri).timeout(const Duration(seconds: 3));
        
        if (intervalResponse.statusCode == 200) {
          final data = jsonDecode(intervalResponse.body);
          debugPrint('Interval status retrieved successfully: ${intervalResponse.body}');
          
          if (data is Map<String, dynamic> && data.containsKey('interval_active') && data['interval_active'] == true) {
            debugPrint('Found active interval-based feeding with data: $data');
            
            // Create enhanced data for interval mode
            Map<String, dynamic> enhancedData = {
              'active': true,
              'frequency': 'minute',
              'amount': data['amount'] ?? 50.0,
              'interval_seconds': data['interval_seconds'] ?? 60,
            };
            
            // Add seconds remaining if available
            if (data.containsKey('seconds_remaining')) {
              enhancedData['seconds_remaining'] = data['seconds_remaining'];
              debugPrint('Seconds remaining: ${data['seconds_remaining']}');
            }
            
            return enhancedData;
          }
        }
      } catch (e) {
        debugPrint('Error getting interval status (this is expected if not in interval mode): $e');
        // Continue to regular schedule check
      }
      
      // Then try regular schedule status
      final scheduleUri = Uri.parse('http://$deviceIP$_scheduleEndpoint');
      debugPrint('Schedule status request URL: $scheduleUri');
      
      final response = await http.get(scheduleUri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Schedule status retrieved successfully: ${response.body}');
        
        // Add debugging logs for specific fields important for schedule info
        if (data is Map<String, dynamic>) {
          debugPrint('ESP32 Schedule raw data: $data');
          
          // Enhance the data to make it more usable by our app
          Map<String, dynamic> enhancedData = Map<String, dynamic>.from(data);
          
          // Make sure 'active' is always true for valid schedule data from ESP32
          enhancedData['active'] = true;
          
          return enhancedData;
        }
        
        return data;
      } else {
        debugPrint('Failed to get schedule status. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting schedule status: $e');
      return null;
    }
  }

  // Check device health through heartbeat endpoint
  static Future<Map<String, dynamic>?> checkDeviceHealth(String deviceKey) async {
    try {
      // Get device IP from local storage
      String? deviceIP = await getDeviceIP(deviceKey);
      if (deviceIP == null || deviceIP.isEmpty) {
        // Get device details from database
        final device = await SupabaseService.getDevice(deviceKey);
        if (device == null) return null;

        deviceIP = device['ip_address'];
        if (deviceIP == null || deviceIP.isEmpty) {
          debugPrint('Device IP address not available');
          return null;
        }
        
        // Save the IP for future use
        await saveDeviceIP(deviceKey, deviceIP);
      }

      // Send a request to the device's heartbeat endpoint
      final uri = Uri.parse('http://$deviceIP/heartbeat');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('Device heartbeat successful');
        
        // Get detailed status
        final status = await getDeviceStatus(deviceIP);
        if (status != null) {
          // Safe casting for food_level
          final foodLevel = status['food_level'];
          final double foodLevelDouble = foodLevel is int ? foodLevel.toDouble() : (foodLevel ?? 0.0);
          
          return {
            'status': 'online',
            'food_level': foodLevelDouble,
            'last_online': DateTime.now().toIso8601String(),
            'wifi_signal': status['wifi_signal'] ?? 0,
          };
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error checking device health: $e');
      return null;
    }
  }
} 