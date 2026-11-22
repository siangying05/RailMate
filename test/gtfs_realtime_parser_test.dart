import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/data/services/gtfs_realtime_parser.dart';
import 'package:railmate/data/services/live_train_service.dart';

/// Confirms the hand-rolled GTFS-Realtime decoder (see
/// lib/data/services/gtfs_realtime_parser.dart) correctly reads a real
/// FeedMessage - not just synthetic bytes. The fixture is
/// assets/data/vehicleposition_ktmb_sample.bin, a genuine capture from
/// https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb containing
/// two vehicles (trips 2964 and 2967), also bundled into the app itself as
/// [LiveTrainService]'s offline fallback for the live train map.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the bundled KTMB vehicle-position sample', () async {
    final data = await rootBundle.load(LiveTrainService.bundledSamplePath);
    final feed = parseGtfsRealtimeFeed(data.buffer.asUint8List());

    expect(feed.version, '2.0');
    expect(feed.vehicles, hasLength(2));

    final byTrip = {for (final v in feed.vehicles) v.tripId: v};
    expect(byTrip.keys, containsAll(['2964', '2967']));

    final first = byTrip['2964']!;
    expect(first.vehicleId, '2964');
    expect(first.vehicleLabel, 'SCS27');
    expect(first.hasFix, isTrue);

    final second = byTrip['2967']!;
    expect(second.vehicleId, '2967');
    expect(second.vehicleLabel, 'SCS29');
    expect(second.hasFix, isTrue);
  });

  test('LiveTrainService.loadBundledSample decodes the same fixture',
      () async {
    final service = LiveTrainService();
    final vehicles = await service.loadBundledSample();

    expect(vehicles, hasLength(2));
    expect(vehicles.every((v) => v.hasFix), isTrue);
  });
}
