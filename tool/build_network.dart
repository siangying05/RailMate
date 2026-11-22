import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const String gtfsRoot = 'tool/gtfs';
const String outputPath = 'assets/data/rail_network.json';

const double paidInterchangeMetres = 130;
const double walkTransferMetres = 450;
const double walkingMetresPerMinute = 70;

const List<List<String>> forcedWalkLinks = [
  ['Abdullah Hukum', 'Mid Valley'],
  ['Muzium Negara', 'KL Sentral'],
  ['Merdeka', 'Plaza Rakyat'],
  ['Merdeka', 'Maharajalela'],
  ['Bukit Bintang', 'Imbi'],
  ['Bandaraya', 'Bank Negara'],
  ['Sultan Ismail', 'Medan Tuanku'],
  ['Dang Wangi', 'Bukit Nanas'],
  ['Pasar Seni', 'Kuala Lumpur'],
  ['Sentul', 'Sentul Barat'],
  ['Kepong Baru', 'Kepong'],
];

const List<List<String>> blockedLinks = [
  ['Lembah Subang', 'Subang'],
  ['Glenmarie', 'Lembah Subang'],
];

const Map<String, String> nameFixups = {
  'perhentian midvalley': 'Mid Valley',
  'bdr tasek selatan': 'Bandar Tasik Selatan',
  'bandar tasik selatan': 'Bandar Tasik Selatan',
  'kl sentral - redone': 'KL Sentral',
};

