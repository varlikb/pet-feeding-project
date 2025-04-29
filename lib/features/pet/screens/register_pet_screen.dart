import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/pet_provider.dart';

class RegisterPetScreen extends StatefulWidget {
  const RegisterPetScreen({super.key});

  @override
  State<RegisterPetScreen> createState() => _RegisterPetScreenState();
}

class _RegisterPetScreenState extends State<RegisterPetScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _manualKeyController = TextEditingController();
  bool _isFemale = false;
  bool _isScanning = false;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  String? _deviceKey;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _manualKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _ageController.text.isEmpty ||
        (_deviceKey == null && _manualKeyController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final deviceKey = _deviceKey ?? _manualKeyController.text;
    
    try {
      await context.read<PetProvider>().registerPet(
        name: _nameController.text,
        weight: double.parse(_weightController.text),
        age: int.parse(_ageController.text),
        isFemale: _isFemale,
        deviceKey: deviceKey,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Pet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Pet Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'Age (years)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
              'Connect your device',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isScanning) ...[
              SizedBox(
                height: 300,
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
                      setState(() {
                        _deviceKey = barcodes[0].rawValue;
                        _isScanning = false;
                      });
                    }
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () => setState(() => _isScanning = false),
                child: const Text('Cancel Scanning'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => setState(() => _isScanning = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Connect with QR'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manualKeyController,
                decoration: const InputDecoration(
                  labelText: 'Enter Manual Key',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
} 