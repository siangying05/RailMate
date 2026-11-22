import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/rail_network.dart';
import '../../models/ridership.dart';
import '../../models/station_exit.dart';

class StationLayout {
  final bool verified;
  final List<LayoutPlatform> platforms;
  final List<LayoutTransfer> transfers;

  const StationLayout({
    required this.verified,
    required this.platforms,
    required this.transfers,
  });

  factory StationLayout.fromJson(Map<String, dynamic> json) {
    return StationLayout(
      verified: json['verified'] as bool? ?? false,
      platforms: (json['platforms'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LayoutPlatform.fromJson)
          .toList(),
      transfers: (json['transfers'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LayoutTransfer.fromJson)
          .toList(),
    );
  }
}

class LayoutPlatform {
  final String lineId;
  final String direction;
  final String platform;
  final String level;

  const LayoutPlatform({
    required this.lineId,
    required this.direction,
    required this.platform,
    required this.level,
  });

  factory LayoutPlatform.fromJson(Map<String, dynamic> json) {
    return LayoutPlatform(
      lineId: json['line'] as String,
      direction: json['direction'] as String? ?? 'outbound',
      platform: json['platform'] as String? ?? '1',
      level: json['level'] as String? ?? 'concourse',
    );
  }

  bool get isOutbound => direction == 'outbound';
}

class LayoutTransfer {
  final String fromLineId;
  final String toLineId;
  final List<int> carriages;
  final int walkSeconds;
  final bool stepFree;
  final String note;

  const LayoutTransfer({
    required this.fromLineId,
    required this.toLineId,
    required this.carriages,
    required this.walkSeconds,
    required this.stepFree,
    required this.note,
  });

  factory LayoutTransfer.fromJson(Map<String, dynamic> json) {
    return LayoutTransfer(
      fromLineId: json['from'] as String,
      toLineId: json['to'] as String,
      carriages: (json['carriages'] as List? ?? []).map((e) => e as int).toList(),
      walkSeconds: json['walkSeconds'] as int? ?? 180,
      stepFree: json['stepFree'] as bool? ?? true,
      note: json['note'] as String? ?? '',
    );
  }
}

class AssetDataSource {
  static const String networkPath = 'assets/data/rail_network.json';
  static const String exitsPath = 'assets/data/station_exits.json';
  static const String layoutsPath = 'assets/data/station_layouts.json';
  static const String ridershipPath = 'assets/data/ridership_snapshot.json';

  const AssetDataSource();

  Future<RailNetwork> loadNetwork() async {
    final raw = await rootBundle.loadString(networkPath);
    return RailNetwork.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<Map<String, List<StationExit>>> loadExits() async {
    final raw = await rootBundle.loadString(exitsPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final exits = decoded['exits'] as Map<String, dynamic>;

    return exits.map((name, value) {
      final list = (value as List)
          .whereType<Map<String, dynamic>>()
          .map(StationExit.fromJson)
          .toList();
      return MapEntry(name.toLowerCase(), list);
    });
  }

  Future<Map<String, StationLayout>> loadLayouts() async {
    final raw = await rootBundle.loadString(layoutsPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final layouts = decoded['layouts'] as Map<String, dynamic>;

    return layouts.map(
      (name, value) => MapEntry(
        name.toLowerCase(),
        StationLayout.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<List<RidershipRecord>> loadRidershipSnapshot() async {
    final raw = await rootBundle.loadString(ridershipPath);
    final decoded = jsonDecode(raw) as List;
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((row) => row['date'] != null)
        .map(RidershipRecord.fromJson)
        .toList();
  }
}
