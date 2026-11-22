class StationExit {
  final String code;
  final String name;
  final int walkMinutes;
  final bool stepFree;
  final List<String> landmarks;

  const StationExit({
    required this.code,
    required this.name,
    required this.walkMinutes,
    required this.stepFree,
    required this.landmarks,
  });

  factory StationExit.fromJson(Map<String, dynamic> json) {
    return StationExit(
      code: json['code'] as String,
      name: json['name'] as String,
      walkMinutes: json['walkMinutes'] as int? ?? 5,
      stepFree: json['stepFree'] as bool? ?? true,
      landmarks: (json['landmarks'] as List?)?.cast<String>() ?? const [],
    );
  }

  String get label => 'Exit $code';
}

class ExitSuggestion {
  final StationExit exit;
  final String matchedLandmark;
  final double score;

  const ExitSuggestion({
    required this.exit,
    required this.matchedLandmark,
    required this.score,
  });

  bool get isConfident => score >= 0.5;
}
