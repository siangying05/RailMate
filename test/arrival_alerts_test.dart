import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/data/datasources/local/asset_data_source.dart';
import 'package:railmate/data/models/journey.dart';
import 'package:railmate/data/models/rail_network.dart';
import 'package:railmate/data/models/ridership.dart';
import 'package:railmate/data/models/station.dart';
import 'package:railmate/data/services/crowd_estimator.dart';
import 'package:railmate/data/services/platform_directory.dart';
import 'package:railmate/features/guidance/providers/guidance_provider.dart';
import 'package:railmate/features/guidance/services/guidance_builder.dart';
import 'package:railmate/features/guidance/services/location_service.dart';
import 'package:railmate/features/routing/services/fare_engine.dart';
import 'package:railmate/features/routing/services/route_planner.dart';

class ScriptedLocationService extends LocationService {
  final _controller = StreamController<LocationFix>.broadcast();

  @override
  Future<LocationStatus> ensurePermission() async => LocationStatus.ready;

  @override
  Stream<LocationFix> watch({int distanceFilterMetres = 60}) =>
      _controller.stream;

  Future<void> moveTo(double lat, double lon) async {
    _controller.add(
      LocationFix(
        latitude: lat,
        longitude: lon,
        accuracyMetres: 8,
        at: DateTime.now(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = AssetDataSource();
  late RailNetwork network;
  late GuidanceBuilder builder;
  late RoutePlanner planner;

  String idOf(String name) => network.allStations
      .firstWhere(
        (station) => station.name.toLowerCase() == name.toLowerCase(),
        orElse: () => throw StateError('Station not found: $name'),
      )
      .id;

  Station stationOf(String id) => network.station(id)!;

  setUpAll(() async {
    network = await assets.loadNetwork();
    final records = await assets.loadRidershipSnapshot();
    final estimator = CrowdEstimator(
      network: network,
      dataset: RidershipDataset(records: records, retrievedAt: DateTime.now()),
      live: false,
    );
    final layouts = await assets.loadLayouts();

    planner = RoutePlanner(
      network: network,
      crowdEstimator: estimator,
      fareEngine: FareEngine(network: network),
    );
    builder = GuidanceBuilder(
      network: network,
      platforms: PlatformDirectory(network: network, layouts: layouts),
      crowdEstimator: estimator,
    );
  });

  JourneyOption planGombakToKajang() {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('Gombak'),
        destinationId: idOf('Kajang'),
        departAt: DateTime(2026, 9, 3, 9, 0),
      ),
    );
    return result.best!;
  }

  test('the journey produces an alert for the transfer and the destination',
      () {
    final option = planGombakToKajang();
    final guidance = builder.build(option);

    expect(guidance.alerts, isNotEmpty);
    expect(
      guidance.alerts.last.stationId,
      option.destinationId,
      reason: 'the last alert must be the destination',
    );
    expect(
      guidance.alerts.last.body,
      contains('leave the train'),
    );
  });

  test('arriving near a stop raises that alert once', () async {
    final location = ScriptedLocationService();
    addTearDown(location.dispose);

    final provider = GuidanceProvider(location: location);
    addTearDown(provider.dispose);

    final option = planGombakToKajang();
    provider.attach(option, builder);
    expect(await provider.startTracking(network), isTrue);

    final destination = stationOf(option.destinationId);

    provider.clearNotice();
    await location.moveTo(3.1390, 101.6869);
    expect(provider.notice, isNull);

    await location.moveTo(destination.lat, destination.lon);
    expect(provider.notice, isNotNull);
    expect(provider.notice, contains(destination.name));

    provider.clearNotice();
    await location.moveTo(destination.lat, destination.lon);
    expect(provider.notice, isNull);
  });

  test('an alert already raised stays quiet when a later one fires', () async {
    final location = ScriptedLocationService();
    addTearDown(location.dispose);

    final provider = GuidanceProvider(location: location);
    addTearDown(provider.dispose);

    final option = planGombakToKajang();
    final guidance = builder.build(option);
    provider.attach(option, builder);
    await provider.startTracking(network);

    for (final alert in guidance.alerts) {
      final station = stationOf(alert.stationId);
      provider.clearNotice();
      await location.moveTo(station.lat, station.lon);
      expect(
        provider.notice,
        contains(station.name),
        reason: 'expected an alert at ${station.name}',
      );
    }

    final first = stationOf(guidance.alerts.first.stationId);
    provider.clearNotice();
    await location.moveTo(first.lat, first.lon);
    expect(
      provider.notice,
      isNull,
      reason: 'a stop already announced must not be announced again',
    );
  });

  test('planning a new journey clears the alerts already raised', () async {
    final location = ScriptedLocationService();
    addTearDown(location.dispose);

    final provider = GuidanceProvider(location: location);
    addTearDown(provider.dispose);

    final option = planGombakToKajang();
    provider.attach(option, builder);
    await provider.startTracking(network);

    final destination = stationOf(option.destinationId);
    await location.moveTo(destination.lat, destination.lon);
    expect(provider.notice, isNotNull);

    provider.attach(planGombakToKajang(), builder);
    provider.clearNotice();
    await location.moveTo(destination.lat, destination.lon);
    expect(provider.notice, contains(destination.name));
  });

  test('the alert radius is wide enough to give warning before the platform',
      () async {
    final location = ScriptedLocationService();
    addTearDown(location.dispose);

    final provider = GuidanceProvider(location: location);
    addTearDown(provider.dispose);

    final option = planGombakToKajang();
    provider.attach(option, builder);
    await provider.startTracking(network);

    final destination = stationOf(option.destinationId);

    provider.clearNotice();
    await location.moveTo(destination.lat + 0.0063, destination.lon);
    expect(provider.notice, isNotNull);
  });
}
