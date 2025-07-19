import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:pet_feeder/core/services/device_communication_service.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class DevicePairingScreen extends StatefulWidget {
  final String petId;
  
  const DevicePairingScreen({Key? key, required this.petId}) : super(key: key);

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceKeyController = TextEditingController();
  final _wifiSSIDController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isPairing = false;
  bool _useCurrentWifi = true; // Default to using current WiFi
  
  @override
  void initState() {
    super.initState();
    _getCurrentWiFiInfo();
  }
  
  @override
  void dispose() {
    _deviceKeyController.dispose();
    _wifiSSIDController.dispose();
    _wifiPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _getCurrentWiFiInfo() async {
    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();
      if (wifiName != null) {
        setState(() {
          _wifiSSIDController.text = wifiName.replaceAll('"', '');
        });
      }
    } catch (e) {
      debugPrint('Error getting WiFi info: $e');
    }
  }
  
  Future<void> _startPairing() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _isPairing = true;
      _statusMessage = 'Cihaz bağlantısı kontrol ediliyor...';
    });
    
    try {
      final deviceKey = _deviceKeyController.text.trim();
      
      // Check if device exists and is available
      final device = await SupabaseService.getDevice(deviceKey);
      if (device == null) {
        setState(() {
          _statusMessage = 'Cihaz bulunamadı!';
          _isLoading = false;
        });
        return;
      }
      
      if (device['is_paired'] == true) {
        setState(() {
          _statusMessage = 'Bu cihaz zaten başka bir kullanıcıya atanmış!';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _statusMessage = 'WiFi bilgileri gönderiliyor...';
      });
      
      // Send WiFi credentials through Supabase realtime
      final ssid = _wifiSSIDController.text.trim();
      final password = _wifiPasswordController.text.trim();
      
      final credentialsSent = await DeviceCommunicationService.sendWifiCredentials(
        deviceKey,
        ssid,
        password,
      );
      
      if (!credentialsSent) {
        setState(() {
          _statusMessage = 'WiFi bilgileri gönderilemedi!';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _statusMessage = 'Cihaz bağlantısı bekleniyor...';
      });
      
      // Wait for device to connect and check its health
      await Future.delayed(const Duration(seconds: 10));
      final deviceHealth = await DeviceCommunicationService.checkDeviceHealth(deviceKey);
      
      if (deviceHealth == null || deviceHealth['status'] != 'online') {
        setState(() {
          _statusMessage = 'Cihaz bağlantısı başarısız!';
          _isLoading = false;
        });
        return;
      }
      
      // Update device data in Supabase
      final deviceData = {
        'is_paired': true,
        'wifi_ssid': ssid,
        'wifi_status': 'connected',
        'last_online': DateTime.now().toIso8601String(),
      };
      
      try {
        await SupabaseService.updateDevice(deviceKey, deviceData);
      } catch (e) {
        setState(() {
          _statusMessage = 'Cihaz güncellenemedi!';
          _isLoading = false;
        });
        return;
      }
      
      // Update pet with device key
      try {
        await SupabaseService.updatePet(widget.petId, {'device_key': deviceKey});
      } catch (e) {
        setState(() {
          _statusMessage = 'Cihaz evcil hayvana atanamadı!';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _statusMessage = 'Eşleştirme tamamlandı!';
        _isLoading = false;
        _isPairing = false;
      });
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Hata: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Cihaz Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cihaz Eşleştirme',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeni bir besleme cihazı eklemek için, cihazın LCD ekranında görünen cihaz kodunu girin ve WiFi ayarlarını yapılandırın.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _deviceKeyController,
                decoration: const InputDecoration(
                  labelText: 'Cihaz Kodu',
                  hintText: 'Örn: PF_ABC123',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen cihaz kodunu girin';
                  }
                  if (!value.startsWith('PF_')) {
                    return 'Cihaz kodu "PF_" ile başlamalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // WiFi Configuration Section
              const Text(
                'WiFi Yapılandırması',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // WiFi Selection Switch
              SwitchListTile(
                title: const Text('Mevcut WiFi\'yi Kullan'),
                subtitle: Text(_useCurrentWifi && _wifiSSIDController.text.isNotEmpty
                  ? 'Bağlı olduğunuz ağ: ${_wifiSSIDController.text}'
                  : 'Manuel WiFi yapılandırması için kapatın'),
                value: _useCurrentWifi,
                onChanged: (bool value) {
                  setState(() {
                    _useCurrentWifi = value;
                    if (!value) {
                      _wifiSSIDController.clear();
                      _wifiPasswordController.clear();
                    } else {
                      _getCurrentWiFiInfo();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Manual WiFi Configuration
              if (!_useCurrentWifi) ...[
                TextFormField(
                  controller: _wifiSSIDController,
                  decoration: const InputDecoration(
                    labelText: 'WiFi Adı',
                    hintText: 'Cihazın bağlanacağı WiFi ağı',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen WiFi adını girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _wifiPasswordController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Şifresi',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen WiFi şifresini girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              if (_isLoading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _startPairing,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Eşleştirmeyi Başlat'),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 