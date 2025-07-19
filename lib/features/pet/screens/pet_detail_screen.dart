import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pet_provider.dart';
import '../../../core/services/device_communication_service.dart';
import 'edit_pet_screen.dart';
import '../../feeding/screens/feeding_schedule_screen.dart';
import '../../feeding/screens/feeding_history_screen.dart';
import 'dart:async';

class PetDetailScreen extends StatefulWidget {
  const PetDetailScreen({Key? key}) : super(key: key);

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  bool _isLoading = false;
  bool _isFeeding = false;
  double _feedAmount = 50.0; // Default feed amount in grams
  double? _foodLevel; // Food level percentage (0-100%) - will be loaded from database
  bool _isFemale = true; // Default gender
  String _deviceKey = ''; // Add this line
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFoodLevel();
    _loadDeviceKey();
    // Start periodic refresh of food level
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadFoodLevel();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFoodLevel() async {
    final petProvider = Provider.of<PetProvider>(context, listen: false);
    final foodLevel = await petProvider.getCurrentDeviceFoodLevel();
    if (mounted) {
      setState(() {
        _foodLevel = foodLevel;
      });
    }
  }

  Future<void> _loadDeviceKey() async {
    final petProvider = Provider.of<PetProvider>(context, listen: false);
    final deviceKey = await petProvider.getDeviceKey();
    if (mounted) {
      setState(() {
        _deviceKey = deviceKey ?? 'Not available';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final petProvider = Provider.of<PetProvider>(context);
    final pet = petProvider.currentPet;

    if (pet == null) {
      return const Scaffold(
        body: Center(
          child: Text('No pet selected'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditPetScreen(pet: pet),
                ),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Pet'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Pet'),
                    content: Text('Are you sure you want to delete ${pet.name}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  try {
                    await petProvider.deletePet(pet.id);
                    if (context.mounted) {
                      Navigator.of(context).pop(); // Go back to pets list
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting pet: $e')),
                      );
                    }
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pet Information Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pet Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Name', pet.name),
                          _buildInfoRow('Age', '${pet.age} years'),
                          _buildInfoRow('Weight', '${pet.weight} kg'),
                          _buildInfoRow('Gender', pet.isFemale ? 'Female' : 'Male'),
                          _buildInfoRow('Device Key', _deviceKey),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Manual Feeding Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manual Feeding',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Food Level Indicator
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.food_bank),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _foodLevel != null 
                                        ? 'Food Level: ${_foodLevel!.toStringAsFixed(1)}%'
                                        : 'Food Level: Loading...',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    LayoutBuilder(
                                      builder: (context, constraints) => SizedBox(
                                        width: constraints.maxWidth,
                                        child: _foodLevel != null
                                          ? LinearProgressIndicator(
                                              value: (_foodLevel! / 100.0).clamp(0.0, 1.0),
                                              backgroundColor: Colors.grey[200],
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                _foodLevel! > 20 ? Colors.green : Colors.red,
                                              ),
                                            )
                                          : LinearProgressIndicator(
                                              backgroundColor: Colors.grey[200],
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                                            ),
                                      ),
                                    ),
                                    if (_foodLevel != null && _foodLevel! <= 20)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Low food level! Please refill.',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Amount: ${_feedAmount.toInt()} grams'),
                          Slider(
                            value: _feedAmount,
                            min: 10,
                            max: 200,
                            divisions: 19,
                            label: _feedAmount.toInt().toString(),
                            onChanged: (value) {
                              setState(() {
                                _feedAmount = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.restaurant),
                                  label: const Text('Feed Now'),
                                  onPressed: () => _feedPet(petProvider),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Feeding Schedule Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: const Text('Manage Feeding Schedule'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FeedingScheduleScreen(petId: pet.id),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Feeding History Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('View Feeding History'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FeedingHistoryScreen(petId: pet.id),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _feedPet(PetProvider petProvider) async {
    setState(() {
      _isLoading = true;
      _isFeeding = true;
    });
    
    try {
      // Get device key
      final deviceKey = await petProvider.getDeviceKey();
      if (deviceKey == null) {
        throw Exception('Device key not found');
      }
      
      // Send feed command to ESP32 device
      final result = await DeviceCommunicationService.feedNow(
        deviceKey,
        _feedAmount,
      );
      
      if (result['success']) {
        // Load new food level
        await _loadFoodLevel();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully fed ${_feedAmount.toInt()} grams')),
          );
        }
      } else {
        String errorMsg = 'Failed to send feed command';
        
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
        
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error feeding pet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isFeeding = false;
      });
    }
  }
} 