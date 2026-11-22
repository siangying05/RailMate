import '../../../data/models/crowd.dart';
import '../../../data/models/guidance.dart';
import '../../../data/models/interchange.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_network.dart';
import '../../../data/services/crowd_estimator.dart';
import '../../../data/services/platform_directory.dart';

class JourneyGuidance {
  final List<TransferGuidance> transfers;
  final Map<int, PlatformInfo> boardingPlatforms;
  final Map<int, CarriageAdvice> carriageAdvice;
  final List<ArrivalAlert> alerts;

  const JourneyGuidance({
    required this.transfers,
    required this.boardingPlatforms,
    required this.carriageAdvice,
    required this.alerts,
  });

  bool get isEmpty => boardingPlatforms.isEmpty;
}

class GuidanceBuilder {
  final RailNetwork network;
  final PlatformDirectory platforms;
  final CrowdEstimator crowdEstimator;

  const GuidanceBuilder({
    required this.network,
    required this.platforms,
    required this.crowdEstimator,
  });

  JourneyGuidance build(JourneyOption option) {
    final transfers = <TransferGuidance>[];
    final boarding = <int, PlatformInfo>{};
    final carriages = <int, CarriageAdvice>{};
    final alerts = <ArrivalAlert>[];

    final rides = <int>[];
    for (var i = 0; i < option.legs.length; i++) {
      if (option.legs[i].kind == LegKind.ride) rides.add(i);
    }

    for (var order = 0; order < rides.length; order++) {
      final index = rides[order];
      final leg = option.legs[index];
      final line = network.line(leg.lineId);
      if (line == null) continue;

      boarding[index] = platforms.platformFor(
        stationId: leg.fromStationId,
        lineId: leg.lineId,
        towardsStationId: leg.towardsStationId,
      );

      final isLast = order == rides.length - 1;
      final nextLine = isLast ? null : option.legs[rides[order + 1]].lineId;

      carriages[index] = _carriageAdvice(
        option: option,
        legIndex: index,
        lineId: leg.lineId,
        nextLineId: nextLine,
        departAt: option.departAt,
      );

      alerts.add(
        ArrivalAlert(
          stationId: leg.toStationId,
          stationName: network.stationName(leg.toStationId),
          stopsAway: 1,
          action: isLast
              ? 'Get ready to leave the train at your destination.'
              : 'Get ready to change trains here.',
        ),
      );
    }

    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      if (leg.kind == LegKind.ride) continue;
      if (leg.kind == LegKind.transfer && leg.note.startsWith('Wait')) continue;

      final previousRide = _previousRide(option.legs, i);
      final nextRide = _nextRide(option.legs, i);
      if (previousRide == null || nextRide == null) continue;

      transfers.add(
        _transferGuidance(
          option: option,
          leg: leg,
          fromLeg: previousRide,
          toLeg: nextRide,
        ),
      );
    }

    return JourneyGuidance(
      transfers: transfers,
      boardingPlatforms: boarding,
      carriageAdvice: carriages,
      alerts: alerts,
    );
  }

  TransferGuidance _transferGuidance({
    required JourneyOption option,
    required JourneyLeg leg,
    required JourneyLeg fromLeg,
    required JourneyLeg toLeg,
  }) {
    final stationId = leg.kind == LegKind.walk
        ? leg.fromStationId
        : leg.fromStationId;

    final arrive = platforms.platformFor(
      stationId: fromLeg.toStationId,
      lineId: fromLeg.lineId,
      towardsStationId: fromLeg.towardsStationId,
    );
    final depart = platforms.platformFor(
      stationId: toLeg.fromStationId,
      lineId: toLeg.lineId,
      towardsStationId: toLeg.towardsStationId,
    );

    final curated = platforms.transferFor(
      stationId: stationId,
      fromLineId: fromLeg.lineId,
      toLineId: toLeg.lineId,
    );

    final type = leg.interchangeType ?? InterchangeType.paid;
    final fromLine = network.line(fromLeg.lineId);
    final toLine = network.line(toLeg.lineId);

    final instruction = curated?.note.isNotEmpty == true
        ? curated!.note
        : _defaultInstruction(
            type: type,
            fromStation: network.stationName(fromLeg.toStationId),
            toStation: network.stationName(toLeg.fromStationId),
            toLineName: toLine?.name ?? 'the next line',
            platform: depart.platform,
          );

    return TransferGuidance(
      stationId: stationId,
      fromLineId: fromLine?.id ?? '',
      toLineId: toLine?.id ?? '',
      type: type,
      arrivePlatform: arrive,
      departPlatform: depart,
      walkSeconds: curated?.walkSeconds ?? leg.seconds,
      metres: (leg.km * 1000).round(),
      instruction: instruction,
      stepFree: curated?.stepFree ?? true,
    );
  }

  String _defaultInstruction({
    required InterchangeType type,
    required String fromStation,
    required String toStation,
    required String toLineName,
    required String platform,
  }) {
    if (type == InterchangeType.paid) {
      return 'Stay inside the paid area at $fromStation and follow the signs '
          'for $toLineName, platform $platform.';
    }
    return 'Tap out at $fromStation, walk across to $toStation, then tap in '
        'again for $toLineName, platform $platform.';
  }

  CarriageAdvice _carriageAdvice({
    required JourneyOption option,
    required int legIndex,
    required String lineId,
    required String? nextLineId,
    required DateTime departAt,
  }) {
    final line = network.line(lineId);
    if (line == null) {
      return const CarriageAdvice(
        totalCarriages: 4,
        recommended: [],
        reason: 'Board any carriage.',
        confidence: AdviceConfidence.derived,
        loads: [],
      );
    }

    final leg = option.legs[legIndex];

    if (nextLineId != null) {
      final curated = platforms.transferFor(
        stationId: leg.toStationId,
        fromLineId: lineId,
        toLineId: nextLineId,
      );
      if (curated != null && curated.carriages.isNotEmpty) {
        return CarriageAdvice(
          totalCarriages: line.carriages,
          recommended: curated.carriages,
          reason: curated.note.isNotEmpty
              ? curated.note
              : 'Closest to the connection at '
                  '${network.stationName(leg.toStationId)}.',
          confidence: AdviceConfidence.verified,
          loads: crowdEstimator.carriageLoads(
            line,
            departAt,
            recommended: curated.carriages,
          ),
        );
      }
    }

    final quiet = crowdEstimator.quietestCarriages(line, departAt);
    return CarriageAdvice(
      totalCarriages: line.carriages,
      recommended: quiet,
      reason: nextLineId != null
          ? 'Station layout is not verified, so these are simply the quieter '
              'carriages at this time of day.'
          : 'These carriages are usually the quietest at this time of day.',
      confidence: AdviceConfidence.derived,
      loads: crowdEstimator.carriageLoads(
        line,
        departAt,
        recommended: quiet,
      ),
    );
  }

  JourneyLeg? _previousRide(List<JourneyLeg> legs, int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (legs[i].kind == LegKind.ride) return legs[i];
    }
    return null;
  }

  JourneyLeg? _nextRide(List<JourneyLeg> legs, int index) {
    for (var i = index + 1; i < legs.length; i++) {
      if (legs[i].kind == LegKind.ride) return legs[i];
    }
    return null;
  }

  List<CarriageLoad> loadsFor(String lineId, DateTime when) {
    final line = network.line(lineId);
    if (line == null) return const [];
    return crowdEstimator.carriageLoads(line, when);
  }
}
