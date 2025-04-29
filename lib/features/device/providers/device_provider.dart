import 'package:flutter/material.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class Device {
  final String id;
  final String name;
  final String deviceKey;
  final String userId;
  final double foodLevel;
  final DateTime? lastFeeding;

  Device({
    required this.id,
    required this.name,
    required this.deviceKey,
    required this.userId,
    required this.foodLevel,
    this.lastFeeding,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceKey: json['device_key'] as String,
      userId: json['user_id'] as String,
      foodLevel: (json['food_level'] as num).toDouble(),
      lastFeeding: json['last_feeding'] != null 
          ? DateTime.parse(json['last_feeding'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'device_key': deviceKey,
      'user_id': userId,
      'food_level': foodLevel,
      'last_feeding': lastFeeding?.toIso8601String(),
    };
  }
}

class FeedingSchedule {
  final String id;
  final String deviceId;
  final DateTime startDate;
  final DateTime endDate;
  final String frequency; // 'hour' or 'day'
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double amount;

  FeedingSchedule({
    required this.id,
    required this.deviceId,
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
      deviceId: json['device_id'] as String,
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
      'device_id': deviceId,
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
      
      final data = await SupabaseService.fetchDevices();
      _devices = data.map((json) => Device.fromJson(json)).toList();
      
      if (_devices.isNotEmpty && _currentDevice == null) {
        _currentDevice = _devices.first;
        await fetchSchedulesForDevice(_currentDevice!.id);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to fetch devices: $e');
    }
  }
  
  // Set current device
  Future<void> selectDevice(String id) async {
    final device = _devices.firstWhere((d) => d.id == id);
    _currentDevice = device;
    await fetchSchedulesForDevice(id);
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
        id: DateTime.now().toString(), // Will be replaced by Supabase UUID
        name: name,
        deviceKey: deviceKey,
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
    required String id,
    String? name,
    String? deviceKey,
    double? foodLevel,
    DateTime? lastFeeding,
  }) async {
    try {
      final deviceToUpdate = _devices.firstWhere((d) => d.id == id);
      
      final updatedDevice = Device(
        id: id,
        name: name ?? deviceToUpdate.name,
        deviceKey: deviceKey ?? deviceToUpdate.deviceKey,
        userId: deviceToUpdate.userId,
        foodLevel: foodLevel ?? deviceToUpdate.foodLevel,
        lastFeeding: lastFeeding ?? deviceToUpdate.lastFeeding,
      );
      
      await SupabaseService.updateDevice(id, updatedDevice.toJson());
      
      // Refresh device list
      await fetchDevices();
      
      // Update current device if needed
      if (_currentDevice?.id == id) {
        _currentDevice = updatedDevice;
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update device: $e');
    }
  }
  
  // Delete a device
  Future<void> deleteDevice(String id) async {
    try {
      await SupabaseService.deleteDevice(id);
      
      // Refresh device list
      await fetchDevices();
      
      // If the deleted device was the current device, select another one
      if (_currentDevice?.id == id) {
        _currentDevice = _devices.isNotEmpty ? _devices.first : null;
        if (_currentDevice != null) {
          await fetchSchedulesForDevice(_currentDevice!.id);
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
  Future<void> fetchSchedulesForDevice(String deviceId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final response = await SupabaseService.client
          .from('feeding_schedules')
          .select('*')
          .eq('device_id', deviceId)
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
      
      await SupabaseService.client.from('feeding_schedules').insert(schedule.toJson());
      
      // Refresh schedules
      await fetchSchedulesForDevice(_currentDevice!.id);
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to add schedule: $e');
    }
  }

  // Remove a feeding schedule
  Future<void> removeSchedule(String scheduleId) async {
    try {
      await SupabaseService.client.from('feeding_schedules').delete().eq('id', scheduleId);
      
      // Refresh schedules
      if (_currentDevice != null) {
        await fetchSchedulesForDevice(_currentDevice!.id);
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
        id: _currentDevice!.id,
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
        id: _currentDevice!.id,
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
} 