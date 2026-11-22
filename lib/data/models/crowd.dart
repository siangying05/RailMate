import 'dart:ui';

import '../../core/theme/app_colors.dart';

enum CrowdLevel { low, moderate, high }

extension CrowdLevelDisplay on CrowdLevel {
  String get label {
    switch (this) {
      case CrowdLevel.low:
        return 'Low';
      case CrowdLevel.moderate:
        return 'Moderate';
      case CrowdLevel.high:
        return 'High';
    }
  }

  String get advice {
    switch (this) {
      case CrowdLevel.low:
        return 'Seats are usually available.';
      case CrowdLevel.moderate:
        return 'Some standing room expected.';
      case CrowdLevel.high:
        return 'Very busy. Consider travelling outside this window.';
    }
  }

  Color get colour {
    switch (this) {
      case CrowdLevel.low:
        return AppColors.crowdLow;
      case CrowdLevel.moderate:
        return AppColors.crowdModerate;
      case CrowdLevel.high:
        return AppColors.crowdHigh;
    }
  }

  int get rank => index;
}

class CrowdForecast {
  final double score;
  final CrowdLevel level;
  final int averageDailyRiders;

  const CrowdForecast({
    required this.score,
    required this.level,
    required this.averageDailyRiders,
  });

  factory CrowdForecast.fromScore(
    double score, {
    required int averageDailyRiders,
  }) {
    final clamped = score.clamp(0.0, 1.0);
    return CrowdForecast(
      score: clamped,
      level: _levelFor(clamped),
      averageDailyRiders: averageDailyRiders,
    );
  }

  static CrowdLevel _levelFor(double score) {
    if (score < 0.42) return CrowdLevel.low;
    if (score < 0.70) return CrowdLevel.moderate;
    return CrowdLevel.high;
  }

  int get percent => (score * 100).round();
}

class CarriageLoad {
  final int carriage;
  final CrowdLevel level;
  final bool recommended;
  final String reason;

  const CarriageLoad({
    required this.carriage,
    required this.level,
    required this.recommended,
    required this.reason,
  });
}

class TravelWindow {
  final int startMinutes;
  final int endMinutes;
  final CrowdForecast forecast;

  const TravelWindow({
    required this.startMinutes,
    required this.endMinutes,
    required this.forecast,
  });

  String get startLabel => _format(startMinutes);

  String get label => '${_format(startMinutes)} - ${_format(endMinutes)}';

  static String _format(int minutes) {
    final normalised = minutes % (24 * 60);
    final hour = normalised ~/ 60;
    final minute = normalised % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    var display = hour % 12;
    if (display == 0) display = 12;
    return '$display:${minute.toString().padLeft(2, '0')} $suffix';
  }
}
