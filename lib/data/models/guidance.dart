import 'crowd.dart';
import 'interchange.dart';

enum PlatformLevel { concourse, upper, lower, ground }

extension PlatformLevelDisplay on PlatformLevel {
  String get label {
    switch (this) {
      case PlatformLevel.concourse:
        return 'Concourse level';
      case PlatformLevel.upper:
        return 'Upper platform';
      case PlatformLevel.lower:
        return 'Lower platform';
      case PlatformLevel.ground:
        return 'Ground level';
    }
  }
}

class PlatformInfo {
  final String stationId;
  final String lineId;
  final String platform;
  final String towardsStationId;
  final PlatformLevel level;
  final bool verified;

  const PlatformInfo({
    required this.stationId,
    required this.lineId,
    required this.platform,
    required this.towardsStationId,
    required this.level,
    required this.verified,
  });

  String get label => 'Platform $platform';
}

enum AdviceConfidence { verified, derived }

extension AdviceConfidenceDisplay on AdviceConfidence {
  String get label {
    switch (this) {
      case AdviceConfidence.verified:
        return 'Verified layout';
      case AdviceConfidence.derived:
        return 'General guidance';
    }
  }
}

class CarriageAdvice {
  final int totalCarriages;
  final List<int> recommended;
  final String reason;
  final AdviceConfidence confidence;
  final List<CarriageLoad> loads;

  const CarriageAdvice({
    required this.totalCarriages,
    required this.recommended,
    required this.reason,
    required this.confidence,
    required this.loads,
  });

  String get label {
    if (recommended.isEmpty) return 'Any carriage';
    if (recommended.length == 1) return 'Carriage ${recommended.first}';
    return 'Carriages ${recommended.first} to ${recommended.last}';
  }
}

class TransferGuidance {
  final String stationId;
  final String fromLineId;
  final String toLineId;
  final InterchangeType type;
  final PlatformInfo? arrivePlatform;
  final PlatformInfo? departPlatform;
  final int walkSeconds;
  final int metres;
  final String instruction;
  final bool stepFree;

  const TransferGuidance({
    required this.stationId,
    required this.fromLineId,
    required this.toLineId,
    required this.type,
    required this.arrivePlatform,
    required this.departPlatform,
    required this.walkSeconds,
    required this.metres,
    required this.instruction,
    required this.stepFree,
  });

  int get walkMinutes => (walkSeconds / 60).ceil();

  bool get requiresExit => type == InterchangeType.walk;
}

class ArrivalAlert {
  final String stationId;
  final String stationName;
  final String action;
  final int stopsAway;

  const ArrivalAlert({
    required this.stationId,
    required this.stationName,
    required this.action,
    required this.stopsAway,
  });

  String get title => stopsAway <= 1
      ? 'Next stop: $stationName'
      : '$stopsAway stops to $stationName';

  String get body => action;
}
