import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class Pet {
  final String id;
  final String name;
  final double weight;
  final int age;
  final bool isFemale;
  final String deviceKey;
  final String userId;
  
  Pet({
    required this.id,
    required this.name,
    required this.weight,
    required this.age,
    required this.isFemale,
    required this.deviceKey,
    required this.userId,
  });
  
  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as num).toDouble(),
      age: json['age'] as int,
      isFemale: json['is_female'] as bool,
      deviceKey: json['device_key'] as String,
      userId: json['user_id'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'age': age,
      'is_female': isFemale,
      'device_key': deviceKey,
      'user_id': userId,
    };
  }
}

class PetProvider extends ChangeNotifier {
  Pet? _currentPet;
  List<Pet> _pets = [];
  bool _isLoading = false;

  Pet? get currentPet => _currentPet;
  List<Pet> get pets => _pets;
  bool get isLoading => _isLoading;

  Future<void> fetchPets() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final data = await SupabaseService.fetchPets();
      _pets = data.map((json) => Pet.fromJson(json)).toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to fetch pets: $e');
    }
  }
  
  Future<void> selectPet(String id) async {
    try {
      final data = await SupabaseService.getPet(id);
      _currentPet = Pet.fromJson(data);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to select pet: $e');
    }
  }

  Future<void> registerPet({
    required String name,
    required double weight,
    required int age,
    required bool isFemale,
    required String deviceKey,
  }) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // First, check if a device with this key already exists
      final existingDevice = await SupabaseService.findDeviceByKey(deviceKey);
      String deviceId;

      if (existingDevice != null) {
        // Use existing device
        deviceId = existingDevice['id'];
      } else {
        // Create new device
        final newDevice = await SupabaseService.addDevice({
          'name': 'Pet Feeder for $name',
          'device_key': deviceKey,
          'user_id': user.id,
          'food_level': 100.0,
        });
        deviceId = newDevice['id'];
      }
      
      // Register the pet
      final pet = {
        'name': name,
        'weight': weight,
        'age': age,
        'is_female': isFemale,
        'device_key': deviceKey,
        'user_id': user.id,
      };
      
      final addedPet = await SupabaseService.addPet(pet);
      
      // Create pet-device assignment
      await SupabaseService.assignPetToDevice(
        addedPet['id'],
        deviceId,
        true, // Set as primary device
      );
      
      // Refresh the pet list
      await fetchPets();
      
      // Set as current pet
      _currentPet = _pets.isNotEmpty ? _pets.first : null;
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to register pet: $e');
    }
  }
  
  Future<void> updatePet({
    required String id,
    required String name,
    required double weight,
    required int age,
    required bool isFemale,
    String? deviceKey,
  }) async {
    try {
      if (_currentPet == null) {
        throw Exception('No pet selected');
      }
      
      final updatedPet = Pet(
        id: id,
        name: name,
        weight: weight,
        age: age,
        isFemale: isFemale,
        deviceKey: deviceKey ?? _currentPet!.deviceKey,
        userId: _currentPet!.userId,
      );
      
      await SupabaseService.updatePet(id, updatedPet.toJson());
      
      // Refresh pet list
      await fetchPets();
      
      // Update current pet
      _currentPet = updatedPet;
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update pet: $e');
    }
  }
  
  Future<void> deletePet(String id) async {
    try {
      await SupabaseService.deletePet(id);
      
      // Refresh pets list
      await fetchPets();
      
      // If the deleted pet was the current pet, clear it
      if (_currentPet?.id == id) {
        _currentPet = _pets.isNotEmpty ? _pets.first : null;
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete pet: $e');
    }
  }

  Future<void> recordFeeding(double amount) async {
    if (_currentPet == null) {
      throw Exception('No pet selected');
    }
    
    try {
      // Get the primary device for this pet
      final deviceAssignment = await SupabaseService.getPrimaryDeviceForPet(_currentPet!.id);
      if (deviceAssignment == null) {
        throw Exception('No device assigned to pet');
      }

      // Get current device details
      final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_id']);
      if (deviceDetails == null) {
        throw Exception('Device not found');
      }

      // Check if there's enough food in the device
      final currentFoodLevel = (deviceDetails['food_level'] as num).toDouble();
      if (currentFoodLevel < amount) {
        throw Exception('Not enough food in device. Available: ${currentFoodLevel.toStringAsFixed(1)}g');
      }

      // Calculate new food level by subtracting the feeding amount
      final newFoodLevel = currentFoodLevel - amount;

      // Update device food level
      await SupabaseService.updateDevice(
        deviceAssignment['device_id'],
        {'food_level': newFoodLevel},
      );
      
      final record = {
        'pet_id': _currentPet!.id,
        'device_id': deviceAssignment['device_id'],
        'amount': amount,
        'feeding_time': DateTime.now().toIso8601String(),
        'feeding_type': 'manual', // Can be 'manual' or 'scheduled'
        'user_id': _currentPet!.userId,
      };
      
      await SupabaseService.addFeedingRecord(record);
    } catch (e) {
      throw Exception('Failed to record feeding: $e');
    }
  }

  Future<void> feedPet(double amount) async {
    if (_currentPet == null) {
      throw Exception('No pet selected');
    }

    try {
      // Record the feeding in Supabase
      await recordFeeding(amount);
      debugPrint('Feeding recorded: ${amount}g for pet ${_currentPet!.name}');
    } catch (e) {
      debugPrint('Error recording feeding: $e');
      throw Exception('Failed to record feeding: $e');
    }
  }

  // Add method to get device food level
  Future<double> getCurrentDeviceFoodLevel() async {
    if (_currentPet == null) {
      return 0.0;
    }

    try {
      final deviceAssignment = await SupabaseService.getPrimaryDeviceForPet(_currentPet!.id);
      if (deviceAssignment == null) {
        return 0.0;
      }

      final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_id']);
      if (deviceDetails == null) {
        return 0.0;
      }

      return (deviceDetails['food_level'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting device food level: $e');
      return 0.0;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}