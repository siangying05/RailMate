import 'package:flutter/material.dart';

class TimeUtils {
  const TimeUtils._();

  static const int morningPeakStart = 7 * 60;
  static const int morningPeakEnd = 9 * 60 + 30;
  static const int eveningPeakStart = 17 * 60;
  static const int eveningPeakEnd = 19 * 60 + 30;
  static const int serviceStart = 6 * 60;
  static const int serviceEnd = 23 * 60 + 30;

  static int minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  static TimeOfDay toTimeOfDay(int minutes) {
    final normalised = minutes % (24 * 60);
    return TimeOfDay(hour: normalised ~/ 60, minute: normalised % 60);
  }

  static bool isPeak(int minutes) {
    final normalised = minutes % (24 * 60);
    return (normalised >= morningPeakStart && normalised <= morningPeakEnd) ||
        (normalised >= eveningPeakStart && normalised <= eveningPeakEnd);
  }

  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  static bool withinServiceHours(int minutes) {
    final normalised = minutes % (24 * 60);
    return normalised >= serviceStart && normalised <= serviceEnd;
  }

  static String formatMinutes(int minutes) {
    final normalised = minutes % (24 * 60);
    final hour = normalised ~/ 60;
    final minute = normalised % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    var display = hour % 12;
    if (display == 0) display = 12;
    return '$display:${minute.toString().padLeft(2, '0')} $suffix';
  }

  static String formatClock(DateTime time) =>
      formatMinutes(time.hour * 60 + time.minute);

  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) return '$hours h';
    return '$hours h $remainder min';
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatDateTime(DateTime value) =>
      '${formatDate(value)}  ${formatClock(value)}';

  static String relativeDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = target.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference < 0 && difference > -7) return '${-difference} days ago';
    return formatDate(date);
  }

  static String peakLabel(int minutes) {
    if (!withinServiceHours(minutes)) return 'Outside service hours';
    return isPeak(minutes) ? 'Peak period' : 'Off-peak period';
  }

  static String weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }
}
