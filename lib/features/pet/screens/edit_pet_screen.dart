import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pet_provider.dart';

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
  late TextEditingController _deviceKeyController;
  late bool _isFemale;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current pet data
    _nameController = TextEditingController(text: widget.pet.name);
    _weightController = TextEditingController(text: widget.pet.weight.toString());
    _ageController = TextEditingController(text: widget.pet.age.toString());
    _deviceKeyController = TextEditingController(text: widget.pet.deviceKey);
    _isFemale = widget.pet.isFemale;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _deviceKeyController.dispose();
    super.dispose();
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
        deviceKey: _deviceKeyController.text,
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter weight';
                        }
                        try {
                          final weight = double.parse(value);
                          if (weight <= 0) {
                            return 'Weight must be greater than 0';
                          }
                        } catch (e) {
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
                        try {
                          final age = int.parse(value);
                          if (age < 0) {
                            return 'Age cannot be negative';
                          }
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _deviceKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Device Key',
                        border: OutlineInputBorder(),
                        helperText: 'Unique identifier for the pet feeder device',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter device key';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Text('Gender: '),
                            Radio<bool>(
                              value: true,
                              groupValue: _isFemale,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  setState(() {
                                    _isFemale = value;
                                  });
                                }
                              },
                            ),
                            const Text('Female'),
                            Radio<bool>(
                              value: false,
                              groupValue: _isFemale,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  setState(() {
                                    _isFemale = value;
                                  });
                                }
                              },
                            ),
                            const Text('Male'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _updatePet,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Update Pet'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 