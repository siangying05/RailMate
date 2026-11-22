import 'dart:async';

import '../../../core/providers/safe_notifier.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_network.dart';
import '../services/guidance_builder.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class GuidanceProvider extends SafeNotifier {
  static const double arrivalRadiusMetres = 900;

  final LocationService _location;
  final NotificationService _notifications;

  GuidanceProvider({
    LocationService? location,
    NotificationService? notifications,
  })  : _location = location ?? LocationService(),
        _notifications = notifications ?? NotificationService.instance;

  JourneyGuidance? _guidance;
  JourneyOption? _option;
  LocationStatus _locationStatus = LocationStatus.unknown;
  LocationFix? _fix;
  NearbyStation? _nearest;
  bool _tracking = false;
  bool _locating = false;
  final Set<String> _alertedStationIds = {};
  String? _notice;
  StreamSubscription<LocationFix>? _subscription;

  JourneyGuidance? get guidance => _guidance;
  JourneyOption? get option => _option;
  LocationStatus get locationStatus => _locationStatus;
  LocationFix? get fix => _fix;
  NearbyStation? get nearest => _nearest;
  bool get tracking => _tracking;
  bool get locating => _locating;
  String? get notice => _notice;

  bool get hasLocation => _fix != null;

  void attach(JourneyOption option, GuidanceBuilder builder) {
    _option = option;
    _guidance = builder.build(option);
    _alertedStationIds.clear();
    notifyListeners();
  }

  void clear() {
    stopTracking();
    _option = null;
    _guidance = null;
    _alertedStationIds.clear();
    notifyListeners();
  }

  Future<NearbyStation?> locateNearest(RailNetwork network) async {
    _locating = true;
    _notice = null;
    notifyListeners();

    _locationStatus = await _location.ensurePermission();
    if (_locationStatus != LocationStatus.ready) {
      _locating = false;
      _notice = _statusMessage(_locationStatus);
      notifyListeners();
      return null;
    }

    final fix = await _location.currentFix();
    if (fix == null) {
      _locating = false;
      _notice = 'Could not get a location fix. Try again in an open area.';
      notifyListeners();
      return null;
    }

    _fix = fix;
    final nearby = network.nearest(fix.latitude, fix.longitude, limit: 1);
    _nearest = nearby.isEmpty ? null : nearby.first;

    if (_nearest == null) {
      _notice = 'No rail station found within 5 km of your location.';
    }

    _locating = false;
    notifyListeners();
    return _nearest;
  }

  Future<List<NearbyStation>> nearbyStations(
    RailNetwork network, {
    int limit = 5,
  }) async {
    final fix = _fix ?? await _location.currentFix();
    if (fix == null) return const [];
    _fix = fix;
    notifyListeners();
    return network.nearest(fix.latitude, fix.longitude, limit: limit);
  }

  Future<bool> startTracking(RailNetwork network) async {
    if (_option == null) return false;

    _locationStatus = await _location.ensurePermission();
    if (_locationStatus != LocationStatus.ready) {
      _notice = _statusMessage(_locationStatus);
      notifyListeners();
      return false;
    }

    await _notifications.requestPermission();

    _subscription?.cancel();
    _subscription = _location.watch().listen((fix) {
      _fix = fix;
      _evaluate(network, fix);
      notifyListeners();
    });

    _tracking = true;
    _notice = 'Arrival alerts are on. Keep RailMate open during your trip.';
    notifyListeners();
    return true;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _tracking = false;
    notifyListeners();
  }

  void _evaluate(RailNetwork network, LocationFix fix) {
    final guidance = _guidance;
    final option = _option;
    if (guidance == null || option == null) return;

    for (final alert in guidance.alerts) {
      final station = network.station(alert.stationId);
      if (station == null) continue;

      final metres = GeoUtils.distanceMetres(
        fix.latitude,
        fix.longitude,
        station.lat,
        station.lon,
      );

      if (metres <= arrivalRadiusMetres &&
          !_alertedStationIds.contains(alert.stationId)) {
        _alertedStationIds.add(alert.stationId);
        _notifications.showArrivalAlert(
          id: alert.stationId.hashCode & 0x7fffffff,
          title: alert.title,
          body: alert.body,
        );
        _notice = '${alert.title} - ${alert.body}';
        return;
      }
    }
  }

  String _statusMessage(LocationStatus status) {
    switch (status) {
      case LocationStatus.disabled:
        return 'Location services are switched off on this device.';
      case LocationStatus.denied:
        return 'RailMate needs location access to find your nearest station.';
      case LocationStatus.deniedForever:
        return 'Location access is blocked. Enable it in system settings.';
      case LocationStatus.unknown:
        return 'Location permission could not be determined.';
      case LocationStatus.ready:
        return '';
    }
  }

  Future<void> openLocationSettings() => _location.openSettings();

  void clearNotice() {
    _notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