const Map<String, LineMeta> lineMeta = {
  'AG': LineMeta(
    id: 'ag',
    name: 'LRT Ampang Line',
    shortName: 'Ampang',
    code: 'LRT',
    mode: 'LRT',
    category: 'urban',
    ridershipKey: 'rail_lrt_ampang',
    dailyCapacity: 210000,
    ridershipShare: 0.5,
    carriages: 6,
  ),
  'PH': LineMeta(
    id: 'sp',
    name: 'LRT Sri Petaling Line',
    shortName: 'Sri Petaling',
    code: 'LRT',
    mode: 'LRT',
    category: 'urban',
    ridershipKey: 'rail_lrt_ampang',
    dailyCapacity: 210000,
    ridershipShare: 0.5,
    carriages: 6,
  ),
  'KJ': LineMeta(
    id: 'kj',
    name: 'LRT Kelana Jaya Line',
    shortName: 'Kelana Jaya',
    code: 'LRT',
    mode: 'LRT',
    category: 'urban',
    ridershipKey: 'rail_lrt_kj',
    dailyCapacity: 520000,
    carriages: 4,
  ),
  'KGL': LineMeta(
    id: 'kg',
    name: 'MRT Kajang Line',
    shortName: 'Kajang',
    code: 'MRT',
    mode: 'MRT',
    category: 'urban',
    ridershipKey: 'rail_mrt_kajang',
    dailyCapacity: 560000,
    carriages: 4,
  ),
  'PYL': LineMeta(
    id: 'py',
    name: 'MRT Putrajaya Line',
    shortName: 'Putrajaya',
    code: 'MRT',
    mode: 'MRT',
    category: 'urban',
    ridershipKey: 'rail_mrt_pjy',
    dailyCapacity: 420000,
    carriages: 4,
  ),
  'MR': LineMeta(
    id: 'mr',
    name: 'KL Monorail Line',
    shortName: 'Monorail',
    code: 'MRL',
    mode: 'Monorail',
    category: 'urban',
    ridershipKey: 'rail_monorail',
    dailyCapacity: 130000,
    carriages: 4,
  ),
  'SA': LineMeta(
    id: 'sa',
    name: 'LRT Shah Alam Line',
    shortName: 'Shah Alam',
    code: 'LRT',
    mode: 'LRT',
    category: 'urban',
    ridershipKey: 'rail_lrt_shah_alam',
    dailyCapacity: 150000,
    carriages: 3,
  ),
  'BRT': LineMeta(
    id: 'brt',
    name: 'BRT Sunway Line',
    shortName: 'Sunway BRT',
    code: 'BRT',
    mode: 'BRT',
    category: 'urban',
    ridershipKey: 'bus_rkl',
    dailyCapacity: 15000,
    ridershipShare: 0.03,
    carriages: 1,
  ),
  'KC05_KB18': LineMeta(
    id: 'kts',
    name: 'KTM Komuter Seremban Line',
    shortName: 'Komuter Seremban',
    code: 'KTM',
    mode: 'Komuter',
    category: 'commuter',
    ridershipKey: 'rail_komuter',
    dailyCapacity: 20000,
    ridershipShare: 0.45,
    carriages: 6,
  ),
  'KA15_KD19': LineMeta(
    id: 'ktp',
    name: 'KTM Komuter Port Klang Line',
    shortName: 'Komuter Port Klang',
    code: 'KTM',
    mode: 'Komuter',
    category: 'commuter',
    ridershipKey: 'rail_komuter',
    dailyCapacity: 20000,
    ridershipShare: 0.45,
    carriages: 6,
  ),
  '100_47300': LineMeta(
    id: 'kpb',
    name: 'KTM Komuter Padang Besar Line',
    shortName: 'Komuter Padang Besar',
    code: 'KTM',
    mode: 'Komuter',
    category: 'commuter',
    ridershipKey: 'rail_komuter_utara',
    dailyCapacity: 20000,
    ridershipShare: 0.5,
    carriages: 6,
  ),
  '100_9000': LineMeta(
    id: 'kip',
    name: 'KTM Komuter Ipoh Line',
    shortName: 'Komuter Ipoh',
    code: 'KTM',
    mode: 'Komuter',
    category: 'commuter',
    ridershipKey: 'rail_komuter_utara',
    dailyCapacity: 20000,
    ridershipShare: 0.5,
    carriages: 6,
  ),
  'SS': LineMeta(
    id: 'kss',
    name: 'KTM Komuter Shuttle Selatan',
    shortName: 'Shuttle Selatan',
    code: 'KTM',
    mode: 'Komuter',
    category: 'commuter',
    ridershipKey: 'rail_komuter',
    dailyCapacity: 4500,
    ridershipShare: 0.10,
    carriages: 4,
  ),
  'ETS': LineMeta(
    id: 'ets',
    name: 'KTM Electric Train Service',
    shortName: 'ETS',
    code: 'ETS',
    mode: 'Intercity',
    category: 'intercity',
    ridershipKey: 'rail_ets',
    dailyCapacity: 45000,
    carriages: 6,
  ),
  'SH': LineMeta(
    id: 'ksh',
    name: 'KTM Intercity Shuttle Tumpat to Gemas',
    shortName: 'Shuttle Tumpat',
    code: 'ICT',
    mode: 'Intercity',
    category: 'intercity',
    ridershipKey: 'rail_intercity',
    dailyCapacity: 5500,
    ridershipShare: 0.5,
    carriages: 6,
  ),
  'ERT': LineMeta(
    id: 'ert',
    name: 'KTM Ekspres Rakyat Timuran',
    shortName: 'Ekspres Timuran',
    code: 'ICT',
    mode: 'Intercity',
    category: 'intercity',
    ridershipKey: 'rail_intercity',
    dailyCapacity: 5500,
    ridershipShare: 0.5,
    carriages: 8,
  ),
  'ST': LineMeta(
    id: 'stb',
    name: 'KTM Shuttle Tebrau',
    shortName: 'Shuttle Tebrau',
    code: 'ICT',
    mode: 'Intercity',
    category: 'intercity',
    ridershipKey: 'rail_tebrau',
    dailyCapacity: 22000,
    carriages: 4,
  ),
};

const Map<String, String> nameOverrides = {
  'KL SENTRAL - REDONE': 'KL Sentral',
  'CIQ': 'JB Sentral CIQ',
  'KOBAH': 'Kobah',
};

const Set<String> acronyms = {
  'KL', 'KLCC', 'PWTC', 'TTDI', 'UPM', 'UKM', 'USJ', 'SS', 'IOI', 'BRT',
  'MRT', 'LRT', 'KTM', 'ETS', 'CIQ', 'TRX', 'HKL', 'UM', 'PJ', 'SK', 'BTS',
  'KLIA', 'ERL', 'SIRIM', 'JB', 'KTMB', 'AU', 'BK5',
};

