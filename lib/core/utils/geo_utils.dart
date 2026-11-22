import 'dart:math' as math;

class GeoUtils {
  const GeoUtils._();

  static const double earthRadiusMetres = 6371000;
  static const double defaultWalkingKmh = 4.5;

  static double distanceMetres(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusMetres * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static int walkMinutes(double metres, {double speedKmh = defaultWalkingKmh}) {
    if (metres <= 0) return 0;
    final metresPerMinute = (speedKmh * 1000) / 60;
    return math.max(1, (metres / metresPerMinute).ceil());
  }

  static String formatDistance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
