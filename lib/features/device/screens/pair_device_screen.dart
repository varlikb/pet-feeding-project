import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/supabase_service.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final _deviceKeyController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isPaired = false;

  @override
  void dispose() {
    _deviceKeyController.dispose();
    super.dispose();
  }

  Future<void> _verifyPairingStatus() async {
    if (_deviceKeyController.text.isEmpty) {
      setState(() {
        _error = 'Please enter the device key';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deviceKey = _deviceKeyController.text.trim();
      
      // First check if device exists and is not paired
      final device = await DeviceService.checkDeviceAvailability(deviceKey);
      
      if (device == null) {
        setState(() {
          _error = 'Device not found or already paired';
          _isLoading = false;
        });
        return;
      }
      
      // Device exists and is not paired, so let's pair it
      final pairedDevice = await DeviceService.pairDevice(deviceKey);
      
      setState(() {
        _isPaired = true;
        _isLoading = false;
      });

      // Show success message and return to previous screen after delay
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device paired successfully!'),
            backgroundColor: Colors.green,
          ),
        );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop(pairedDevice);
      }

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair New Device'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify Device Pairing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
              const Text(
                      'Enter your device key to verify and complete the pairing process:',
              ),
                    const SizedBox(height: 12),
              TextFormField(
                controller: _deviceKeyController,
                decoration: const InputDecoration(
                        labelText: 'Device Key',
                        hintText: 'Example: PF_ABC123',
                  border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        onPressed: _verifyPairingStatus,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Verify Pairing Status'),
                style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                          color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _error!,
                          style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ],
                    if (_isPaired) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                  child: Column(
                    children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Device Successfully Paired!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                    ],
                  ),
                ),
                    ],
            ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 