class LineMeta {
  final String id;
  final String name;
  final String shortName;
  final String code;
  final String mode;
  final String category;
  final String ridershipKey;
  final int dailyCapacity;
  final double ridershipShare;
  final int carriages;

  const LineMeta({
    required this.id,
    required this.name,
    required this.shortName,
    required this.code,
    required this.mode,
    required this.category,
    required this.ridershipKey,
    required this.dailyCapacity,
    required this.carriages,
    this.ridershipShare = 1.0,
  });
}

class Stop {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String operator;
  final bool accessible;

  const Stop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.operator,
    required this.accessible,
  });
}

List<String> parseCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

List<Map<String, String>> readCsv(String path) {
  final file = File(path);
  if (!file.existsSync()) return [];

  final lines = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return [];

  final header = parseCsvLine(lines.first.replaceFirst('﻿', ''))
      .map((h) => h.trim())
      .toList();

  return lines.skip(1).map((line) {
    final values = parseCsvLine(line);
    final row = <String, String>{};
    for (var i = 0; i < header.length; i++) {
      row[header[i]] = i < values.length ? values[i].trim() : '';
    }
    return row;
  }).toList();
}

String titleCase(String raw) {
  var cleaned = raw.trim();

  final fixup = nameFixups[cleaned.toLowerCase()];
  if (fixup != null) return fixup;

  if (nameOverrides.containsKey(cleaned.toUpperCase())) {
    return nameOverrides[cleaned.toUpperCase()]!;
  }

  final dash = cleaned.indexOf(' - ');
  if (dash > 0) cleaned = cleaned.substring(0, dash).trim();

  if (cleaned.toUpperCase().startsWith('PERHENTIAN ')) {
    cleaned = cleaned.substring('PERHENTIAN '.length).trim();
  }

  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) {
        final upper = word.toUpperCase();
        if (acronyms.contains(upper)) return upper;
        if (RegExp(r'^\d').hasMatch(word)) return upper;
        if (word.length <= 1) return upper;
        final head = word.substring(0, 1).toUpperCase();
        final tail = word.substring(1).toLowerCase();
        return '$head$tail';
      })
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

int parseGtfsTime(String value) {
  final parts = value.split(':');
  if (parts.length != 3) return 0;
  final hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  final seconds = int.tryParse(parts[2]) ?? 0;
  return hours * 3600 + minutes * 60 + seconds;
}

double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

void main() {
  final stops = <String, Stop>{};
  final lines = <Map<String, dynamic>>[];

  _loadRapidRail(stops, lines);
  _loadKtmb(stops, lines);

  final usedStopIds = <String>{};
  for (final line in lines) {
    usedStopIds.addAll((line['stations'] as List).cast<String>());
  }
  stops.removeWhere((id, _) => !usedStopIds.contains(id));

  final linesByStop = <String, List<String>>{};
  for (final line in lines) {
    for (final stopId in (line['stations'] as List).cast<String>()) {
      linesByStop.putIfAbsent(stopId, () => <String>[]).add(line['id'] as String);
    }
  }

  final interchanges = _buildInterchanges(stops, linesByStop);

  final stationJson = <String, dynamic>{};
  final sortedIds = stops.keys.toList()..sort();
  for (final id in sortedIds) {
    final stop = stops[id]!;
    stationJson[id] = {
      'name': stop.name,
      'lat': double.parse(stop.lat.toStringAsFixed(6)),
      'lon': double.parse(stop.lon.toStringAsFixed(6)),
      'operator': stop.operator,
      'accessible': stop.accessible,
      'lines': linesByStop[id] ?? const <String>[],
    };
  }

  final output = {
    'meta': {
      'version': '2.0.0',
      'generatedAt': DateTime.now().toIso8601String().split('T').first,
      'sources': [
        'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl',
        'https://api.data.gov.my/gtfs-static/ktmb',
      ],
      'notes':
          'Generated by tool/build_network.dart from official GTFS feeds published on the Malaysian Government Open Data portal. Station coordinates, line colours, running times and service frequencies are taken directly from the feeds. Interchanges are derived from station name and coordinate proximity.',
      'stationCount': stationJson.length,
      'lineCount': lines.length,
      'interchangeCount': interchanges.length,
    },
    'lines': lines,
    'stations': stationJson,
    'interchanges': interchanges,
  };

  final encoder = JsonEncoder.withIndent('  ');
  File(outputPath).writeAsStringSync(encoder.convert(output));

  stdout.writeln('Wrote $outputPath');
  stdout.writeln('  lines        : ${lines.length}');
  stdout.writeln('  stations     : ${stationJson.length}');
  stdout.writeln('  interchanges : ${interchanges.length}');
  final paid = interchanges.where((i) => i['type'] == 'paid').length;
  stdout.writeln('    paid area  : $paid');
  stdout.writeln('    walking    : ${interchanges.length - paid}');
}

