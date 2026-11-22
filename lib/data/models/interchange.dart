enum InterchangeType { paid, walk }

extension InterchangeTypeDisplay on InterchangeType {
  String get label {
    switch (this) {
      case InterchangeType.paid:
        return 'Paid area interchange';
      case InterchangeType.walk:
        return 'Connecting station';
    }
  }

  String get shortLabel {
    switch (this) {
      case InterchangeType.paid:
        return 'Inside gates';
      case InterchangeType.walk:
        return 'Exit and walk';
    }
  }

  String get advice {
    switch (this) {
      case InterchangeType.paid:
        return 'Stay inside the paid area. Do not tap out.';
      case InterchangeType.walk:
        return 'Tap out, walk to the connecting station, then tap in again.';
    }
  }
}

class Interchange {
  final String fromStationId;
  final String toStationId;
  final InterchangeType type;
  final int metres;
  final int walkMinutes;
  final bool sameName;

  const Interchange({
    required this.fromStationId,
    required this.toStationId,
    required this.type,
    required this.metres,
    required this.walkMinutes,
    required this.sameName,
  });

  factory Interchange.fromJson(Map<String, dynamic> json) {
    return Interchange(
      fromStationId: json['from'] as String,
      toStationId: json['to'] as String,
      type: json['type'] == 'paid' ? InterchangeType.paid : InterchangeType.walk,
      metres: json['metres'] as int? ?? 0,
      walkMinutes: json['walkMinutes'] as int? ?? 3,
      sameName: json['sameName'] as bool? ?? false,
    );
  }

  bool get requiresExit => type == InterchangeType.walk;

  Interchange reversed() {
    return Interchange(
      fromStationId: toStationId,
      toStationId: fromStationId,
      type: type,
      metres: metres,
      walkMinutes: walkMinutes,
      sameName: sameName,
    );
  }
}
