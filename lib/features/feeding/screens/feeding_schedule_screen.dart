import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../device/providers/device_provider.dart';

class FeedingSchedule {
  final String id;
  final String deviceId;
  final DateTime startDate;
  final DateTime endDate;
  final String frequency;
  final TimeOfDay startTime;
  final double amount;
  final bool isActive;

  FeedingSchedule({
    required this.id,
    required this.deviceId,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required this.startTime,
    required this.amount,
    this.isActive = true,
  });
}

class FeedingScheduleScreen extends StatefulWidget {
  final String petId;
  
  const FeedingScheduleScreen({Key? key, required this.petId}) : super(key: key);

  @override
  State<FeedingScheduleScreen> createState() => _FeedingScheduleScreenState();
}

class _FeedingScheduleScreenState extends State<FeedingScheduleScreen> {
  bool _isLoading = false;
  List<FeedingSchedule> _schedules = [];
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // In a real app, fetch schedules from the device provider
      final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
      // This is a placeholder. In your real app, you would fetch real schedules
      // for this specific pet from your backend.
      
      // For demo, creating some sample schedules
      _schedules = [
        FeedingSchedule(
          id: '1',
          deviceId: widget.petId,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          frequency: 'daily',
          startTime: const TimeOfDay(hour: 8, minute: 0),
          amount: 50,
        ),
        FeedingSchedule(
          id: '2',
          deviceId: widget.petId,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          frequency: 'daily',
          startTime: const TimeOfDay(hour: 18, minute: 0),
          amount: 50,
        ),
      ];
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading schedules: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addSchedule() async {
    // Show dialog to add a new schedule
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddScheduleDialog(petId: widget.petId),
    );
    
    if (result == true) {
      _loadSchedules();
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeding Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Feeding Schedules',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your first schedule to get started',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Schedule'),
                        onPressed: _addSchedule,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Automatic Feeding Times',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _schedules.length,
                          itemBuilder: (context, index) {
                            final schedule = _schedules[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Daily at ${_formatTimeOfDay(schedule.startTime)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Switch(
                                          value: schedule.isActive,
                                          onChanged: (value) {
                                            // Update schedule active status
                                            setState(() {
                                              _schedules[index] = FeedingSchedule(
                                                id: schedule.id,
                                                deviceId: schedule.deviceId,
                                                startDate: schedule.startDate,
                                                endDate: schedule.endDate,
                                                frequency: schedule.frequency,
                                                startTime: schedule.startTime,
                                                amount: schedule.amount,
                                                isActive: value,
                                              );
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Amount: ${schedule.amount.toInt()} grams',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date Range: ${_dateFormat.format(schedule.startDate)} - ${_dateFormat.format(schedule.endDate)}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.edit, size: 18),
                                          label: const Text('Edit'),
                                          onPressed: () {
                                            // Show edit dialog
                                          },
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          onPressed: () {
                                            // Show delete confirmation
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Schedule'),
                                                content: const Text('Are you sure you want to delete this feeding schedule?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                      setState(() {
                                                        _schedules.removeAt(index);
                                                      });
                                                    },
                                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSchedule,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddScheduleDialog extends StatefulWidget {
  final String petId;
  
  const AddScheduleDialog({Key? key, required this.petId}) : super(key: key);

  @override
  State<AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<AddScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Schedule settings
  TimeOfDay _selectedTime = TimeOfDay.now();
  double _amount = 50;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String _frequency = 'daily';
  
  final List<String> _frequencies = ['daily', 'twice-daily', 'custom'];
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate.add(const Duration(days: 1)),
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365)),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Feeding Schedule'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time picker
              ListTile(
                title: const Text('Feeding Time'),
                subtitle: Text('${_selectedTime.format(context)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context),
              ),
              const SizedBox(height: 8),
              
              // Amount slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount: ${_amount.toInt()} grams'),
                  Slider(
                    value: _amount,
                    min: 10,
                    max: 200,
                    divisions: 19,
                    label: _amount.toInt().toString(),
                    onChanged: (value) {
                      setState(() {
                        _amount = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Frequency dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                value: _frequency,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _frequency = newValue;
                    });
                  }
                },
                items: _frequencies.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.replaceAll('-', ' ').capitalize()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // Date Range
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Date'),
                      subtitle: Text(
                        '${_startDate.year}/${_startDate.month}/${_startDate.day}',
                      ),
                      onTap: () => _selectStartDate(context),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Date'),
                      subtitle: Text(
                        '${_endDate.year}/${_endDate.month}/${_endDate.day}',
                      ),
                      onTap: () => _selectEndDate(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // In a real app, you would save the schedule to your backend
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Add Schedule'),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 