void _loadRapidRail(Map<String, Stop> stops, List<Map<String, dynamic>> lines) {
  const dir = '$gtfsRoot/rapid_rail';
  final routes = readCsv('$dir/routes.txt');
  final rawStops = readCsv('$dir/stops.txt');
  final trips = readCsv('$dir/trips.txt');
  final stopTimes = readCsv('$dir/stop_times.txt');
  final frequencies = readCsv('$dir/frequencies.txt');

  for (final row in rawStops) {
    final id = 'rr_${row['stop_id']}';
    stops[id] = Stop(
      id: id,
      name: titleCase(row['stop_name'] ?? ''),
      lat: double.tryParse(row['stop_lat'] ?? '') ?? 0,
      lon: double.tryParse(row['stop_lon'] ?? '') ?? 0,
      operator: 'Rapid Rail',
      accessible: (row['isOKU'] ?? 'false').toLowerCase() == 'true',
    );
  }

  final headwayByTrip = <String, List<Map<String, String>>>{};
  for (final row in frequencies) {
    headwayByTrip.putIfAbsent(row['trip_id'] ?? '', () => []).add(row);
  }

  for (final route in routes) {
    final routeId = route['route_id'] ?? '';
    final meta = lineMeta[routeId];
    if (meta == null) continue;

    final tripCandidates = trips.where(
      (t) =>
          t['route_id'] == routeId &&
          t['direction_id'] == '0' &&
          (t['service_id'] ?? '').toLowerCase().contains('mon'),
    );
    final trip = tripCandidates.isNotEmpty
        ? tripCandidates.first
        : trips.firstWhere(
            (t) => t['route_id'] == routeId && t['direction_id'] == '0',
            orElse: () => <String, String>{},
          );
    if (trip.isEmpty) continue;

    final tripId = trip['trip_id'] ?? '';
    final sequence = stopTimes.where((s) => s['trip_id'] == tripId).toList()
      ..sort(
        (a, b) => (int.tryParse(a['stop_sequence'] ?? '0') ?? 0)
            .compareTo(int.tryParse(b['stop_sequence'] ?? '0') ?? 0),
      );
    if (sequence.length < 2) continue;

    final stationIds = <String>[];
    final hopSeconds = <int>[];
    final hopKm = <double>[];

    for (var i = 0; i < sequence.length; i++) {
      final stopId = 'rr_${sequence[i]['stop_id']}';
      if (!stops.containsKey(stopId)) continue;
      stationIds.add(stopId);

      if (i > 0) {
        final previous = stops[stationIds[stationIds.length - 2]]!;
        final current = stops[stopId]!;
        final departPrevious =
            parseGtfsTime(sequence[i - 1]['departure_time'] ?? '0:00:00');
        final arriveCurrent =
            parseGtfsTime(sequence[i]['arrival_time'] ?? '0:00:00');
        final delta = arriveCurrent - departPrevious;
        hopSeconds.add(delta > 0 ? delta : 120);
        hopKm.add(
          double.parse(
            (haversineMetres(
                      previous.lat,
                      previous.lon,
                      current.lat,
                      current.lon,
                    ) /
                    1000)
                .toStringAsFixed(3),
          ),
        );
      }
    }

    if (stationIds.length < 2) continue;

    final bands = headwayByTrip[tripId] ?? const [];
    var peak = 300;
    var offPeak = 600;
    if (bands.isNotEmpty) {
      final values = bands
          .map((b) => int.tryParse(b['headway_secs'] ?? '') ?? 300)
          .toList()
        ..sort();
      peak = values.first;
      offPeak = values.last;
    }

    lines.add(
      _lineJson(
        meta: meta,
        gtfsRouteId: routeId,
        operator: 'Rapid Rail',
        colour: '#${(route['route_color'] ?? '999999').toUpperCase()}',
        textColour: '#${(route['route_text_color'] ?? 'FFFFFF').toUpperCase()}',
        longName: route['route_long_name'] ?? meta.name,
        stationIds: stationIds,
        hopSeconds: hopSeconds,
        hopKm: hopKm,
        headwayPeak: peak,
        headwayOffPeak: offPeak,
      ),
    );
  }
}

