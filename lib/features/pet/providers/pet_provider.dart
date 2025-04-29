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
  bool _isConnected = false;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  bool _isLoading = false;

  Pet? get currentPet => _currentPet;
  List<Pet> get pets => _pets;
  bool get isConnected => _isConnected;
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
      
      final pet = {
        'name': name,
        'weight': weight,
        'age': age,
        'is_female': isFemale,
        'device_key': deviceKey,
        'user_id': user.id,
      };
      
      await SupabaseService.addPet(pet);
      
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
      final record = {
        'pet_id': _currentPet!.id,
        'amount': amount,
        'feeding_time': DateTime.now().toIso8601String(),
        'user_id': _currentPet!.userId,
      };
      
      await SupabaseService.addFeedingRecord(record);
    } catch (e) {
      throw Exception('Failed to record feeding: $e');
    }
  }

  Future<void> connectDevice() async {
    if (_currentPet == null) return;

    try {
      // Start scanning for devices
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      
      // Listen for scan results
      await for (final result in FlutterBluePlus.scanResults) {
        for (ScanResult r in result) {
          if (r.device.remoteId.toString() == _currentPet!.deviceKey) {
            _device = r.device;
            break;
          }
        }
      }

      if (_device == null) {
        throw Exception('Device not found');
      }

      // Connect to the device
      await _device!.connect();
      
      // Discover services
      List<BluetoothService> services = await _device!.discoverServices();
      
      // Find the characteristic we want to write to
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            _characteristic = characteristic;
            break;
          }
        }
      }

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      throw Exception('Failed to connect to device: $e');
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> feedPet(double amount) async {
    if (!_isConnected || _characteristic == null) {
      throw Exception('Device not connected');
    }

    try {
      final command = 'FEED:$amount';
      await _characteristic!.write(Uint8List.fromList(command.codeUnits));
      
      // Record the feeding in the database
      await recordFeeding(amount);
    } catch (e) {
      throw Exception('Failed to send feeding command: $e');
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _characteristic = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}