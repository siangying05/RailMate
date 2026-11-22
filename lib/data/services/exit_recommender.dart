import '../models/station_exit.dart';

class ExitRecommender {
  final Map<String, List<StationExit>> directory;

  const ExitRecommender({required this.directory});

  List<StationExit> exitsFor(String stationName) {
    return directory[stationName.toLowerCase()] ?? const [];
  }

  bool hasExits(String stationName) => exitsFor(stationName).isNotEmpty;

  ExitSuggestion? recommend(
    String stationName,
    String destinationHint, {
    bool preferStepFree = false,
  }) {
    final exits = exitsFor(stationName);
    if (exits.isEmpty) return null;

    final hint = _normalise(destinationHint);
    if (hint.isEmpty) {
      return ExitSuggestion(
        exit: _shortestWalk(exits, preferStepFree: preferStepFree),
        matchedLandmark: '',
        score: 0,
      );
    }

    final tokens = hint.split(' ').where((token) => token.length > 2).toSet();

    StationExit? best;
    var bestScore = 0.0;
    var bestLandmark = '';

    for (final exit in exits) {
      if (preferStepFree && !exit.stepFree) continue;

      for (final landmark in exit.landmarks) {
        final score = _similarity(hint, tokens, _normalise(landmark));
        if (score > bestScore) {
          bestScore = score;
          best = exit;
          bestLandmark = landmark;
        }
      }

      final nameScore = _similarity(hint, tokens, _normalise(exit.name)) * 0.85;
      if (nameScore > bestScore) {
        bestScore = nameScore;
        best = exit;
        bestLandmark = exit.name;
      }
    }

    if (best == null || bestScore <= 0) {
      return ExitSuggestion(
        exit: _shortestWalk(exits, preferStepFree: preferStepFree),
        matchedLandmark: '',
        score: 0,
      );
    }

    return ExitSuggestion(
      exit: best,
      matchedLandmark: bestLandmark,
      score: bestScore.clamp(0.0, 1.0),
    );
  }

  StationExit _shortestWalk(
    List<StationExit> exits, {
    bool preferStepFree = false,
  }) {
    final pool = preferStepFree
        ? (exits.where((exit) => exit.stepFree).toList()..addAll(
            exits.where((exit) => !exit.stepFree),
          ))
        : exits;
    final sorted = [...pool]
      ..sort((a, b) => a.walkMinutes.compareTo(b.walkMinutes));
    return sorted.first;
  }

  double _similarity(String hint, Set<String> hintTokens, String landmark) {
    if (landmark.isEmpty) return 0;
    if (landmark == hint) return 1.0;
    if (landmark.contains(hint) || hint.contains(landmark)) return 0.9;

    final landmarkTokens =
        landmark.split(' ').where((token) => token.length > 2).toSet();
    if (landmarkTokens.isEmpty || hintTokens.isEmpty) return 0;

    final overlap = landmarkTokens.intersection(hintTokens).length;
    if (overlap == 0) return 0;

    final union = landmarkTokens.union(hintTokens).length;
    return (overlap / union) * 0.8;
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