void _loadKtmb(Map<String, Stop> stops, List<Map<String, dynamic>> lines) {
  const dir = '$gtfsRoot/ktmb';
  final routes = readCsv('$dir/routes.txt');
  final rawStops = readCsv('$dir/stops.txt');
  final trips = readCsv('$dir/trips.txt');
  final stopTimes = readCsv('$dir/stop_times.txt');

  for (final row in rawStops) {
    final id = 'km_${row['stop_id']}';
    stops[id] = Stop(
      id: id,
      name: titleCase(row['stop_name'] ?? ''),
      lat: double.tryParse(row['stop_lat'] ?? '') ?? 0,
      lon: double.tryParse(row['stop_lon'] ?? '') ?? 0,
      operator: 'KTM Berhad',
      accessible: true,
    );
  }

  final timesByTrip = <String, List<Map<String, String>>>{};
  for (final row in stopTimes) {
    timesByTrip.putIfAbsent(row['trip_id'] ?? '', () => []).add(row);
  }

  for (final route in routes) {
    final routeId = route['route_id'] ?? '';
    final meta = lineMeta[routeId];
    if (meta == null) continue;

    final routeTrips =
        trips.where((t) => t['route_id'] == routeId).toList();
    if (routeTrips.isEmpty) continue;

    Map<String, String>? bestTrip;
    var bestLength = 0;
    for (final trip in routeTrips) {
      if (trip['direction_id'] != '0') continue;
      final length = (timesByTrip[trip['trip_id']] ?? const []).length;
      if (length > bestLength) {
        bestLength = length;
        bestTrip = trip;
      }
    }
    if (bestTrip == null) continue;

    final sequence = [...(timesByTrip[bestTrip['trip_id']] ?? const [])]..sort(
        (a, b) => (int.tryParse(a['stop_sequence'] ?? '0') ?? 0)
            .compareTo(int.tryParse(b['stop_sequence'] ?? '0') ?? 0),
      );
    if (sequence.length < 2) continue;

    final stationIds = <String>[];
    final hopSeconds = <int>[];
    final hopKm = <double>[];

    for (var i = 0; i < sequence.length; i++) {
      final stopId = 'km_${sequence[i]['stop_id']}';
      if (!stops.containsKey(stopId)) continue;
      stationIds.add(stopId);

      if (i > 0) {
        final departPrevious =
            parseGtfsTime(sequence[i - 1]['departure_time'] ?? '0:00:00');
        final arriveCurrent =
            parseGtfsTime(sequence[i]['arrival_time'] ?? '0:00:00');
        final delta = arriveCurrent - departPrevious;
        hopSeconds.add(delta > 0 ? delta : 300);

        final previousDist =
            double.tryParse(sequence[i - 1]['shape_dist_traveled'] ?? '') ?? 0;
        final currentDist =
            double.tryParse(sequence[i]['shape_dist_traveled'] ?? '') ?? 0;
        var km = currentDist - previousDist;
        if (km <= 0) {
          final previous = stops[stationIds[stationIds.length - 2]]!;
          final current = stops[stopId]!;
          km = haversineMetres(
                previous.lat,
                previous.lon,
                current.lat,
                current.lon,
              ) /
              1000;
        }
        hopKm.add(double.parse(km.toStringAsFixed(3)));
      }
    }

    if (stationIds.length < 2) continue;

    final isIntercity = meta.category == 'intercity';

    lines.add(
      _lineJson(
        meta: meta,
        gtfsRouteId: routeId,
        operator: 'KTM Berhad',
        colour: '#${(route['route_color'] ?? '999999').toUpperCase()}',
        textColour: '#${(route['route_text_color'] ?? 'FFFFFF').toUpperCase()}',
        longName: route['route_long_name'] ?? meta.name,
        stationIds: stationIds,
        hopSeconds: hopSeconds,
        hopKm: hopKm,
        headwayPeak: isIntercity ? 3600 : 1800,
        headwayOffPeak: isIntercity ? 7200 : 3600,
      ),
    );
  }
}

