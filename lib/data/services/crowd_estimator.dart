import 'dart:math' as math;

import '../../core/utils/time_utils.dart';
import '../models/crowd.dart';
import '../models/journey.dart';
import '../models/rail_line.dart';
import '../models/rail_network.dart';
import '../models/ridership.dart';
import '../models/station.dart';

class CrowdEstimator {
  static const List<List<double>> demandCurve = [
    [0, 0.10],
    [5 * 60, 0.14],
    [6 * 60, 0.34],
    [7 * 60, 0.86],
    [8 * 60, 1.00],
    [9 * 60, 0.80],
    [10 * 60, 0.50],
    [11 * 60, 0.44],
    [12 * 60, 0.54],
    [13 * 60, 0.56],
    [14 * 60, 0.44],
    [15 * 60, 0.46],
    [16 * 60, 0.60],
    [17 * 60, 0.86],
    [18 * 60, 1.00],
    [19 * 60, 0.78],
    [20 * 60, 0.52],
    [21 * 60, 0.40],
    [22 * 60, 0.28],
    [23 * 60, 0.18],
    [24 * 60, 0.10],
  ];

  static const double peakMultiplier = 1.72;
  static const double interchangeUplift = 0.07;

  final RailNetwork network;
  final RidershipDataset dataset;
  final bool live;

  const CrowdEstimator({
    required this.network,
    required this.dataset,
    required this.live,
  });

  double timeFactor(int minutesOfDay) {
    final normalised = (minutesOfDay % (24 * 60)).toDouble();
    for (var i = 0; i < demandCurve.length - 1; i++) {
      final start = demandCurve[i];
      final end = demandCurve[i + 1];
      if (normalised >= start[0] && normalised <= end[0]) {
        final span = end[0] - start[0];
        if (span == 0) return start[1];
        final progress = (normalised - start[0]) / span;
        return start[1] + (end[1] - start[1]) * progress;
      }
    }
    return demandCurve.last[1];
  }

  double dayFactor(RailLine line, DateTime when) {
    if (dataset.isEmpty) {
      return TimeUtils.isWeekend(when) ? 0.62 : 1.08;
    }
    return dataset
        .weekdayFactorFor(line.ridershipKey, when.weekday)
        .clamp(0.35, 1.45);
  }

  double baseLoad(RailLine line) {
    final average = dataset.averageFor(line.ridershipKey) * line.ridershipShare;
    if (average <= 0 || line.dailyCapacity <= 0) return 0.42;
    return (average / line.dailyCapacity).clamp(0.05, 0.95);
  }

  CrowdForecast forLine(RailLine line, DateTime when) {
    final minutes = when.hour * 60 + when.minute;
    final score = baseLoad(line) *
        timeFactor(minutes) *
        peakMultiplier *
        dayFactor(line, when);

    return CrowdForecast.fromScore(
      score,
      averageDailyRiders: (dataset.averageFor(line.ridershipKey) * line.ridershipShare).round(),
    );
  }

  CrowdForecast forStation(Station station, DateTime when) {
    final lines = network.linesFor(station.id);
    if (lines.isEmpty) {
      return CrowdForecast.fromScore(0.3, averageDailyRiders: 0);
    }

    var worst = 0.0;
    var riders = 0;
    for (final line in lines) {
      final forecast = forLine(line, when);
      worst = math.max(worst, forecast.score);
      riders += forecast.averageDailyRiders;
    }

    final connections = network.linksFrom(station.id).length;
    final uplift = interchangeUplift * (lines.length - 1 + connections * 0.5);

    return CrowdForecast.fromScore(
      worst + uplift,
      averageDailyRiders: riders,
    );
  }

  CrowdForecast forLegs(List<JourneyLeg> legs, DateTime departAt) {
    final rides = legs.where((leg) => leg.kind == LegKind.ride).toList();
    if (rides.isEmpty) {
      return CrowdForecast.fromScore(0.3, averageDailyRiders: 0);
    }

    var weighted = 0.0;
    var totalSeconds = 0;
    var riders = 0;
    var elapsed = 0;

    for (final leg in legs) {
      if (leg.kind != LegKind.ride) {
        elapsed += leg.seconds;
        continue;
      }
      final line = network.line(leg.lineId);
      if (line == null) continue;

      final at = departAt.add(Duration(seconds: elapsed));
      final forecast = forLine(line, at);
      weighted += forecast.score * leg.seconds;
      totalSeconds += leg.seconds;
      riders = math.max(riders, forecast.averageDailyRiders);
      elapsed += leg.seconds;
    }

    if (totalSeconds == 0) {
      return CrowdForecast.fromScore(0.3, averageDailyRiders: riders);
    }

    return CrowdForecast.fromScore(
      weighted / totalSeconds,
      averageDailyRiders: riders,
    );
  }

