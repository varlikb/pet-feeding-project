import 'package:flutter/material.dart';
import 'package:pet_feeder/core/services/feeding_scheduler_service.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class FeedingScheduleTestScreen extends StatefulWidget {
  const FeedingScheduleTestScreen({Key? key}) : super(key: key);

  @override
  State<FeedingScheduleTestScreen> createState() => _FeedingScheduleTestScreenState();
}

class _FeedingScheduleTestScreenState extends State<FeedingScheduleTestScreen> {
  final _schedulerService = FeedingSchedulerService();
  bool _isSchedulerRunning = false;
  List<Map<String, dynamic>> _recentFeedings = [];
  
  @override
  void initState() {
    super.initState();
    _loadRecentFeedings();
  }

  Future<void> _loadRecentFeedings() async {
    try {
      final response = await SupabaseService.client
          .from('feeding_records')
          .select('''
            *,
            pets!feeding_records_pet_id_fkey(*),
            feeding_schedules(*)
          ''')
          .eq('feeding_type', 'scheduled')
          .order('feeding_time', ascending: false)
          .limit(10);
          
      setState(() {
        _recentFeedings = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading recent feedings: $e');
    }
  }

  void _toggleScheduler() {
    if (_isSchedulerRunning) {
      _schedulerService.stopScheduler();
    } else {
      _schedulerService.startScheduler();
    }
    
    setState(() {
      _isSchedulerRunning = !_isSchedulerRunning;
    });
  }

  Future<void> _forceCheck() async {
    try {
      await _schedulerService.forceCheckScheduledFeedings();
      await _loadRecentFeedings(); // Refresh the list after force check
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Force check completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeding Schedule Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scheduler Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isSchedulerRunning ? Icons.timer : Icons.timer_off,
                          color: _isSchedulerRunning ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSchedulerRunning ? 'Running' : 'Stopped',
                          style: TextStyle(
                            color: _isSchedulerRunning ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _toggleScheduler,
                          icon: Icon(_isSchedulerRunning ? Icons.stop : Icons.play_arrow),
                          label: Text(_isSchedulerRunning ? 'Stop Scheduler' : 'Start Scheduler'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSchedulerRunning ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _forceCheck,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Force Check Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Scheduled Feedings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _recentFeedings.length,
                itemBuilder: (context, index) {
                  final feeding = _recentFeedings[index];
                  final feedingTime = DateTime.parse(feeding['feeding_time']);
                  final petName = feeding['pets']['name'] as String;
                  final amount = (feeding['amount'] as num).toDouble();
                  final scheduleId = feeding['schedule_id'] as String?;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.pets),
                      title: Text(petName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount: ${amount.toStringAsFixed(1)}g'),
                          Text('Time: ${feedingTime.toString()}'),
                          if (scheduleId != null)
                            Text('Schedule ID: $scheduleId', style: const TextStyle(fontSize: 12)),
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
    );
  }
} 