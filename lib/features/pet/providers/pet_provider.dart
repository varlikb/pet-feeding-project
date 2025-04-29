import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Pet {
  final String id;
  final String name;
  final double weight;
  final int age;
  final bool isFemale;
  final String deviceKey;

  Pet({
    required this.id,
    required this.name,
    required this.weight,
    required this.age,
    required this.isFemale,
    required this.deviceKey,
  });
}

class PetProvider extends ChangeNotifier {
  Pet? _currentPet;
  bool _isConnected = false;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;

  Pet? get currentPet => _currentPet;
  bool get isConnected => _isConnected;

  Future<void> registerPet({
    required String name,
    required double weight,
    required int age,
    required bool isFemale,
    required String deviceKey,
  }) async {
    try {
      _currentPet = Pet(
        id: DateTime.now().toString(), // In real app, use proper ID generation
        name: name,
        weight: weight,
        age: age,
        isFemale: isFemale,
        deviceKey: deviceKey,
      );
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to register pet: $e');
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