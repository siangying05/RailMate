/// Mirrors the fields RailMate reads out of a GTFS-Realtime FeedMessage ->
/// FeedEntity -> VehiclePosition (see
/// `data/services/gtfs_realtime_parser.dart` for the wire-format decoder).
///
/// Verified against a real sample pulled from
/// https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb :
///   trip_id "2964", lat 6.404168, lon 100.278030, speed 114.0 km/h,
///   vehicle {id: "2964", label: "SCS27"}.
class VehiclePosition {
  final String tripId;
  final String? vehicleId;
  final String? vehicleLabel;
  final double latitude;
  final double longitude;
  final double bearing;
  final double speedKmh;
  final DateTime timestamp;

  VehiclePosition({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.bearing,
    required this.speedKmh,
    required this.timestamp,
    this.vehicleId,
    this.vehicleLabel,
  });

  /// data.gov.my occasionally returns an entity with no position fix yet
  /// (a vehicle that hasn't reported), which decodes to (0, 0) - off the
  /// coast of West Africa, nowhere near a Malaysian rail line. Callers
  /// should skip these rather than plotting a marker there.
  bool get hasFix => latitude != 0 || longitude != 0;

  @override
  String toString() =>
      'VehiclePosition(trip=$tripId, veh=$vehicleLabel, '
      '($latitude,$longitude), ${speedKmh}km/h @ $timestamp)';
}