Map<String, dynamic> _lineJson({
  required LineMeta meta,
  required String gtfsRouteId,
  required String operator,
  required String colour,
  required String textColour,
  required String longName,
  required List<String> stationIds,
  required List<int> hopSeconds,
  required List<double> hopKm,
  required int headwayPeak,
  required int headwayOffPeak,
}) {
  return {
    'id': meta.id,
    'gtfsRouteId': gtfsRouteId,
    'name': meta.name,
    'shortName': meta.shortName,
    'longName': longName,
    'code': meta.code,
    'mode': meta.mode,
    'category': meta.category,
    'operator': operator,
    'colour': colour,
    'textColour': textColour,
    'ridershipKey': meta.ridershipKey,
    'ridershipShare': meta.ridershipShare,
    'dailyCapacity': meta.dailyCapacity,
    'carriages': meta.carriages,
    'headwayPeakSecs': headwayPeak,
    'headwayOffPeakSecs': headwayOffPeak,
    'stations': stationIds,
    'hopSeconds': hopSeconds,
    'hopKm': hopKm,
  };
}

bool _matches(List<List<String>> pairs, String a, String b) {
  final lowerA = a.toLowerCase();
  final lowerB = b.toLowerCase();
  for (final pair in pairs) {
    final first = pair[0].toLowerCase();
    final second = pair[1].toLowerCase();
    if ((lowerA == first && lowerB == second) ||
        (lowerA == second && lowerB == first)) {
      return true;
    }
  }
  return false;
}

List<Map<String, dynamic>> _buildInterchanges(
  Map<String, Stop> stops,
  Map<String, List<String>> linesByStop,
) {
  final ids = stops.keys.toList()..sort();
  final result = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (var i = 0; i < ids.length; i++) {
    for (var j = i + 1; j < ids.length; j++) {
      final a = stops[ids[i]]!;
      final b = stops[ids[j]]!;

      final linesA = linesByStop[a.id] ?? const <String>[];
      final linesB = linesByStop[b.id] ?? const <String>[];
      if (linesA.isEmpty || linesB.isEmpty) continue;
      if (linesA.toSet().difference(linesB.toSet()).isEmpty &&
          linesB.toSet().difference(linesA.toSet()).isEmpty &&
          linesA.length == 1) {
        continue;
      }

      final metres = haversineMetres(a.lat, a.lon, b.lat, b.lon);
      final sameName = a.name.toLowerCase() == b.name.toLowerCase();

      if (_matches(blockedLinks, a.name, b.name)) continue;

      final forced = _matches(forcedWalkLinks, a.name, b.name);
      if (!forced) {
        if (metres > walkTransferMetres && !sameName) continue;
        if (sameName && metres > 1500) continue;
      } else if (metres > 1200) {
        continue;
      }

      final key = '${a.id}|${b.id}';
      if (seen.contains(key)) continue;
      seen.add(key);

      final isPaid = metres <= paidInterchangeMetres;
      final walkMinutes = isPaid
          ? math.max(2, (metres / walkingMetresPerMinute).ceil())
          : math.max(3, (metres / walkingMetresPerMinute).ceil() + 2);

      result.add({
        'from': a.id,
        'to': b.id,
        'type': isPaid ? 'paid' : 'walk',
        'metres': metres.round(),
        'walkMinutes': walkMinutes,
        'sameName': sameName,
      });
    }
  }

  result.sort((x, y) => (x['metres'] as int).compareTo(y['metres'] as int));
  return result;
}
