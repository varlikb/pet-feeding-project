import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pet_feeder/core/services/device_communication_service.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class FeedingScheduleStatusScreen extends StatefulWidget {
  final String? petId;
  final String? deviceIP;
  final String? deviceKey;
  
  const FeedingScheduleStatusScreen({
    Key? key, 
    this.petId,
    this.deviceIP,
    this.deviceKey,
  }) : super(key: key);

  @override
  State<FeedingScheduleStatusScreen> createState() => _FeedingScheduleStatusScreenState();
}

class _FeedingScheduleStatusScreenState extends State<FeedingScheduleStatusScreen> {
  bool _isLoading = false;
  String _deviceIP = '';
  String? _deviceKey;
  Map<String, dynamic>? _deviceStatus;
  Map<String, dynamic>? _scheduleStatus;
  Timer? _refreshTimer;
  int _countdown = 0;
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
    });
    
    if (widget.deviceIP != null && widget.deviceIP!.isNotEmpty) {
      _deviceIP = widget.deviceIP!;
      _deviceKey = widget.deviceKey;
      debugPrint('Using provided device IP: $_deviceIP');
      await _refreshData();
    } else if (widget.petId != null) {
      try {
        // Get device details from pet ID
        debugPrint('Getting device for pet ID: ${widget.petId}');
        final deviceAssignment = await SupabaseService.getPrimaryDeviceForPet(widget.petId!);
        
        if (deviceAssignment != null) {
          debugPrint('Found device assignment: $deviceAssignment');
          _deviceKey = deviceAssignment['device_key'];
          
          if (_deviceKey != null) {
            // First try to get device IP from local storage
            String? storedIP = await DeviceCommunicationService.getDeviceIP(_deviceKey!);
            
            if (storedIP != null && storedIP.isNotEmpty) {
              debugPrint('Using stored IP address: $storedIP');
              _deviceIP = storedIP;
            } else {
              // If not found in local storage, get from database
              final deviceDetails = await SupabaseService.getDevice(_deviceKey!);
              if (deviceDetails != null && deviceDetails['ip_address'] != null && deviceDetails['ip_address'].isNotEmpty) {
                _deviceIP = deviceDetails['ip_address'];
                debugPrint('Using IP from database: $_deviceIP');
                
                // Save for future use
                await DeviceCommunicationService.saveDeviceIP(_deviceKey!, _deviceIP);
              } else {
                _showError('Device IP address not found. Please make sure the device is on and connected.');
                setState(() {
                  _isLoading = false;
                });
                return;
              }
            }
            
            // Now try to refresh with the obtained IP
            await _refreshData();
          } else {
            _showError('Device key not found in assignment.');
          }
        } else {
          _showError('No device assigned to this pet.');
        }
      } catch (e) {
        _showError('Error: $e');
      }
    } else {
      _showError('No pet ID or device IP provided');
    }
    
    setState(() {
      _isLoading = false;
    });
    
    // Start refresh timer for frequent updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      }
      
      // Get real-time updates from ESP32 every 5 seconds
      if (timer.tick % 5 == 0) {
        _quickRefreshFromESP32();
      }
      
      // Full refresh every 15 seconds
      if (timer.tick % 15 == 0) {
        _refreshData();
      }
    });
  }
  
  Future<void> _refreshData() async {
    if (_deviceIP.isEmpty) {
      debugPrint('Device IP is empty, cannot refresh data');
      return;
    }
    
    try {
      debugPrint('\n========== REFRESHING DEVICE DATA ==========');
      debugPrint('Device IP: $_deviceIP');
      
      // First, try to get device details from Supabase
      Map<String, dynamic>? databaseDevice;
      if (_deviceKey != null && _deviceKey!.isNotEmpty) {
        databaseDevice = await SupabaseService.getDevice(_deviceKey!);
        debugPrint('Database device details: $databaseDevice');
        
        // Print all keys in device object to find correct field name
        if (databaseDevice != null) {
          debugPrint('Device database keys: ${databaseDevice.keys.join(', ')}');
          databaseDevice.forEach((key, value) {
            debugPrint('Device DB field $key = $value');
          });
          
          // Attempt to fetch active feeding schedules for this device
          try {
            final schedules = await SupabaseService.fetchFeedingSchedules(_deviceKey!);
            if (schedules.isNotEmpty) {
              debugPrint('Found ${schedules.length} active feeding schedules for device');
              // Take the first active schedule
              _scheduleStatus = schedules.first;
              debugPrint('Active schedule from database: $_scheduleStatus');
            } else {
              debugPrint('No active schedules found in database');
              _scheduleStatus = null; // Önemli: database'de schedule yoksa null olarak ayarla
            }
          } catch (e) {
            debugPrint('Error fetching schedules from database: $e');
          }
        }
      } else {
        debugPrint('No device key available, skipping database fetch');
      }
      
      // Get device status from ESP32
      final status = await DeviceCommunicationService.getDeviceStatus(_deviceIP);
      debugPrint('Received device status from ESP32: $status');
      
      // Get schedule status if device status was successful
      Map<String, dynamic>? schedule;
      if (status != null) {
        schedule = await DeviceCommunicationService.getScheduleStatus(_deviceIP);
        debugPrint('Received schedule status from ESP32: $schedule');
        
        // Önemli kontrol: ESP32 aktif schedule bildirdiyse, kullan
        if (schedule != null && schedule.containsKey('active') && schedule['active'] == true) {
          _scheduleStatus = schedule;
          debugPrint('Using ESP32 active schedule');
        } 
        // ESP32 hiçbir aktif schedule bildirmediyse ve _scheduleStatus != null ise
        else if (schedule == null || !schedule.containsKey('active') || schedule['active'] != true) {
          debugPrint('ESP32 reports no active schedule');
          if (_scheduleStatus != null) {
            debugPrint('Clearing schedule status as ESP32 reports none');
            _scheduleStatus = null;
          }
        }
      } else {
        debugPrint('Skipping schedule status request as device status failed');
      }
      
      if (mounted) {
        setState(() {
          // Combine data from both sources
          Map<String, dynamic> combinedStatus = {
            'ip': _deviceIP,
            'connected': false,
            'ssid': 'Unknown',
            'current_time': DateTime.now().toString(),
          };
          
          // If we have database info, add it first (will be overridden by ESP32 data if available)
          if (databaseDevice != null) {
            combinedStatus['connected'] = databaseDevice['is_paired'] == true;
            combinedStatus['device_key'] = databaseDevice['device_key'];
            
            // Try different possible field names for WiFi network
            String wifiNetwork = 'Unknown';
            if (databaseDevice.containsKey('wifi_ssid')) {
              wifiNetwork = databaseDevice['wifi_ssid'] ?? 'Unknown';
              debugPrint('Found wifi network in "wifi_ssid": $wifiNetwork');
            } else if (databaseDevice.containsKey('ssid')) {
              wifiNetwork = databaseDevice['ssid'] ?? 'Unknown';
              debugPrint('Found wifi network in "ssid": $wifiNetwork');
            } else if (databaseDevice.containsKey('network')) {
              wifiNetwork = databaseDevice['network'] ?? 'Unknown';
              debugPrint('Found wifi network in "network": $wifiNetwork');
            } else if (databaseDevice.containsKey('wifi_network')) {
              wifiNetwork = databaseDevice['wifi_network'] ?? 'Unknown';
              debugPrint('Found wifi network in "wifi_network": $wifiNetwork');
            }
            combinedStatus['ssid'] = wifiNetwork;
            
            combinedStatus['device_name'] = databaseDevice['name'] ?? 'Pet Feeder';
            combinedStatus['last_online'] = databaseDevice['last_online'];
            combinedStatus['food_level'] = databaseDevice['food_level'];
            combinedStatus['is_registered'] = true;
            
            // Update device key if we didn't have it before
            if (_deviceKey == null || _deviceKey!.isEmpty) {
              _deviceKey = databaseDevice['device_key'];
              debugPrint('Updated device key from database: $_deviceKey');
            }
          }
          
          // If we have ESP32 status, add it (overriding database values)
          if (status != null) {
            // Store the wifi_ssid in a temporary variable before overriding
            String? storedWifiSSID = combinedStatus['ssid'];
            debugPrint('Saving wifi network before ESP32 merge: $storedWifiSSID');
            
            // Merge everything from ESP32 status
            status.forEach((key, value) {
              if (value != null) {
                combinedStatus[key] = value;
              }
            });
            
            // Always set connected to true if we got a successful response from ESP32
            combinedStatus['connected'] = true;
            
            // If ESP32 didn't provide a ssid value, use the one from database
            if ((!status.containsKey('ssid') || status['ssid'] == 'Unknown') && storedWifiSSID != 'Unknown') {
              combinedStatus['ssid'] = storedWifiSSID;
              debugPrint('Restored wifi network from database: $storedWifiSSID');
            }
            
            // Update device key if it was in the response and we don't have it yet
            if (status.containsKey('device_key') && (_deviceKey == null || _deviceKey!.isEmpty)) {
              _deviceKey = status['device_key'];
              debugPrint('Updated device key from ESP32: $_deviceKey');
            }
          }
          
          // Set the final combined status
          _deviceStatus = combinedStatus;
          debugPrint('Combined device status: $_deviceStatus');
          
          // Son ESP32 schedule durumuna göre countdown'ı güncelle
          _setCountdownFromSchedule();
        });
      }
      
      debugPrint('========== REFRESH COMPLETE ==========\n');
    } catch (e) {
      debugPrint('Error in _refreshData: $e');
      if (mounted) {
        _showError('Veri yenileme hatası: $e');
        
        // Still update UI with error state
        setState(() {
          _deviceStatus = {
            'ip': _deviceIP,
            'connected': false,
            'ssid': 'Error: ${e.toString().substring(0, min(30, e.toString().length))}...',
            'current_time': DateTime.now().toString(),
          };
        });
      }
    }
  }
  
  Future<void> _manualFeed() async {
    if (_deviceIP.isEmpty) {
      _showError('Device IP not found');
      return;
    }

    if (_deviceKey == null) {
      // Try to get device key from Supabase if not provided
      try {
        final deviceDetails = await SupabaseService.findDeviceByKey(_deviceIP);
        if (deviceDetails != null) {
          _deviceKey = deviceDetails['device_key'];
        }
      } catch (e) {
        _showError('Error getting device key: $e');
        return;
      }

      if (_deviceKey == null) {
        _showError('Device key not found');
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Save the current network name before feed operation, if available
      String? currentWifiSSID = null;
      if (_deviceStatus != null) {
        if (_deviceStatus!.containsKey('ssid') && _deviceStatus!['ssid'] != null) {
          currentWifiSSID = _deviceStatus!['ssid'].toString();
        } else if (_deviceStatus!.containsKey('wifi_ssid') && _deviceStatus!['wifi_ssid'] != null) {
          currentWifiSSID = _deviceStatus!['wifi_ssid'].toString();
        }
      }

      final result = await DeviceCommunicationService.feedNow(_deviceKey!, 50.0); // Default 50 grams
      if (result['success']) {
        _showSuccess('Manual feeding started!');
        
        // If we have the wifi network info but it wasn't passed to device update,
        // explicitly update it in the database
        if (currentWifiSSID != null && currentWifiSSID != 'Unknown') {
          try {
            debugPrint('Explicitly updating wifi_ssid in database after feed: $currentWifiSSID');
            Map<String, dynamic> updates = {
              'wifi_ssid': currentWifiSSID,
              'last_online': DateTime.now().toIso8601String(),
            };
            await SupabaseService.updateDevice(_deviceKey!, updates);
          } catch (e) {
            debugPrint('Error updating wifi_ssid in database: $e');
            // Continue even if this fails
          }
        }
        
        await _refreshData();
      } else {
        String errorMsg = 'Manual feeding failed';
        
        // More detailed message based on error type
        if (result['error'] == 'TIMEOUT') {
          errorMsg = 'Connection timeout. Device might be offline.';
        } else if (result['error'] == 'CONNECTION_FAILED') {
          errorMsg = 'Cannot connect to device. Check if it\'s powered on.';
        } else if (result['error'] == 'INSUFFICIENT_FOOD') {
          errorMsg = 'Not enough food. Please refill the container.';
        } else if (result.containsKey('message')) {
          errorMsg = result['message'];
        }
        
        _showError(errorMsg);
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _disableSchedule() async {
    if (_deviceIP.isEmpty) {
      _showError('Device IP not available');
      return;
    }
    
    if (_deviceKey == null || _deviceKey!.isEmpty) {
      _showError('Device key not available');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      debugPrint('\n========== DISABLING SCHEDULE ==========');
      debugPrint('Device IP: $_deviceIP');
      debugPrint('Device Key: $_deviceKey');
      
      // İptal isteğini 3 kez deneyelim - daha güvenilir olması için
      bool success = false;
      for (int attempt = 1; attempt <= 3; attempt++) {
        debugPrint('Attempt $attempt to disable schedule...');
        final result = await DeviceCommunicationService.disableSchedule(_deviceIP);
        
        if (result) {
          success = true;
          debugPrint('✅ Schedule disabled successfully on attempt $attempt');
          break;
        } else {
          debugPrint('❌ Failed to disable schedule on attempt $attempt');
          // Kısa bir süre bekle ve tekrar dene
          if (attempt < 3) {
            debugPrint('Waiting before next attempt...');
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      
      if (success) {
        _showSuccess('Schedule disabled');
        
        // Also update device info in database with the latest data since we know the device is online
        try {
          final status = await DeviceCommunicationService.getDeviceStatus(_deviceIP);
          if (status != null) {
            Map<String, dynamic> updates = {
              'last_online': DateTime.now().toIso8601String(),
            };
            
            // Update WiFi network name if we got it
            if (status.containsKey('ssid') && status['ssid'] != null) {
              updates['wifi_ssid'] = status['ssid'];
              debugPrint('Updating WiFi SSID in database: ${status['ssid']}');
            }
            
            if (status.containsKey('food_level')) {
              updates['food_level'] = status['food_level'];
            }
            
            await SupabaseService.updateDevice(_deviceKey!, updates);
            debugPrint('Updated device info in database after disabling schedule');
          }
        } catch (e) {
          debugPrint('Error updating device info: $e');
          // Continue even if this fails
        }
        
        // İptal işleminin ESP32'ye tam olarak ulaştığından emin olmak için kısa bir süre bekle
        await Future.delayed(const Duration(seconds: 2));
        
        // Durumu yenile
        await _refreshData();
      } else {
        _showError('Failed to disable schedule after multiple attempts');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  String _formatCountdown(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    // If total time is less than 60 seconds, show only seconds with "s" suffix
    if (hours == 0 && minutes == 0) {
      return '${remainingSeconds}s';
    }
    
    // Less than 1 hour but more than 1 minute
    if (hours == 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    
    // Standard format for hours:minutes:seconds
    return '${hours}h ${minutes}m ${remainingSeconds}s';
  }
  
  // Format date string from ISO format to readable format
  String _formatDate(String isoDateString) {
    try {
      final dateTime = DateTime.parse(isoDateString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_deviceIP.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text(
                        'Device not found',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please make sure the device is connected',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device status
                      _buildStatusCard(
                        title: 'Device Status',
                        icon: Icons.devices,
                        color: Colors.green,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatusRow('Device Name', _deviceStatus?.containsKey('device_name') == true 
                              ? _deviceStatus!['device_name'] 
                              : 'Pet Feeder Device'),
                            _buildStatusRow('IP Address', _deviceIP),
                            _buildStatusRow('Connection', 
                              _deviceStatus?.containsKey('connected') == true && _deviceStatus!['connected'] == true
                                ? 'Connected'
                                : 'Disconnected'),
                            _buildStatusRow('Wi-Fi Network', 
                              _getWifiNetworkName(_deviceStatus)),
                            if (_deviceStatus != null && _deviceStatus!.containsKey('rssi')) ...[
                              _buildStatusRow('Signal Strength', '${_deviceStatus!['rssi']} dBm'),
                            ],
                            _buildStatusRow('Current Time', _deviceStatus?.containsKey('current_time') == true 
                              ? _deviceStatus!['current_time'] 
                              : DateTime.now().toString()),
                            if (_deviceStatus != null && _deviceStatus!.containsKey('device_uptime_seconds')) ...[
                              _buildStatusRow('Uptime', '${(_deviceStatus!['device_uptime_seconds'] / 3600).toStringAsFixed(1)} hours'),
                            ],
                            if (_deviceStatus != null && _deviceStatus!.containsKey('food_level')) ...[
                              _buildStatusRow('Food Level', '${_deviceStatus!['food_level'].toString()}%'),
                            ],
                            
                            // Manual feed button
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.restaurant),
                                label: const Text('Feed Now'),
                                onPressed: _manualFeed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Schedule status and countdown
                      if (_scheduleStatus != null) ...[
                        _buildStatusCard(
                          title: 'Next Feeding',
                          icon: Icons.timer,
                          color: Colors.blue,
                          child: Column(
                            children: [
                              // Big countdown timer
                              Text(
                                _formatCountdown(_countdown),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Schedule details
                              Text(
                                'Frequency: ${_getReadableFrequency(_scheduleStatus!.containsKey('frequency') ? _scheduleStatus!['frequency'] ?? 'unknown' : 'unknown')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (_scheduleStatus!.containsKey('frequency') && _scheduleStatus!['frequency'] != 'minute') ...[
                                Text(
                                  'Time: ${_scheduleStatus!.containsKey('hour') ? _scheduleStatus!['hour'].toString().padLeft(2, '0') : '00'}:${_scheduleStatus!.containsKey('minute') ? _scheduleStatus!['minute'].toString().padLeft(2, '0') : '00'}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                              Text(
                                'Amount: ${_scheduleStatus!.containsKey('amount') ? _scheduleStatus!['amount'] : 0} grams',
                                style: const TextStyle(fontSize: 16),
                              ),
                              
                              // Date range if available
                              if (_scheduleStatus!.containsKey('start_date') && _scheduleStatus!.containsKey('end_date')) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Active: ${_formatDate(_scheduleStatus!['start_date'])} to ${_formatDate(_scheduleStatus!['end_date'])}',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                              
                              // Last feeding info
                              if (_scheduleStatus!.containsKey('last_feeding_elapsed_seconds') &&
                                  _scheduleStatus!['last_feeding_elapsed_seconds'] != null &&
                                  _scheduleStatus!['last_feeding_elapsed_seconds'] > 0) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Last Feeding:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${(_scheduleStatus!['last_feeding_elapsed_seconds'] / 60).toStringAsFixed(1)} minutes ago',
                                ),
                              ],
                              
                              // Disable button
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.stop, color: Colors.red),
                                  label: const Text('Cancel Schedule', style: TextStyle(color: Colors.red)),
                                  onPressed: _disableSchedule,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        _buildStatusCard(
                          title: 'Schedule Status',
                          icon: Icons.schedule,
                          color: Colors.orange,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No active schedule',
                                style: TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Use the Feeding Schedule page to add a schedule',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildStatusCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.toString(),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getReadableFrequency(String frequency) {
    switch (frequency) {
      case 'day':
        return 'Daily';
      case 'hour':
        return 'Hourly';
      case 'minute':
        return 'Every Minute (Test)';
      case 'daily':
        return 'Daily';
      case 'twice-daily':
        return 'Twice Daily';
      case 'custom':
        return 'Custom';
      default:
        return frequency;
    }
  }
  
  String _getWifiNetworkName(Map<String, dynamic>? deviceStatus) {
    if (deviceStatus == null) {
      return 'Unknown';
    }
    
    // Önce 'ssid' alanını kontrol et
    if (deviceStatus.containsKey('ssid') && 
        deviceStatus['ssid'] != null && 
        deviceStatus['ssid'] != 'Unknown') {
      return deviceStatus['ssid'];
    }
    
    // Sonra 'wifi_ssid' alanını kontrol et
    if (deviceStatus.containsKey('wifi_ssid') && 
        deviceStatus['wifi_ssid'] != null && 
        deviceStatus['wifi_ssid'] != 'Unknown') {
      return deviceStatus['wifi_ssid'];
    }
    
    return 'Unknown';
  }
  
  // Helper to set countdown based on schedule info
  void _setCountdownFromSchedule() {
    // Schedule yok ise countdown 0 olsun
    if (_scheduleStatus == null) {
      _countdown = 0;
      debugPrint('No schedule available, setting countdown to 0');
      return;
    }
    
    // Special handling for "minute" frequency
    if (_scheduleStatus!.containsKey('frequency') && _scheduleStatus!['frequency'] == 'minute') {
      // For "minute" frequency, we know the next feeding is within a minute
      debugPrint('Detected "minute" frequency schedule');
      
      // If we have last_feeding_elapsed_seconds, use it to calculate remaining time
      if (_scheduleStatus!.containsKey('last_feeding_elapsed_seconds') && 
          _scheduleStatus!['last_feeding_elapsed_seconds'] != null) {
        // A full minute (60 seconds) minus the elapsed time since last feeding
        _countdown = 60 - (_scheduleStatus!['last_feeding_elapsed_seconds'] as num).toInt();
        if (_countdown < 0) _countdown = 0; // Avoid negative values
        debugPrint('Setting countdown for minute frequency: $_countdown seconds');
      } else {
        // Default to 60 seconds if we don't have elapsed time info
        _countdown = 60;
        debugPrint('Setting default 60 second countdown for minute frequency');
      }
    } 
    // Regular handling for other frequencies
    else if (_scheduleStatus!.containsKey('total_next_feed_seconds')) {
      _countdown = _scheduleStatus!['total_next_feed_seconds'];
      debugPrint('Setting countdown from total_next_feed_seconds: $_countdown');
    } else if (_scheduleStatus!.containsKey('next_feed_minutes') && 
              _scheduleStatus!.containsKey('next_feed_seconds')) {
      _countdown = (_scheduleStatus!['next_feed_minutes'] * 60) + _scheduleStatus!['next_feed_seconds'];
      debugPrint('Setting countdown from next_feed_minutes/seconds: $_countdown');
    } else if (_scheduleStatus!.containsKey('next_feed_time') && _scheduleStatus!['next_feed_time'] != null) {
      try {
        // Parse next feed time from ISO format
        DateTime nextFeedTime = DateTime.parse(_scheduleStatus!['next_feed_time']);
        DateTime now = DateTime.now();
        
        // Calculate seconds until next feeding
        int secondsUntil = nextFeedTime.difference(now).inSeconds;
        _countdown = secondsUntil > 0 ? secondsUntil : 0;
        
        debugPrint('Setting countdown from next_feed_time: $_countdown seconds');
      } catch (e) {
        debugPrint('Error parsing next_feed_time: $e');
        _calculateCountdownFromSchedule(_scheduleStatus!);
      }
    } else if (_scheduleStatus!.containsKey('active') && _scheduleStatus!['active'] == true) {
      _calculateCountdownFromSchedule(_scheduleStatus!);
    } else {
      _countdown = 0;
      debugPrint('No countdown info found in schedule, setting to 0');
    }
  }
  
  // Calculate countdown based on schedule time and frequency
  void _calculateCountdownFromSchedule(Map<String, dynamic> schedule) {
    try {
      if (schedule.containsKey('hour') && schedule.containsKey('minute')) {
        int scheduleHour = schedule['hour'] is String ? int.parse(schedule['hour']) : schedule['hour'];
        int scheduleMinute = schedule['minute'] is String ? int.parse(schedule['minute']) : schedule['minute'];
        
        // Get current time
        DateTime now = DateTime.now();
        DateTime scheduleTime = DateTime(
          now.year, now.month, now.day, scheduleHour, scheduleMinute);
        
        // If the scheduled time is earlier today, add a day
        if (scheduleTime.isBefore(now)) {
          scheduleTime = scheduleTime.add(const Duration(days: 1));
        }
        
        // Check if schedule has start_date and end_date
        if (schedule.containsKey('start_date') && schedule.containsKey('end_date')) {
          try {
            DateTime startDate = DateTime.parse(schedule['start_date']);
            DateTime endDate = DateTime.parse(schedule['end_date']);
            
            // Check if current time is before start date
            if (now.isBefore(startDate)) {
              // Calculate seconds until start date
              DateTime scheduleStartTime = DateTime(
                startDate.year, startDate.month, startDate.day, scheduleHour, scheduleMinute);
              _countdown = scheduleStartTime.difference(now).inSeconds;
              debugPrint('Schedule starts in the future. Countdown: $_countdown seconds');
            } 
            // Check if current time is after end date
            else if (now.isAfter(endDate)) {
              debugPrint('Schedule has ended. Setting countdown to 0');
              _countdown = 0;
            } 
            // Otherwise use the regular calculation
            else {
              _countdown = scheduleTime.difference(now).inSeconds;
              debugPrint('Calculated countdown from hour/minute: $_countdown seconds');
            }
          } catch (e) {
            debugPrint('Error parsing date range: $e');
            _countdown = scheduleTime.difference(now).inSeconds;
          }
        } else {
          // Calculate seconds until next feeding without date checking
          _countdown = scheduleTime.difference(now).inSeconds;
          debugPrint('Calculated countdown from hour/minute: $_countdown seconds');
        }
      } else {
        debugPrint('Schedule has active=true but missing hour/minute');
        _countdown = 0;
      }
    } catch (e) {
      debugPrint('Error calculating countdown: $e');
      _countdown = 0;
    }
  }
  
  // Light-weight refresh just to get countdown from ESP32
  Future<void> _quickRefreshFromESP32() async {
    if (_deviceIP.isEmpty) {
      return;
    }
    
    try {
      debugPrint('Performing quick refresh from ESP32...');
      
      // Just get schedule status from ESP32 to update countdown
      final schedule = await DeviceCommunicationService.getScheduleStatus(_deviceIP);
      if (schedule != null && mounted) {
        debugPrint('ESP32 returned schedule: $schedule');
        
        setState(() {
          // Update schedule status with latest from ESP32
          _scheduleStatus = schedule;
          
          // For minute frequency, handle special
          if (_scheduleStatus!.containsKey('frequency') && 
              _scheduleStatus!['frequency'] == 'minute') {
            
            debugPrint('Processing minute-based feeding schedule');
            
            // If we have seconds_remaining, use it directly
            if (_scheduleStatus!.containsKey('seconds_remaining')) {
              int seconds = (_scheduleStatus!['seconds_remaining'] as num).toInt();
              debugPrint('Setting countdown to seconds_remaining: $seconds');
              _countdown = seconds;
            }
            // If we have interval_seconds (for interval-based feeding)
            else if (_scheduleStatus!.containsKey('interval_seconds')) {
              int seconds = (_scheduleStatus!['interval_seconds'] as num).toInt();
              debugPrint('Setting countdown based on interval_seconds: $seconds');
              _countdown = seconds;
            }
            // Otherwise calculate from last_feeding_elapsed_seconds
            else if (_scheduleStatus!.containsKey('last_feeding_elapsed_seconds')) {
              int elapsed = (_scheduleStatus!['last_feeding_elapsed_seconds'] as num).toInt();
              _countdown = 60 - elapsed;
              if (_countdown < 0) _countdown = 0;
              debugPrint('Calculated countdown from elapsed time: $_countdown');
            } else {
              // Default for minute based feeding
              _countdown = 60;
              debugPrint('Using default 60 second countdown for minute-based feeding');
            }
          } else {
            // For other frequencies, update normally
            _setCountdownFromSchedule();
          }
        });
      } else {
        debugPrint('ESP32 did not return any schedule data');
      }
    } catch (e) {
      debugPrint('Quick ESP32 refresh error: $e');
    }
  }
} 