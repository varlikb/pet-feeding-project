import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pet_provider.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/supabase_service.dart';

class EditPetScreen extends StatefulWidget {
  final Pet pet;
  
  const EditPetScreen({Key? key, required this.pet}) : super(key: key);

  @override
  State<EditPetScreen> createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;
  late bool _isFemale;
  String? _selectedDeviceKey;
  List<Map<String, dynamic>> _availableDevices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _weightController = TextEditingController(text: widget.pet.weight.toString());
    _ageController = TextEditingController(text: widget.pet.age.toString());
    _isFemale = widget.pet.isFemale;
    _selectedDeviceKey = widget.pet.deviceKey;
    _loadAvailableDevices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableDevices() async {
    try {
      final devices = await SupabaseService.getAvailableDevices();
      setState(() {
        _availableDevices = devices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading devices: $e')),
        );
      }
    }
  }

  Future<void> _updatePet() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await context.read<PetProvider>().updatePet(
          id: widget.pet.id,
          name: _nameController.text,
          weight: double.parse(_weightController.text),
          age: int.parse(_ageController.text),
          isFemale: _isFemale,
          deviceKey: _selectedDeviceKey,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet updated successfully')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating pet: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
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
                decoration: const InputDecoration(labelText: 'Age'),
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
              SwitchListTile(
                title: const Text('Gender'),
                subtitle: Text(_isFemale ? 'Female' : 'Male'),
                value: _isFemale,
                onChanged: (bool value) {
                  setState(() {
                    _isFemale = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDeviceKey,
                decoration: const InputDecoration(labelText: 'Device'),
                items: [
                  if (widget.pet.deviceKey != null)
                    DropdownMenuItem<String>(
                      value: widget.pet.deviceKey,
                      child: const Text('Current Device'),
                    ),
                  ..._availableDevices.map((device) => DropdownMenuItem<String>(
                        value: device['device_key'] as String,
                        child: Text(device['name'] as String),
                      )),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _selectedDeviceKey = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _updatePet,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Update Pet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 