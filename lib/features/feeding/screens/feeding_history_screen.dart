import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';

class FeedingRecord {
  final String id;
  final String petId;
  final double amount;
  final DateTime feedingTime;
  final String feedingType;
  final String? deviceId;
  final String? deviceKey;
  final String petName;

  FeedingRecord({
    required this.id,
    required this.petId,
    required this.amount,
    required this.feedingTime,
    required this.feedingType,
    this.deviceId,
    this.deviceKey,
    required this.petName,
  });

  factory FeedingRecord.fromJson(Map<String, dynamic> json) {
    return FeedingRecord(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      feedingTime: DateTime.parse(json['feeding_time'] as String),
      feedingType: json['feeding_type'] as String,
      deviceId: json['device_id'] as String?,
      deviceKey: json['devices']?['device_key'] as String?,
      petName: json['pets']?['name'] as String? ?? 'Unknown Pet',
    );
  }
}

class FeedingHistoryScreen extends StatefulWidget {
  final String? petId;

  const FeedingHistoryScreen({
    Key? key,
    this.petId,
  }) : super(key: key);

  @override
  State<FeedingHistoryScreen> createState() => _FeedingHistoryScreenState();
}

class _FeedingHistoryScreenState extends State<FeedingHistoryScreen> {
  bool _isLoading = false;
  List<FeedingRecord> _feedingRecords = [];
  List<FeedingRecord> _filteredRecords = [];
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  // Filter states
  String? _selectedPetId;
  String? _selectedDeviceKey;
  DateTimeRange? _selectedDateRange;
  
  // Lists for dropdowns
  List<Map<String, String>> _pets = [];  // [{id: name}]
  List<String> _deviceKeys = [];

  @override
  void initState() {
    super.initState();
    // Set initial pet selection if navigated from pet detail screen
    _selectedPetId = widget.petId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Always load all feeding records to support clearing filters
      final records = await SupabaseService.fetchAllFeedingRecords();
          
      final feedingRecords = records.map((record) => FeedingRecord.fromJson(record)).toList();
      
      // Use a Map to properly deduplicate pets
      final petsMap = <String, String>{};  // Map of id to name
      final devicesSet = <String>{};
      
      for (var record in feedingRecords) {
        petsMap[record.petId] = record.petName;  // This automatically handles deduplication
        if (record.deviceKey != null) {
          devicesSet.add(record.deviceKey!);
        }
      }
      
      setState(() {
        _feedingRecords = feedingRecords;
        _pets = petsMap.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
        _deviceKeys = devicesSet.toList();
      });

      // Apply initial filters if pet is selected
      if (_selectedPetId != null) {
        _applyFilters();
      } else {
        _filteredRecords = feedingRecords;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feeding history: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRecords = _feedingRecords.where((record) {
        // Pet filter
        if (_selectedPetId != null && record.petId != _selectedPetId) {
          return false;
        }
        
        // Device filter
        if (_selectedDeviceKey != null && record.deviceKey != _selectedDeviceKey) {
          return false;
        }
        
        // Date range filter
        if (_selectedDateRange != null) {
          final recordDate = DateTime(
            record.feedingTime.year,
            record.feedingTime.month,
            record.feedingTime.day,
          );
          
          if (recordDate.isBefore(_selectedDateRange!.start) ||
              recordDate.isAfter(_selectedDateRange!.end)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = _selectedDateRange ?? 
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );
        
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );
    
    if (pickedRange != null) {
      setState(() {
        _selectedDateRange = pickedRange;
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedPetId = null;
      _selectedDeviceKey = null;
      _selectedDateRange = null;
      _filteredRecords = _feedingRecords;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final recordDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (recordDate == DateTime(now.year, now.month, now.day)) {
      return 'Today at ${_timeFormat.format(dateTime)}';
    } else if (recordDate == yesterday) {
      return 'Yesterday at ${_timeFormat.format(dateTime)}';
    } else {
      return '${_dateFormat.format(dateTime)} at ${_timeFormat.format(dateTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeding History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setState) => Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Filter Feeding History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Pet dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedPetId,
                          decoration: const InputDecoration(
                            labelText: 'Select Pet',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Pets'),
                            ),
                            ..._pets.map((pet) => DropdownMenuItem(
                              value: pet['id'],
                              child: Text(pet['name']!),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedPetId = value;
                            });
                            _applyFilters();
                          },
                        ),
                        const SizedBox(height: 16),
                        // Device dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedDeviceKey,
                          decoration: const InputDecoration(
                            labelText: 'Select Device',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Devices'),
                            ),
                            ..._deviceKeys.map((key) => DropdownMenuItem(
                              value: key,
                              child: Text(key),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedDeviceKey = value;
                            });
                            _applyFilters();
                          },
                        ),
                        const SizedBox(height: 16),
                        // Date range picker
                        ListTile(
                          title: Text(
                            _selectedDateRange != null
                                ? '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}'
                                : 'Select Date Range',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: _selectDateRange,
                        ),
                        const SizedBox(height: 16),
                        // Clear filters button
                        ElevatedButton(
                          onPressed: () {
                            _clearFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Feeding History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Feeding records will appear here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = _filteredRecords[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          record.feedingType == 'manual'
                              ? Icons.restaurant
                              : Icons.schedule,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          '${record.amount.toInt()} grams for ${record.petName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatDateTime(record.feedingTime)),
                            Text(
                              'Type: ${record.feedingType == 'manual' ? 'Manual Feed' : 'Scheduled Feed'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            if (record.deviceKey != null)
                              Text(
                                'Device: ${record.deviceKey}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
} 