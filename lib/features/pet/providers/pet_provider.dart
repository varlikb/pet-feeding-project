import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';
import 'package:pet_feeder/core/services/device_service.dart';

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
      final device = await DeviceService.getDeviceByKey(deviceKey);
      if (device == null) {
        throw Exception('Device not found');
      }

      final response = await SupabaseService.client.from('pets').insert({
        'name': name,
        'weight': weight,
        'age': age,
        'is_female': isFemale,
        'device_key': deviceKey,
        'user_id': SupabaseService.client.auth.currentUser!.id,
      }).select();

      if (response.isNotEmpty) {
        _pets.add(Pet.fromJson(response[0]));
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Error registering pet: $e');
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
      final response = await SupabaseService.client
          .from('pets')
          .update({
            'name': name,
            'weight': weight,
            'age': age,
            'is_female': isFemale,
            'device_key': deviceKey,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      final updatedPet = Pet.fromJson(response);
      final index = _pets.indexWhere((pet) => pet.id == id);
      if (index != -1) {
        _pets[index] = updatedPet;
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Error updating pet: $e');
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
      final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_key']);
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
        deviceAssignment['device_key'],
        {'food_level': newFoodLevel},
      );
      
      final record = {
        'pet_id': _currentPet!.id,
        'device_key': deviceAssignment['device_key'],
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

      final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_key']);
      if (deviceDetails == null) {
        return 0.0;
      }

      return (deviceDetails['food_level'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting device food level: $e');
      return 0.0;
    }
  }

  Future<String?> getDeviceKey() async {
    if (_currentPet == null) {
      return null;
    }

    try {
      final deviceAssignment = await SupabaseService.getPrimaryDeviceForPet(_currentPet!.id);
      if (deviceAssignment == null) {
        return null;
      }

      final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_key']);
      if (deviceDetails == null) {
        return null;
      }

      return deviceDetails['device_key'] as String;
    } catch (e) {
      debugPrint('Error getting device key: $e');
      return null;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}