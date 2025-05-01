import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

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
  
  Future<void> _checkScheduledFeedings() async {
    debugPrint('Checking for scheduled feedings...');
    
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentTimeStr = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';
      
      // Get all active schedules for the current time
      // Join with pets first, then to pet_device_assignments
      final schedules = await SupabaseService.client
          .from('feeding_schedules')
          .select('''
            *,
            pets:pet_id (
              id,
              user_id,
              pet_device_assignments!inner (
                device_id,
                is_primary
              )
            )
          ''')
          .lte('start_date', now)
          .gte('end_date', now)
          .eq('start_time', currentTimeStr)
          .eq('pets.pet_device_assignments.is_primary', true);

      for (final schedule in schedules) {
        try {
          final frequency = schedule['frequency'] as String;
          final lastCheck = _lastCheck ?? now.subtract(const Duration(minutes: 1));
          
          // For hourly schedules, check if we've crossed an hour boundary
          if (frequency == 'hour' && 
              lastCheck.hour != now.hour) {
            await _executeScheduledFeeding(schedule);
          }
          // For daily schedules, always execute at the scheduled time
          else if (frequency == 'day') {
            await _executeScheduledFeeding(schedule);
          }
          // For twice-daily schedules, check both morning and evening times
          else if (frequency == 'twice-daily') {
            await _executeScheduledFeeding(schedule);
          }
        } catch (e) {
          debugPrint('Error executing scheduled feeding: $e');
        }
      }
      
      _lastCheck = now;
    } catch (e) {
      debugPrint('Error checking scheduled feedings: $e');
    }
  }
  
  Future<void> _executeScheduledFeeding(Map<String, dynamic> schedule) async {
    try {
      // Get device ID from the nested pet_device_assignments
      final deviceId = schedule['pets']['pet_device_assignments'][0]['device_id'];
      final deviceDetails = await SupabaseService.getDevice(deviceId);
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
      await SupabaseService.updateDevice(deviceId, {'food_level': newFoodLevel});

      // Create the feeding record
      await SupabaseService.client.from('feeding_records').insert({
        'pet_id': schedule['pet_id'],
        'device_id': deviceId,
        'amount': amount,
        'feeding_time': DateTime.now().toIso8601String(),
        'feeding_type': 'scheduled',
        'schedule_id': schedule['id'],
        'user_id': schedule['pets']['user_id'],
      });
      
      debugPrint('Successfully executed scheduled feeding for schedule ${schedule['id']}');
    } catch (e) {
      debugPrint('Error executing scheduled feeding: $e');
      throw Exception('Failed to execute scheduled feeding: $e');
    }
  }
} 