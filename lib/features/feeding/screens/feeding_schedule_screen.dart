import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';
import 'package:pet_feeder/core/services/device_communication_service.dart';
import 'package:pet_feeder/features/feeding/screens/feeding_schedule_status_screen.dart';

class FeedingSchedule {
  final String id;
  final String petId;
  final DateTime startDate;
  final DateTime endDate;
  final String frequency;
  final TimeOfDay startTime;
  final double amount;

  FeedingSchedule({
    required this.id,
    required this.petId,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required this.startTime,
    required this.amount,
  });
  
  // Convert TimeOfDay to string for database storage
  static String timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  // Convert string to TimeOfDay for app usage
  static TimeOfDay stringToTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
  
  // Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'frequency': frequency,
      'start_time': timeOfDayToString(startTime),
      'amount': amount,
    };
  }
  
  // Create from JSON from database
  factory FeedingSchedule.fromJson(Map<String, dynamic> json) {
    // Convert old frequency values to new ones
    String frequency = json['frequency'] as String;
    if (frequency == 'daily') frequency = 'day';
    if (frequency == 'twice-daily') frequency = 'day';
    if (frequency == 'custom') frequency = 'day';
    
    return FeedingSchedule(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      frequency: frequency,
      startTime: stringToTimeOfDay(json['start_time'] as String),
      amount: (json['amount'] as num).toDouble(),
    );
  }
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
      // Fetch schedules from Supabase
      final response = await SupabaseService.fetchFeedingSchedules(widget.petId);
      
      // Convert response to schedules
      _schedules = response.map((data) => FeedingSchedule.fromJson(data)).toList();
      
      debugPrint('Loaded ${_schedules.length} feeding schedules from Supabase');
    } catch (e) {
      debugPrint('Error loading schedules: $e');
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

  Future<void> _diagnoseDatabaseIssues() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check the feeding_schedules table
      final tableInfo = await SupabaseService.getTableInfo('feeding_schedules');
      
      // Show diagnostic info in a dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Database Diagnostic'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Table Structure Information:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(tableInfo),
                  const SizedBox(height: 16),
                  const Text(
                    'Required Columns for feeding_schedules:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('''
- id (UUID, primary key)
- pet_id (UUID, foreign key to pets)
- start_date (timestamp with time zone)
- end_date (timestamp with time zone)
- frequency (text)
- start_time (text)
- amount (numeric/float)
                  '''),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running diagnostics: $e')),
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
        title: const Text('Feeding Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Schedules from Database',
            onPressed: _loadSchedules,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Database Diagnostics',
            onPressed: _diagnoseDatabaseIssues,
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
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.devices),
                        label: const Text('Check Device Status'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedingScheduleStatusScreen(petId: widget.petId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Automatic Feeding Times',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.device_hub, size: 18),
                            label: const Text('Device Status'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FeedingScheduleStatusScreen(petId: widget.petId),
                                ),
                              );
                            },
                          ),
                        ],
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
                                          schedule.frequency == 'hour' ? 'Hourly' : 'Daily at ${_formatTimeOfDay(schedule.startTime)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
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
                                          onPressed: () async {
                                            // Show edit dialog
                                            final result = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => EditScheduleDialog(
                                                schedule: schedule,
                                                petId: widget.petId,
                                              ),
                                            );
                                            
                                            if (result == true) {
                                              _loadSchedules();
                                            }
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
                                                    onPressed: () async {
                                                      Navigator.of(context).pop();
                                                      setState(() {
                                                        _isLoading = true;
                                                      });
                                                      
                                                      try {
                                                        // Delete schedule from Supabase
                                                        await SupabaseService.deleteFeedingSchedule(schedule.id);
                                                        
                                                        // Notify ESP32 to disable the schedule
                                                        // Get the primary device for this pet
                                                        final deviceAssignment = await SupabaseService.getPrimaryDeviceForPet(widget.petId);
                                                        if (deviceAssignment != null) {
                                                          final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_key']);
                                                          if (deviceDetails != null) {
                                                            String? deviceIP = await DeviceCommunicationService.getDeviceIP(deviceDetails['device_key']);
                                                            if (deviceIP == null) {
                                                              deviceIP = '192.168.1.9'; // Default IP
                                                              await DeviceCommunicationService.saveDeviceIP(deviceDetails['device_key'], deviceIP);
                                                            }
                                                            
                                                            // Disable the schedule on ESP32
                                                            await DeviceCommunicationService.disableSchedule(deviceIP);
                                                            debugPrint('Schedule disabled on ESP32');
                                                          }
                                                        }
                                                        
                                                        setState(() {
                                                          _schedules.removeAt(index);
                                                          _isLoading = false;
                                                        });
                                                        
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Schedule deleted successfully'),
                                                              backgroundColor: Colors.green,
                                                            ),
                                                          );
                                                        }
                                                      } catch (e) {
                                                        debugPrint('Error deleting schedule: $e');
                                                        setState(() {
                                                          _isLoading = false;
                                                        });
                                                        
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Error deleting schedule: $e'),
                                                              backgroundColor: Colors.red,
                                                            ),
                                                          );
                                                        }
                                                      }
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
        tooltip: 'Add New Schedule',
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
  final _dateFormat = DateFormat('MMM dd, yyyy');
  
  TimeOfDay _selectedTime = TimeOfDay.now();
  double _amount = 50.0;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  String _frequency = 'day';
  bool _isLoading = false;
  
  final List<String> _frequencies = ['day', 'hour', 'minute'];
  
  // Format TimeOfDay to string
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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

  Widget _buildFrequencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _frequency,
      decoration: const InputDecoration(
        labelText: 'Frequency',
        border: OutlineInputBorder(),
      ),
      items: _frequencies.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(() {
            if (value == 'day') return 'Daily';
            if (value == 'hour') return 'Hourly';
            if (value == 'minute') return 'Every Minute (Test)';
            return value;
          }()),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _frequency = newValue;
          });
        }
      },
    );
  }

  // Submit the form
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Get the primary device for this pet
        final deviceAssignment = await SupabaseService.getPrimaryDeviceForPet(widget.petId);
        if (deviceAssignment == null) {
          throw Exception('No device assigned to pet');
        }
        
        // Get device details
        final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_key']);
        if (deviceDetails == null) {
          throw Exception('Device not found');
        }

        // Create schedule object for Supabase
        final scheduleData = {
          'pet_id': widget.petId,
          'device_key': deviceAssignment['device_key'],
          'start_date': _startDate.toIso8601String(),
          'end_date': _endDate.toIso8601String(),
          'frequency': _frequency,
          'start_time': _frequency == 'minute' 
              ? FeedingSchedule.timeOfDayToString(TimeOfDay.now())
              : FeedingSchedule.timeOfDayToString(_selectedTime),
          'amount': _amount,
        };
        
        // Add to Supabase
        await SupabaseService.addFeedingSchedule(scheduleData);
        
        // Send to device if it's connected
        String? deviceIP = await DeviceCommunicationService.getDeviceIP(deviceDetails['device_key']);
        if (deviceIP == null) {
          deviceIP = '172.20.10.11'; // Default IP
          await DeviceCommunicationService.saveDeviceIP(deviceDetails['device_key'], deviceIP);
        }
        
        // Ensure the device time is synchronized
        await DeviceCommunicationService.setDeviceTimezone(deviceIP, timezone: 3); // Türkiye için UTC+3
        
        // Send the schedule to ESP32
        final timeStr = _frequency == 'minute' 
          ? FeedingSchedule.timeOfDayToString(TimeOfDay.now()) 
          : FeedingSchedule.timeOfDayToString(_selectedTime);
        await DeviceCommunicationService.sendScheduleCommand(
          deviceDetails['device_key'],
          frequency: _frequency,
          amount: _amount,
          startTime: timeStr,
          startDate: _startDate,
          endDate: _endDate,
        );
        
        // Show success message and close dialog
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        debugPrint('Error adding schedule: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding schedule: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Feeding Schedule'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Amount (grams)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                initialValue: _amount.toString(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
                onSaved: (value) {
                  if (value != null) {
                    _amount = double.parse(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Feeding time picker - Hide when frequency is 'minute'
              if (_frequency != 'minute') ...[
                ListTile(
                  title: const Text('Feeding Time'),
                  subtitle: Text(_formatTimeOfDay(_selectedTime)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(context),
                ),
                
                const SizedBox(height: 16),
              ],
              
              _buildFrequencyDropdown(),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(_dateFormat.format(_startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectStartDate(context),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(_dateFormat.format(_endDate)),
                      trailing: const Icon(Icons.calendar_today),
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
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Add Schedule'),
        ),
      ],
    );
  }
}

class EditScheduleDialog extends StatefulWidget {
  final FeedingSchedule schedule;
  final String petId;
  
  const EditScheduleDialog({
    Key? key,
    required this.schedule,
    required this.petId,
  }) : super(key: key);

  @override
  State<EditScheduleDialog> createState() => _EditScheduleDialogState();
}

class _EditScheduleDialogState extends State<EditScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('MMM dd, yyyy');
  
  late TimeOfDay _selectedTime;
  late double _amount;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _frequency;
  bool _isLoading = false;
  
  final List<String> _frequencies = ['day', 'hour', 'minute'];
  
  @override
  void initState() {
    super.initState();
    // Initialize with existing schedule values
    _selectedTime = widget.schedule.startTime;
    _amount = widget.schedule.amount;
    _startDate = widget.schedule.startDate;
    _endDate = widget.schedule.endDate;
    // Convert old frequency values if necessary
    _frequency = widget.schedule.frequency == 'daily' || widget.schedule.frequency == 'twice-daily' || widget.schedule.frequency == 'custom' 
        ? 'day' 
        : widget.schedule.frequency;
  }
  
  // Add _buildFrequencyDropdown method
  Widget _buildFrequencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _frequency,
      decoration: const InputDecoration(
        labelText: 'Frequency',
        border: OutlineInputBorder(),
      ),
      items: _frequencies.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(() {
            if (value == 'day') return 'Daily';
            if (value == 'hour') return 'Hourly';
            if (value == 'minute') return 'Every Minute (Test)';
            return value;
          }()),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _frequency = newValue;
          });
        }
      },
    );
  }
  
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

  // Submit the form
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Get the primary device for this pet
        final deviceAssignment = await SupabaseService.getPrimaryDeviceForPet(widget.petId);
        if (deviceAssignment == null) {
          throw Exception('No device assigned to pet');
        }
        
        // Get device details
        final deviceDetails = await SupabaseService.getDevice(deviceAssignment['device_key']);
        if (deviceDetails == null) {
          throw Exception('Device not found');
        }

        // Create schedule object for Supabase
        final scheduleData = {
          'pet_id': widget.petId,
          'device_key': deviceAssignment['device_key'],
          'start_date': _startDate.toIso8601String(),
          'end_date': _endDate.toIso8601String(),
          'frequency': _frequency,
          'start_time': _frequency == 'minute' 
              ? FeedingSchedule.timeOfDayToString(TimeOfDay.now())
              : FeedingSchedule.timeOfDayToString(_selectedTime),
          'amount': _amount,
        };
        
        // Update in Supabase
        await SupabaseService.updateFeedingSchedule(widget.schedule.id, scheduleData);
        
        // Send to device if it's connected
        String? deviceIP = await DeviceCommunicationService.getDeviceIP(deviceDetails['device_key']);
        if (deviceIP == null) {
          deviceIP = '172.20.10.11'; // Default IP
          await DeviceCommunicationService.saveDeviceIP(deviceDetails['device_key'], deviceIP);
        }
        
        // First disable any existing schedule
        await DeviceCommunicationService.disableSchedule(deviceIP);
        
        // Ensure the device time is synchronized
        await DeviceCommunicationService.setDeviceTimezone(deviceIP, timezone: 3); // Türkiye için UTC+3
        
        // Send the updated schedule to ESP32
        final timeStr = _frequency == 'minute' 
          ? FeedingSchedule.timeOfDayToString(TimeOfDay.now()) 
          : FeedingSchedule.timeOfDayToString(_selectedTime);
        await DeviceCommunicationService.sendScheduleCommand(
          deviceDetails['device_key'],
          frequency: _frequency,
          amount: _amount,
          startTime: timeStr,
          startDate: _startDate,
          endDate: _endDate,
        );
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Feeding Schedule'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time picker - Hide when frequency is 'minute'
              if (_frequency != 'minute') ...[
                ListTile(
                  title: const Text('Feeding Time'),
                  subtitle: Text('${_selectedTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(context),
                ),
                const SizedBox(height: 8),
              ],
              
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
              _buildFrequencyDropdown(),
              const SizedBox(height: 16),
              
              // Date range
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(_dateFormat.format(_startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectStartDate(context),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(_dateFormat.format(_endDate)),
                      trailing: const Icon(Icons.calendar_today),
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
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Update Schedule'),
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