  List<CarriageLoad> carriageLoads(
    RailLine line,
    DateTime when, {
    List<int> recommended = const [],
  }) {
    final base = forLine(line, when);
    final total = line.carriages;
    final loads = <CarriageLoad>[];

    for (var carriage = 1; carriage <= total; carriage++) {
      final distanceFromEnds =
          math.min(carriage - 1, total - carriage).toDouble();
      final centreBias = total <= 1 ? 0.0 : distanceFromEnds / (total / 2);
      final score = (base.score * (0.82 + 0.30 * centreBias)).clamp(0.0, 1.0);
      final forecast = CrowdForecast.fromScore(
        score,
        averageDailyRiders: base.averageDailyRiders,
      );

      loads.add(
        CarriageLoad(
          carriage: carriage,
          level: forecast.level,
          recommended: recommended.contains(carriage),
          reason: recommended.contains(carriage)
              ? 'Closest to your next connection'
              : (centreBias > 0.7
                  ? 'Middle carriages fill up first'
                  : 'End carriages are usually quieter'),
        ),
      );
    }

    return loads;
  }

  List<int> quietestCarriages(RailLine line, DateTime when) {
    final loads = carriageLoads(line, when);
    if (loads.isEmpty) return const [];
    final sorted = [...loads]
      ..sort((a, b) => a.level.rank.compareTo(b.level.rank));
    final best = sorted.take(2).map((load) => load.carriage).toList()..sort();
    return best;
  }

  List<TravelWindow> dailyProfile(
    List<String> lineIds,
    DateTime day, {
    int stepMinutes = 30,
    int startMinutes = TimeUtils.serviceStart,
    int endMinutes = TimeUtils.serviceEnd,
  }) {
    final lines = lineIds.map(network.line).whereType<RailLine>().toList();
    if (lines.isEmpty) return const [];

    final windows = <TravelWindow>[];
    for (var minute = startMinutes; minute < endMinutes; minute += stepMinutes) {
      final at =
          DateTime(day.year, day.month, day.day).add(Duration(minutes: minute));

      var worst = 0.0;
      var riders = 0;
      for (final line in lines) {
        final forecast = forLine(line, at);
        worst = math.max(worst, forecast.score);
        riders = math.max(riders, forecast.averageDailyRiders);
      }

      windows.add(
        TravelWindow(
          startMinutes: minute,
          endMinutes: minute + stepMinutes,
          forecast: CrowdForecast.fromScore(worst, averageDailyRiders: riders),
        ),
      );
    }

    return windows;
  }

  List<TravelWindow> quieterAlternatives(
    List<String> lineIds,
    DateTime departAt, {
    int maxShiftMinutes = 180,
    int results = 3,
  }) {
    final profile = dailyProfile(lineIds, departAt);
    if (profile.isEmpty) return const [];

    final departMinutes = departAt.hour * 60 + departAt.minute;
    final current = scoreAt(lineIds, departAt);

    final candidates = profile.where((window) {
      final shift = (window.startMinutes - departMinutes).abs();
      return shift > 0 &&
          shift <= maxShiftMinutes &&
          window.forecast.score < current - 0.08;
    }).toList();

    candidates.sort((a, b) {
      final byScore = a.forecast.score.compareTo(b.forecast.score);
      if (byScore != 0) return byScore;
      return (a.startMinutes - departMinutes)
          .abs()
          .compareTo((b.startMinutes - departMinutes).abs());
    });

    return candidates.take(results).toList();
  }

  double scoreAt(List<String> lineIds, DateTime at) {
    final lines = lineIds.map(network.line).whereType<RailLine>().toList();
    if (lines.isEmpty) return 0.3;
    var worst = 0.0;
    for (final line in lines) {
      worst = math.max(worst, forLine(line, at).score);
    }
    return worst;
  }

  String dataNarrative() {
    final latest = dataset.latestDate;
    if (latest == null) return 'No ridership data available.';
    return 'Predicted from ${dataset.dayCount} days of national rail ridership '
        'published on data.gov.my, up to ${TimeUtils.formatDate(latest)}.';
  }
}
