import 'crowd.dart';
import 'fare.dart';
import 'interchange.dart';

enum LegKind { ride, transfer, walk }

class JourneyLeg {
  final LegKind kind;
  final String lineId;
  final String fromStationId;
  final String toStationId;
  final List<String> viaStationIds;
  final int seconds;
  final double km;
  final String towardsStationId;
  final int waitSeconds;
  final InterchangeType? interchangeType;
  final String note;
  final CrowdForecast? crowd;

  const JourneyLeg({
    required this.kind,
    required this.lineId,
    required this.fromStationId,
    required this.toStationId,
    required this.viaStationIds,
    required this.seconds,
    required this.km,
    required this.towardsStationId,
    this.waitSeconds = 0,
    this.interchangeType,
    this.note = '',
    this.crowd,
  });

  factory JourneyLeg.ride({
    required String lineId,
    required String fromStationId,
    required String toStationId,
    required List<String> viaStationIds,
    required int seconds,
    required double km,
    required String towardsStationId,
    required int waitSeconds,
  }) {
    return JourneyLeg(
      kind: LegKind.ride,
      lineId: lineId,
      fromStationId: fromStationId,
      toStationId: toStationId,
      viaStationIds: viaStationIds,
      seconds: seconds,
      km: km,
      towardsStationId: towardsStationId,
      waitSeconds: waitSeconds,
    );
  }

  factory JourneyLeg.transfer({
    required String stationId,
    required int seconds,
    required InterchangeType type,
    required String note,
  }) {
    return JourneyLeg(
      kind: LegKind.transfer,
      lineId: '',
      fromStationId: stationId,
      toStationId: stationId,
      viaStationIds: const [],
      seconds: seconds,
      km: 0,
      towardsStationId: '',
      interchangeType: type,
      note: note,
    );
  }

  factory JourneyLeg.walk({
    required String fromStationId,
    required String toStationId,
    required int seconds,
    required double km,
    required String note,
  }) {
    return JourneyLeg(
      kind: LegKind.walk,
      lineId: '',
      fromStationId: fromStationId,
      toStationId: toStationId,
      viaStationIds: const [],
      seconds: seconds,
      km: km,
      towardsStationId: '',
      interchangeType: InterchangeType.walk,
      note: note,
    );
  }

  int get minutes => (seconds / 60).round();

  int get stopCount => viaStationIds.length;

  List<String> get passThroughIds => viaStationIds.length > 1
      ? viaStationIds.sublist(0, viaStationIds.length - 1)
      : const [];

  JourneyLeg withCrowd(CrowdForecast forecast) => JourneyLeg(
        kind: kind,
        lineId: lineId,
        fromStationId: fromStationId,
        toStationId: toStationId,
        viaStationIds: viaStationIds,
        seconds: seconds,
        km: km,
        towardsStationId: towardsStationId,
        waitSeconds: waitSeconds,
        interchangeType: interchangeType,
        note: note,
        crowd: forecast,
      );
}

enum RouteStrategy { fastest, leastTransfers, leastCrowded }

extension RouteStrategyDisplay on RouteStrategy {
  String get label {
    switch (this) {
      case RouteStrategy.fastest:
        return 'Fastest';
      case RouteStrategy.leastTransfers:
        return 'Fewest transfers';
      case RouteStrategy.leastCrowded:
        return 'Least crowded';
    }
  }
}

class JourneyOption {
  final String id;
  final List<JourneyLeg> legs;
  final Set<RouteStrategy> strategies;
  final int totalSeconds;
  final CrowdForecast crowd;
  final FareBreakdown fare;
  final DateTime departAt;

  const JourneyOption({
    required this.id,
    required this.legs,
    required this.strategies,
    required this.totalSeconds,
    required this.crowd,
    required this.fare,
    required this.departAt,
  });

  List<JourneyLeg> get rideLegs =>
      legs.where((leg) => leg.kind == LegKind.ride).toList();

  int get totalMinutes => (totalSeconds / 60).round();

  int get transferCount => rideLegs.isEmpty ? 0 : rideLegs.length - 1;

  int get stationCount =>
      rideLegs.fold<int>(0, (sum, leg) => sum + leg.stopCount);

  double get totalKm => legs.fold<double>(0, (sum, leg) => sum + leg.km);

  List<String> get lineIds => rideLegs.map((leg) => leg.lineId).toList();

  String get originId => legs.isEmpty ? '' : legs.first.fromStationId;

  String get destinationId => legs.isEmpty ? '' : legs.last.toStationId;

  DateTime get arriveAt => departAt.add(Duration(seconds: totalSeconds));

  int get walkMinutes => legs
      .where((leg) => leg.kind == LegKind.walk)
      .fold<int>(0, (sum, leg) => sum + leg.minutes);

  bool get hasExitAndWalk =>
      legs.any((leg) => leg.kind == LegKind.walk);

  bool get isPaidAreaOnly => !hasExitAndWalk;

  String get signature => rideLegs
      .map((leg) => '${leg.lineId}:${leg.fromStationId}>${leg.toStationId}')
      .join('|');

  JourneyOption copyWith({
    List<JourneyLeg>? legs,
    Set<RouteStrategy>? strategies,
    CrowdForecast? crowd,
    FareBreakdown? fare,
    DateTime? departAt,
  }) {
    return JourneyOption(
      id: id,
      legs: legs ?? this.legs,
      strategies: strategies ?? this.strategies,
      totalSeconds: totalSeconds,
      crowd: crowd ?? this.crowd,
      fare: fare ?? this.fare,
      departAt: departAt ?? this.departAt,
    );
  }
}
