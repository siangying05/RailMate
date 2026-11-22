import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum LineCategory { urban, commuter, intercity }

class RailLine {
  final String id;
  final String gtfsRouteId;
  final String name;
  final String shortName;
  final String longName;
  final String code;
  final String mode;
  final LineCategory category;
  final String operator;
  final String colourHex;
  final String textColourHex;
  final String ridershipKey;
  final double ridershipShare;
  final int dailyCapacity;
  final int carriages;
  final int headwayPeakSecs;
  final int headwayOffPeakSecs;
  final List<String> stationIds;
  final List<int> hopSeconds;
  final List<double> hopKm;

  const RailLine({
    required this.id,
    required this.gtfsRouteId,
    required this.name,
    required this.shortName,
    required this.longName,
    required this.code,
    required this.mode,
    required this.category,
    required this.operator,
    required this.colourHex,
    required this.textColourHex,
    required this.ridershipKey,
    required this.ridershipShare,
    required this.dailyCapacity,
    required this.carriages,
    required this.headwayPeakSecs,
    required this.headwayOffPeakSecs,
    required this.stationIds,
    required this.hopSeconds,
    required this.hopKm,
  });

  factory RailLine.fromJson(Map<String, dynamic> json) {
    return RailLine(
      id: json['id'] as String,
      gtfsRouteId: json['gtfsRouteId'] as String? ?? '',
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      longName: json['longName'] as String? ?? json['name'] as String,
      code: json['code'] as String,
      mode: json['mode'] as String? ?? json['code'] as String,
      category: _category(json['category'] as String?),
      operator: json['operator'] as String,
      colourHex: json['colour'] as String,
      textColourHex: json['textColour'] as String? ?? '#FFFFFF',
      ridershipKey: json['ridershipKey'] as String,
      ridershipShare: (json['ridershipShare'] as num?)?.toDouble() ?? 1.0,
      dailyCapacity: json['dailyCapacity'] as int? ?? 100000,
      carriages: json['carriages'] as int? ?? 4,
      headwayPeakSecs: json['headwayPeakSecs'] as int? ?? 300,
      headwayOffPeakSecs: json['headwayOffPeakSecs'] as int? ?? 600,
      stationIds: (json['stations'] as List).cast<String>(),
      hopSeconds: (json['hopSeconds'] as List).map((e) => e as int).toList(),
      hopKm: (json['hopKm'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  static LineCategory _category(String? raw) {
    switch (raw) {
      case 'commuter':
        return LineCategory.commuter;
      case 'intercity':
        return LineCategory.intercity;
      default:
        return LineCategory.urban;
    }
  }

  Color get colour => AppColors.parseHex(colourHex);

  Color get textColour => AppColors.parseHex(textColourHex);

  int get stationCount => stationIds.length;

  int indexOf(String stationId) => stationIds.indexOf(stationId);

  bool serves(String stationId) => stationIds.contains(stationId);

  int hopSecondsAt(int index) {
    if (index < 0 || index >= hopSeconds.length) return 150;
    return hopSeconds[index];
  }

  double hopKmAt(int index) {
    if (index < 0 || index >= hopKm.length) return 1.0;
    return hopKm[index];
  }

  int headwaySecs({required bool peak}) =>
      peak ? headwayPeakSecs : headwayOffPeakSecs;

  int expectedWaitMinutes({required bool peak}) {
    final headway = headwaySecs(peak: peak);
    return (headway / 120).ceil();
  }

  String terminusTowards(int fromIndex, int toIndex) {
    return toIndex > fromIndex ? stationIds.last : stationIds.first;
  }

  bool get isIntercity => category == LineCategory.intercity;

  bool get requiresSeatReservation => category == LineCategory.intercity;
}
