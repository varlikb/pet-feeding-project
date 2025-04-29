import 'package:flutter/material.dart';

class FeedingSchedule {
  final DateTime startDate;
  final DateTime endDate;
  final String frequency; // 'hour' or 'day'
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double amount;

  FeedingSchedule({
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required this.startTime,
    required this.endTime,
    required this.amount,
  });
}

class DeviceProvider extends ChangeNotifier {
  List<FeedingSchedule> _schedules = [];
  double _foodLevel = 100.0; // percentage
  DateTime? _lastFeeding;
  bool _isFeeding = false;

  List<FeedingSchedule> get schedules => List.unmodifiable(_schedules);
  double get foodLevel => _foodLevel;
  DateTime? get lastFeeding => _lastFeeding;
  bool get isFeeding => _isFeeding;

  Future<void> addSchedule(FeedingSchedule schedule) async {
    _schedules.add(schedule);
    notifyListeners();
  }

  Future<void> removeSchedule(FeedingSchedule schedule) async {
    _schedules.remove(schedule);
    notifyListeners();
  }

  Future<void> updateFoodLevel(double newLevel) async {
    _foodLevel = newLevel;
    notifyListeners();
  }

  Future<void> recordFeeding(double amount) async {
    _lastFeeding = DateTime.now();
    _foodLevel = (_foodLevel - (amount / 1000.0) * 100).clamp(0.0, 100.0);
    notifyListeners();
  }

  void setFeeding(bool isFeeding) {
    _isFeeding = isFeeding;
    notifyListeners();
  }

  bool shouldSendLowFoodNotification() {
    return _foodLevel < 20.0;
  }

  List<DateTime> getNextFeedingTimes() {
    final now = DateTime.now();
    final nextTimes = <DateTime>[];

    for (final schedule in _schedules) {
      if (schedule.endDate.isBefore(now)) continue;

      final startDateTime = DateTime(
        schedule.startDate.year,
        schedule.startDate.month,
        schedule.startDate.day,
        schedule.startTime.hour,
        schedule.startTime.minute,
      );

      if (startDateTime.isAfter(now)) {
        nextTimes.add(startDateTime);
      } else {
        // Calculate next feeding time based on frequency
        var nextTime = startDateTime;
        while (nextTime.isBefore(now)) {
          if (schedule.frequency == 'hour') {
            nextTime = nextTime.add(const Duration(hours: 1));
          } else {
            nextTime = nextTime.add(const Duration(days: 1));
          }
        }
        if (nextTime.isBefore(schedule.endDate)) {
          nextTimes.add(nextTime);
        }
      }
    }

    nextTimes.sort();
    return nextTimes;
  }
} 