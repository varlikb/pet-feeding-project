import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pet_provider.dart';
import '../../../core/services/device_service.dart';

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
  bool _isLoading = false;
  List<Map<String, dynamic>> _userDevices = [];
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current pet data
    _nameController = TextEditingController(text: widget.pet.name);
    _weightController = TextEditingController(text: widget.pet.weight.toString());
    _ageController = TextEditingController(text: widget.pet.age.toString());
    _isFemale = widget.pet.isFemale;
    _selectedDeviceId = widget.pet.deviceId;
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

  Future<void> _updatePet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<PetProvider>(context, listen: false).updatePet(
        id: widget.pet.id,
        name: _nameController.text,
        weight: double.parse(_weightController.text),
        age: int.parse(_ageController.text),
        isFemale: _isFemale,
        deviceId: _selectedDeviceId,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nameController.text} updated successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.pet.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter name';
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
                        labelText: 'Age (months)',
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gender',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _isFemale = false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: !_isFemale ? Theme.of(context).colorScheme.primary : null,
                                      foregroundColor: !_isFemale ? Colors.white : null,
                                    ),
                                    child: const Text('MALE'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _isFemale = true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFemale ? Theme.of(context).colorScheme.primary : null,
                                      foregroundColor: _isFemale ? Colors.white : null,
                                    ),
                                    child: const Text('FEMALE'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paired Device',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_userDevices.isEmpty)
                              const Text(
                                'No devices available',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Select Device',
                                  border: OutlineInputBorder(),
                                ),
                                value: _selectedDeviceId,
                                items: _userDevices.map((device) {
                                  return DropdownMenuItem<String>(
                                    value: device['id'],
                                    child: Text('${device['name']} (${device['device_key']})'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDeviceId = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a device';
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/pair-device').then((_) {
                                  _loadUserDevices();
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Pair New Device'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _updatePet,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 