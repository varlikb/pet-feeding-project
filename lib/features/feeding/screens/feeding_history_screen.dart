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

  FeedingRecord({
    required this.id,
    required this.petId,
    required this.amount,
    required this.feedingTime,
    required this.feedingType,
    this.deviceId,
  });

  factory FeedingRecord.fromJson(Map<String, dynamic> json) {
    return FeedingRecord(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      feedingTime: DateTime.parse(json['feeding_time'] as String),
      feedingType: json['feeding_type'] as String,
      deviceId: json['device_id'] as String?,
    );
  }
}

class FeedingHistoryScreen extends StatefulWidget {
  final String petId;

  const FeedingHistoryScreen({
    Key? key,
    required this.petId,
  }) : super(key: key);

  @override
  State<FeedingHistoryScreen> createState() => _FeedingHistoryScreenState();
}

class _FeedingHistoryScreenState extends State<FeedingHistoryScreen> {
  bool _isLoading = false;
  List<FeedingRecord> _feedingRecords = [];
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _loadFeedingHistory();
  }

  Future<void> _loadFeedingHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await SupabaseService.fetchFeedingRecords(widget.petId);
      setState(() {
        _feedingRecords = records.map((record) => FeedingRecord.fromJson(record)).toList();
      });
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadFeedingHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedingRecords.isEmpty
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
                  itemCount: _feedingRecords.length,
                  itemBuilder: (context, index) {
                    final record = _feedingRecords[index];
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
                          '${record.amount.toInt()} grams',
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
                            if (record.deviceId != null)
                              Text(
                                'Device ID: ${record.deviceId}',
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