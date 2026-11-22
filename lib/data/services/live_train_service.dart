import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/vehicle_position.dart';
import 'gtfs_realtime_parser.dart';

/// Which of Malaysia's two rail operators a GTFS-Realtime feed belongs to.
/// Kept as its own tiny enum here rather than reusing [RailNetwork] (the
/// rich station/line graph model) - this service only needs to pick a URL,
/// not know anything about stations or lines.
enum LiveFeedSource { ktmb, rapidRailKl }

/// One tick's worth of vehicle positions, tagged with where they came from
/// so the UI can be honest about it - [isSample] is only ever true when
/// both live endpoints failed and [LiveTrainService.bundledSamplePath] was
/// shown in their place.
class LiveFeedSnapshot {
  final List<VehiclePosition> vehicles;
  final bool isSample;

  const LiveFeedSnapshot(this.vehicles, {required this.isSample});
}

/// Talks to the real data.gov.my GTFS-Realtime Vehicle Position API:
///   KTMB            -> https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb
///   Rapid Rail (KV) -> https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-rail-kl
///
/// Both feeds refresh every ~30s per data.gov.my's own documentation, so
/// [pollingInterval] defaults to that. This is the one part of RailMate
/// that shows genuinely live train positions rather than a schedule-based
/// or GPS-based estimate - everywhere else in the app (arrival alerts,
/// crowd levels) is explicit that it does not have this.
class LiveTrainService {
  static const _ktmbUrl =
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb';
  static const _rapidRailUrl =
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-rail-kl';

  /// A real GTFS-Realtime FeedMessage captured from the KTMB endpoint above
  /// (two vehicles, trips 2964 and 2967) and checked into the app as an
  /// asset. It's decoded by the exact same [parseGtfsRealtimeFeed] used for
  /// the live network response - see
  /// `test/gtfs_realtime_parser_test.dart` - and is only ever shown as a
  /// last resort (below) so a marker still appears on the live map during a
  /// demo run without network access, or if data.gov.my's endpoint is
  /// briefly down.
  static const bundledSamplePath = 'assets/data/vehicleposition_ktmb_sample.bin';

  final http.Client _http;
  LiveTrainService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Duration pollingInterval = const Duration(seconds: 30);

  Future<List<VehiclePosition>> fetchLive(LiveFeedSource source) async {
    final url = source == LiveFeedSource.ktmb ? _ktmbUrl : _rapidRailUrl;
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception(
          'GTFS-Realtime fetch failed (${res.statusCode}) for $url');
    }
    return parseGtfsRealtimeFeed(res.bodyBytes).vehicles;
  }

  /// Loads and decodes [bundledSamplePath]. Exposed separately from
  /// [fetchAllLive] so tests and the fallback path below can both use it.
  Future<List<VehiclePosition>> loadBundledSample() async {
    final bytes = await rootBundle.load(bundledSamplePath);
    return parseGtfsRealtimeFeed(bytes.buffer.asUint8List()).vehicles;
  }

  /// Fetches both operators' feeds and merges everything currently running
  /// into one list. Either feed failing (a flaky mobile connection, or one
  /// operator's endpoint being briefly down) doesn't take the other with
  /// it - it just contributes an empty list for that operator this tick. If
  /// *both* come back empty - most often because the device has no
  /// internet, since data.gov.my requires none of the endpoints below to
  /// authenticate - [bundledSamplePath] is shown instead so the live map
  /// never looks simply broken.
  Future<LiveFeedSnapshot> fetchAllLive() async {
    final results = await Future.wait<List<VehiclePosition>>([
      fetchLive(LiveFeedSource.ktmb)
          .catchError((_) => <VehiclePosition>[]),
      fetchLive(LiveFeedSource.rapidRailKl)
          .catchError((_) => <VehiclePosition>[]),
    ]);
    final live = [...results[0], ...results[1]];
    if (live.isNotEmpty) return LiveFeedSnapshot(live, isSample: false);

    final sample = await loadBundledSample().catchError(
      (_) => <VehiclePosition>[],
    );
    return LiveFeedSnapshot(sample, isSample: sample.isNotEmpty);
  }

  /// A repeating stream a screen can subscribe to from initState. Never
  /// throws - a failed tick yields whatever it managed to fetch (possibly
  /// an empty list) rather than killing the stream, since a live map
  /// should keep trying rather than crash the guidance screen.
  Stream<LiveFeedSnapshot> watchAll() async* {
    while (true) {
      yield await fetchAllLive();
      await Future.delayed(pollingInterval);
    }
  }
}
