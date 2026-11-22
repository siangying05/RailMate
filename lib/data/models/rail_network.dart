import '../../core/utils/geo_utils.dart';
import 'interchange.dart';
import 'rail_line.dart';
import 'station.dart';

class NearbyStation {
  final Station station;
  final double metres;

  const NearbyStation({required this.station, required this.metres});

  int get walkMinutes => GeoUtils.walkMinutes(metres);
}

class RailNetwork {
  final Map<String, Station> stations;
  final List<RailLine> lines;
  final List<Interchange> interchanges;
  final String sourceNote;
  final String version;
  final String generatedAt;

  RailNetwork({
    required this.stations,
    required this.lines,
    required this.interchanges,
    required this.sourceNote,
    required this.version,
    required this.generatedAt,
  });

  factory RailNetwork.fromJson(Map<String, dynamic> json) {
    final lines = (json['lines'] as List)
        .map((e) => RailLine.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawStations = json['stations'] as Map<String, dynamic>;
    final stations = <String, Station>{};
    rawStations.forEach((id, value) {
      stations[id] = Station.fromJson(id, value as Map<String, dynamic>);
    });

    final interchanges = (json['interchanges'] as List)
        .map((e) => Interchange.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = json['meta'] as Map<String, dynamic>? ?? const {};

    return RailNetwork(
      stations: stations,
      lines: lines,
      interchanges: interchanges,
      sourceNote: meta['notes'] as String? ?? '',
      version: meta['version'] as String? ?? '2.0.0',
      generatedAt: meta['generatedAt'] as String? ?? '',
    );
  }

  late final Map<String, RailLine> _lineIndex = {
    for (final line in lines) line.id: line,
  };

  late final Map<String, List<Interchange>> _interchangeIndex = _indexLinks();

  Map<String, List<Interchange>> _indexLinks() {
    final index = <String, List<Interchange>>{};
    for (final link in interchanges) {
      index.putIfAbsent(link.fromStationId, () => []).add(link);
      index.putIfAbsent(link.toStationId, () => []).add(link.reversed());
    }
    return index;
  }

  RailLine? line(String id) => _lineIndex[id];

  Station? station(String id) => stations[id];

  String stationName(String id) => stations[id]?.name ?? id;

  List<Interchange> linksFrom(String stationId) =>
      _interchangeIndex[stationId] ?? const [];

  List<RailLine> linesFor(String stationId) {
    final ids = stations[stationId]?.lineIds ?? const <String>[];
    return ids.map(line).whereType<RailLine>().toList();
  }

  late final List<Station> allStations = () {
    final list = stations.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }();

  late final List<Station> interchangeStations = () {
    final connected = <String>{};
    for (final link in interchanges) {
      connected.add(link.fromStationId);
      connected.add(link.toStationId);
    }
    final list = stations.values
        .where((s) => s.isInterchange || connected.contains(s.id))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }();

  late final List<Station> majorStations = () {
    final scored = <Station, int>{};
    for (final station in stations.values) {
      var score = station.lineIds.length;
      score += linksFrom(station.id).length;
      if (score > 1) scored[station] = score;
    }
    final list = scored.keys.toList()
      ..sort((a, b) {
        final byScore = scored[b]!.compareTo(scored[a]!);
        if (byScore != 0) return byScore;
        return a.name.compareTo(b.name);
      });
    return list;
  }();

  List<Station> search(String query, {int limit = 40}) {
    final normalised = query.trim().toLowerCase();
    if (normalised.isEmpty) return majorStations.take(limit).toList();

    final starts = <Station>[];
    final contains = <Station>[];
    final seenNames = <String>{};

    for (final station in allStations) {
      final name = station.name.toLowerCase();
      final key = '$name|${station.operator}';
      if (seenNames.contains(key)) continue;

      if (name.startsWith(normalised)) {
        starts.add(station);
        seenNames.add(key);
      } else if (station.searchKey.contains(normalised)) {
        contains.add(station);
        seenNames.add(key);
      }
    }

    return [...starts, ...contains].take(limit).toList();
  }

  List<NearbyStation> nearest(
    double lat,
    double lon, {
    int limit = 5,
    double maxMetres = 5000,
  }) {
    final results = <NearbyStation>[];
    for (final station in stations.values) {
      final metres = GeoUtils.distanceMetres(lat, lon, station.lat, station.lon);
      if (metres <= maxMetres) {
        results.add(NearbyStation(station: station, metres: metres));
      }
    }
    results.sort((a, b) => a.metres.compareTo(b.metres));
    return results.take(limit).toList();
  }

  int get totalStations => stations.length;

  int get totalLines => lines.length;

  int get totalInterchanges => interchanges.length;

  List<RailLine> get urbanLines =>
      lines.where((l) => l.category == LineCategory.urban).toList();

  List<RailLine> get intercityLines =>
      lines.where((l) => l.category == LineCategory.intercity).toList();
}
