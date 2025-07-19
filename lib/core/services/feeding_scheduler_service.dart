import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';
import 'package:pet_feeder/core/services/device_communication_service.dart';

class FeedingSchedulerService {
  static final FeedingSchedulerService _instance = FeedingSchedulerService._internal();
  
  factory FeedingSchedulerService() {
    return _instance;
  }
  
  FeedingSchedulerService._internal();
  
  Timer? _schedulerTimer;
  bool _isRunning = false;
  DateTime? _lastCheck;
  
  void startScheduler() {
    if (_isRunning) return;
    
    _isRunning = true;
    _lastCheck = DateTime.now();
    
    // Check every minute if any scheduled feeding should run
    _schedulerTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkScheduledFeedings();
    });
    
    debugPrint('Feeding scheduler started');
  }
  
  void stopScheduler() {
    _schedulerTimer?.cancel();
    _isRunning = false;
    _lastCheck = null;
    debugPrint('Feeding scheduler stopped');
  }

  // For testing purposes - force check scheduled feedings
  Future<void> forceCheckScheduledFeedings() async {
    debugPrint('Force checking scheduled feedings...');
    await _checkScheduledFeedings();
  }
  
  Future<void> _checkScheduledFeedings() async {
    debugPrint('Checking for scheduled feedings...');
    
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentTimeStr = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
      
      debugPrint('Current time: $currentTimeStr');
      
      // Get all active schedules for the current time
      final schedules = await SupabaseService.client
          .from('feeding_schedules')
          .select('''
            *,
            pets:pet_id (
              id,
              user_id,
              device_key
            )
          ''')
          .lte('start_date', now)
          .gte('end_date', now)
          .eq('start_time', currentTimeStr);

      debugPrint('Found ${schedules.length} schedules for current time');

      // Execute each schedule
      for (final schedule in schedules) {
        await _executeScheduledFeeding(schedule);
      }
    } catch (e) {
      debugPrint('Error checking scheduled feedings: $e');
    }
  }
  
  Future<void> _executeScheduledFeeding(Map<String, dynamic> schedule) async {
    try {
      debugPrint('Executing scheduled feeding for schedule ${schedule['id']}');
      
      // Get device key from the pet
      final deviceKey = schedule['pets']['device_key'];
      if (deviceKey == null) {
        throw Exception('No device assigned to pet');
      }

      final deviceDetails = await SupabaseService.getDevice(deviceKey);
      if (deviceDetails == null) {
        throw Exception('Device not found');
      }

      // Check if there's enough food
      final amount = (schedule['amount'] as num).toDouble();
      final currentFoodLevel = (deviceDetails['food_level'] as num).toDouble();
      
      debugPrint('Device food level: $currentFoodLevel, Required amount: $amount');
      
      if (currentFoodLevel < amount) {
        throw Exception('Not enough food in device. Available: ${currentFoodLevel.toStringAsFixed(1)}g');
      }

      // Send feed command to device - ESP32 will handle database updates
      final result = await DeviceCommunicationService.feedNow(deviceKey, amount);
      
      if (!result['success']) {
        throw Exception(result['message'] ?? 'Failed to execute scheduled feeding');
      }
      
      debugPrint('Successfully executed scheduled feeding for schedule ${schedule['id']}');
    } catch (e) {
      debugPrint('Error executing scheduled feeding: $e');
      throw Exception('Failed to execute scheduled feeding: $e');
    }
  }
} 