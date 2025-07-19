import 'package:flutter/material.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class Device {
  final String deviceKey;
  final String name;
  final String userId;
  final double foodLevel;
  final DateTime? lastFeeding;

  Device({
    required this.deviceKey,
    required this.name,
    required this.userId,
    required this.foodLevel,
    this.lastFeeding,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceKey: json['device_key'] as String,
      name: json['name'] as String,
      userId: json['user_id'] as String,
      foodLevel: (json['food_level'] as num).toDouble(),
      lastFeeding: json['last_feeding'] != null 
          ? DateTime.parse(json['last_feeding'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_key': deviceKey,
      'name': name,
      'user_id': userId,
      'food_level': foodLevel,
      'last_feeding': lastFeeding?.toIso8601String(),
    };
  }
}

class FeedingSchedule {
  final String id;
  final String deviceKey;
  final DateTime startDate;
  final DateTime endDate;
  final String frequency; // 'hour' or 'day'
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double amount;

  FeedingSchedule({
    required this.id,
    required this.deviceKey,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required this.startTime,
    required this.endTime,
    required this.amount,
  });
  
  factory FeedingSchedule.fromJson(Map<String, dynamic> json) {
    return FeedingSchedule(
      id: json['id'] as String,
      deviceKey: json['device_key'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      frequency: json['frequency'] as String,
      startTime: TimeOfDay(
        hour: int.parse((json['start_time'] as String).split(':')[0]),
        minute: int.parse((json['start_time'] as String).split(':')[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse((json['end_time'] as String).split(':')[0]),
        minute: int.parse((json['end_time'] as String).split(':')[1]),
      ),
      amount: (json['amount'] as num).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_key': deviceKey,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'frequency': frequency,
      'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'amount': amount,
    };
  }
}

class DeviceProvider extends ChangeNotifier {
  List<Device> _devices = [];
  Device? _currentDevice;
  List<FeedingSchedule> _schedules = [];
  bool _isFeeding = false;
  bool _isLoading = false;

  List<Device> get devices => _devices;
  Device? get currentDevice => _currentDevice;
  List<FeedingSchedule> get schedules => List.unmodifiable(_schedules);
  bool get isFeeding => _isFeeding;
  bool get isLoading => _isLoading;
  double get foodLevel => _currentDevice?.foodLevel ?? 100.0;
  DateTime? get lastFeeding => _currentDevice?.lastFeeding;

  // Fetch devices from Supabase
  Future<void> fetchDevices() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      debugPrint('Fetching devices...');
      final data = await SupabaseService.fetchDevices();
      debugPrint('Fetched ${data.length} devices');
      
      // Debug print each device
      for (var device in data) {
        debugPrint('Device: ${device.toString()}');
      }
      
      _devices = data.map((json) => Device.fromJson(json)).toList();
      
      // Sort devices by last update time if available
      _devices.sort((a, b) {
        if (a.lastFeeding == null && b.lastFeeding == null) return 0;
        if (a.lastFeeding == null) return 1;
        if (b.lastFeeding == null) return -1;
        return b.lastFeeding!.compareTo(a.lastFeeding!);
      });
      
      if (_devices.isNotEmpty) {
        if (_currentDevice == null || !_devices.contains(_currentDevice)) {
          _currentDevice = _devices.first;
          await fetchSchedulesForDevice(_currentDevice!.deviceKey);
        }
      } else {
        debugPrint('No devices found');
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching devices: $e');
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to fetch devices: $e');
    }
  }
  
  // Set current device
  Future<void> selectDevice(String deviceKey) async {
    final device = _devices.firstWhere((d) => d.deviceKey == deviceKey);
    _currentDevice = device;
    await fetchSchedulesForDevice(deviceKey);
    notifyListeners();
  }
  
  // Register a new device
  Future<void> registerDevice({
    required String name,
    required String deviceKey,
  }) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final device = Device(
        deviceKey: deviceKey,
        name: name,
        userId: user.id,
        foodLevel: 100.0,
        lastFeeding: null,
      );
      
      await SupabaseService.addDevice(device.toJson());
      
      // Refresh the device list
      await fetchDevices();
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to register device: $e');
    }
  }
  
  // Update a device
  Future<void> updateDevice({
    required String deviceKey,
    String? name,
    double? foodLevel,
    DateTime? lastFeeding,
  }) async {
    try {
      debugPrint('Updating device: $deviceKey');
      debugPrint('Food level: $foodLevel');
      debugPrint('Last feeding: $lastFeeding');
      
      final deviceToUpdate = _devices.firstWhere((d) => d.deviceKey == deviceKey);
      
      final updatedDevice = Device(
        deviceKey: deviceKey,
        name: name ?? deviceToUpdate.name,
        userId: deviceToUpdate.userId,
        foodLevel: foodLevel ?? deviceToUpdate.foodLevel,
        lastFeeding: lastFeeding ?? deviceToUpdate.lastFeeding,
      );
      
      await SupabaseService.updateDevice(deviceKey, updatedDevice.toJson());
      
      // Update local device list
      final index = _devices.indexWhere((d) => d.deviceKey == deviceKey);
      if (index != -1) {
        _devices[index] = updatedDevice;
      }
      
      // Update current device if needed
      if (_currentDevice?.deviceKey == deviceKey) {
        _currentDevice = updatedDevice;
      }
      
      notifyListeners();
      
      // Verify the update by refetching
      await fetchDevices();
    } catch (e) {
      debugPrint('Error updating device: $e');
      throw Exception('Failed to update device: $e');
    }
  }
  
  // Delete a device
  Future<void> deleteDevice(String deviceKey) async {
    try {
      await SupabaseService.deleteDevice(deviceKey);
      
      // Refresh device list
      await fetchDevices();
      
      // If the deleted device was the current device, select another one
      if (_currentDevice?.deviceKey == deviceKey) {
        _currentDevice = _devices.isNotEmpty ? _devices.first : null;
        if (_currentDevice != null) {
          await fetchSchedulesForDevice(_currentDevice!.deviceKey);
        } else {
          _schedules = [];
        }
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete device: $e');
    }
  }
  
  // Fetch feeding schedules for a specific device
  Future<void> fetchSchedulesForDevice(String deviceKey) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final response = await SupabaseService.client
          .from('feeding_schedules')
          .select('*')
          .eq('device_key', deviceKey)
          .order('start_date', ascending: true);
      
      _schedules = (response as List).map((json) => FeedingSchedule.fromJson(json)).toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to fetch schedules: $e');
    }
  }

  // Add a feeding schedule
  Future<void> addSchedule(FeedingSchedule schedule) async {
    try {
      if (_currentDevice == null) {
        throw Exception('No device selected');
      }
      
      await SupabaseService.addFeedingSchedule(schedule.toJson());
      
      // Refresh schedules
      await fetchSchedulesForDevice(_currentDevice!.deviceKey);
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to add schedule: $e');
    }
  }

  // Update a feeding schedule
  Future<void> updateSchedule(String scheduleId, FeedingSchedule schedule) async {
    try {
      await SupabaseService.updateFeedingSchedule(scheduleId, schedule.toJson());
      
      // Refresh schedules
      if (_currentDevice != null) {
        await fetchSchedulesForDevice(_currentDevice!.deviceKey);
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update schedule: $e');
    }
  }

  // Remove a feeding schedule
  Future<void> removeSchedule(String scheduleId) async {
    try {
      await SupabaseService.deleteFeedingSchedule(scheduleId);
      
      // Refresh schedules
      if (_currentDevice != null) {
        await fetchSchedulesForDevice(_currentDevice!.deviceKey);
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to remove schedule: $e');
    }
  }

  // Update food level
  Future<void> updateFoodLevel(double newLevel) async {
    if (_currentDevice == null) return;
    
    try {
      await updateDevice(
        deviceKey: _currentDevice!.deviceKey,
        foodLevel: newLevel,
      );
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update food level: $e');
    }
  }

  // Record a feeding event
  Future<void> recordFeeding(double amount) async {
    if (_currentDevice == null) return;
    
    final now = DateTime.now();
    final newFoodLevel = (foodLevel - (amount / 1000.0) * 100).clamp(0.0, 100.0);
    
    try {
      // Update device with new food level and last feeding time
      await updateDevice(
        deviceKey: _currentDevice!.deviceKey,
        foodLevel: newFoodLevel,
        lastFeeding: now,
      );
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to record feeding: $e');
    }
  }

  void setFeeding(bool isFeeding) {
    _isFeeding = isFeeding;
    notifyListeners();
  }

  bool shouldSendLowFoodNotification() {
    return foodLevel < 20.0;
  }

  // Get next feeding times
  List<DateTime> getNextFeedingTimes() {
    final now = DateTime.now();
    final nextTimes = <DateTime>[];

    for (final schedule in _schedules) {
      if (schedule.endDate.isBefore(now)) continue;

      final startDateTime = DateTime(
        schedule.startDate.year,
        schedule.startDate.month,
        schedule.startDate.day,
        schedule.startTime.hour,
        schedule.startTime.minute,
      );

      if (startDateTime.isAfter(now)) {
        nextTimes.add(startDateTime);
      } else {
        // Calculate next feeding time based on frequency
        var nextTime = startDateTime;
        while (nextTime.isBefore(now)) {
          if (schedule.frequency == 'hour') {
            nextTime = nextTime.add(const Duration(hours: 1));
          } else {
            nextTime = nextTime.add(const Duration(days: 1));
          }
        }
        if (nextTime.isBefore(schedule.endDate)) {
          nextTimes.add(nextTime);
        }
      }
    }

    nextTimes.sort();
    return nextTimes;
  }

  // Check if there is a scheduled feeding at the current time
  bool hasScheduledFeeding() {
    final now = DateTime.now();
    final nextTimes = getNextFeedingTimes();
    
    if (nextTimes.isEmpty) return false;
    
    final nextFeeding = nextTimes.first;
    final difference = nextFeeding.difference(now).inMinutes.abs();
    
    // Allow 1 minute tolerance
    return difference <= 1;
  }

  // Get the amount to feed for the current schedule
  double? getCurrentScheduleAmount() {
    if (!hasScheduledFeeding()) return null;
    
    final now = DateTime.now();
    
    for (final schedule in _schedules) {
      if (schedule.endDate.isBefore(now)) continue;
      
      final startDateTime = DateTime(
        schedule.startDate.year,
        schedule.startDate.month,
        schedule.startDate.day,
        schedule.startTime.hour,
        schedule.startTime.minute,
      );
      
      if (startDateTime.isAfter(now)) {
        return schedule.amount;
      } else {
        var nextTime = startDateTime;
        while (nextTime.isBefore(now)) {
          if (schedule.frequency == 'hour') {
            nextTime = nextTime.add(const Duration(hours: 1));
          } else {
            nextTime = nextTime.add(const Duration(days: 1));
          }
        }
        if (nextTime.isBefore(schedule.endDate)) {
          return schedule.amount;
        }
      }
    }
    
    return null;
  }
} 