import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationStatus { unknown, denied, deniedForever, disabled, ready }

class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracyMetres;
  final DateTime at;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMetres,
    required this.at,
  });
}

class LocationService {
  Future<LocationStatus> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationStatus.disabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        return LocationStatus.denied;
      case LocationPermission.deniedForever:
        return LocationStatus.deniedForever;
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationStatus.ready;
      case LocationPermission.unableToDetermine:
        return LocationStatus.unknown;
    }
  }

  Future<LocationFix?> currentFix() async {
    final status = await ensurePermission();
    if (status != LocationStatus.ready) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMetres: position.accuracy,
        at: DateTime.now(),
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Stream<LocationFix> watch({int distanceFilterMetres = 60}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMetres,
      ),
    ).map(
      (position) => LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMetres: position.accuracy,
        at: DateTime.now(),
      ),
    );
  }

  Future<void> openSettings() => Geolocator.openLocationSettings();
}
