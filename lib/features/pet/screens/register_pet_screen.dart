import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pet_provider.dart';
import '../../../core/services/device_service.dart';

class RegisterPetScreen extends StatefulWidget {
  const RegisterPetScreen({super.key});

  @override
  State<RegisterPetScreen> createState() => _RegisterPetScreenState();
}

class _RegisterPetScreenState extends State<RegisterPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isFemale = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _userDevices = [];
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _loadUserDevices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDevices() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final devices = await DeviceService.getUserDevices();
      
      setState(() {
        _userDevices = devices;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading devices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a device'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the selected device
      final selectedDevice = _userDevices.firstWhere(
        (device) => device['id'] == _selectedDeviceId,
      );

      await context.read<PetProvider>().registerPet(
        name: _nameController.text,
        weight: double.parse(_weightController.text),
        age: int.parse(_ageController.text),
        isFemale: _isFemale,
        deviceId: selectedDevice['id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pet registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Exception: ') 
                ? e.toString().split('Exception: ')[1]
                : e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Pet'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Pet Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter pet name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Age (years)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter age';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => _isFemale = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isFemale ? Theme.of(context).colorScheme.primary : null,
                      foregroundColor: !_isFemale ? Colors.white : null,
                    ),
                    child: const Text('MALE'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _isFemale = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFemale ? Theme.of(context).colorScheme.primary : null,
                      foregroundColor: _isFemale ? Colors.white : null,
                    ),
                    child: const Text('FEMALE'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Select Device',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_userDevices.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'No paired devices found',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            // Navigate to device pairing screen
                            Navigator.pushNamed(context, '/pair-device').then((_) {
                              // Reload devices when returning from pairing screen
                              _loadUserDevices();
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Pair a Device'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Device',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedDeviceId,
                      items: _userDevices.map((device) {
                        return DropdownMenuItem<String>(
                          value: device['id'],
                          child: Text(device['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDeviceId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a device';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        // Navigate to device pairing screen
                        Navigator.pushNamed(context, '/pair-device').then((_) {
                          // Reload devices when returning from pairing screen
                          _loadUserDevices();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Pair Another Device'),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Register Pet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 