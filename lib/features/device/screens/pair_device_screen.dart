import 'package:flutter/material.dart';
import '../../../core/services/device_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final _deviceKeyController = TextEditingController();
  bool _isScanning = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _foundDevice;

  @override
  void dispose() {
    _deviceKeyController.dispose();
    super.dispose();
  }

  Future<void> _checkDeviceAvailability(String deviceKey) async {
    if (deviceKey.isEmpty) {
      setState(() {
        _error = 'Please enter a device key';
        _foundDevice = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _foundDevice = null;
    });

    try {
      final device = await DeviceService.checkDeviceAvailability(deviceKey);
      setState(() {
        _isLoading = false;
        _foundDevice = device;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().contains('Exception: ')
            ? e.toString().split('Exception: ')[1]
            : 'Device not found. Please check if the device key is correct.';
      });
    }
  }

  Future<void> _pairDevice() async {
    if (_foundDevice == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final device = await DeviceService.pairDevice(_foundDevice!['device_key']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device paired successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(device);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().contains('Exception: ')
            ? e.toString().split('Exception: ')[1]
            : 'Failed to pair device. Please try again.';
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
            const Text(
              'Scan the QR code on your device or enter the device key manually',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isScanning) ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
                        setState(() {
                          _deviceKeyController.text = barcodes[0].rawValue!;
                          _isScanning = false;
                        });
                        _checkDeviceAvailability(_deviceKeyController.text);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() => _isScanning = false),
                child: const Text('Cancel Scanning'),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _deviceKeyController,
                      decoration: InputDecoration(
                        labelText: 'Device Key',
                        border: const OutlineInputBorder(),
                        errorText: _error,
                        suffixIcon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _foundDevice != null
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _checkDeviceAvailability(_deviceKeyController.text),
                    child: const Text('Verify'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _isScanning = true),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
              ),
            ],
            if (_foundDevice != null) ...[
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Found: ${_foundDevice!['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Key: ${_foundDevice!['device_key']}'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _pairDevice,
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
                              : const Text('Pair Device'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 