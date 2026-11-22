import '../datasources/local/asset_data_source.dart';
import '../models/guidance.dart';
import '../models/rail_network.dart';

class PlatformDirectory {
  final RailNetwork network;
  final Map<String, StationLayout> layouts;

  const PlatformDirectory({required this.network, required this.layouts});

  StationLayout? layoutFor(String stationId) {
    final station = network.station(stationId);
    if (station == null) return null;
    return layouts[station.name.toLowerCase()];
  }

  bool isVerified(String stationId) => layoutFor(stationId)?.verified ?? false;

  PlatformInfo platformFor({
    required String stationId,
    required String lineId,
    required String towardsStationId,
  }) {
    final line = network.line(lineId);
    final outbound = line != null &&
        line.stationIds.isNotEmpty &&
        towardsStationId == line.stationIds.last;

    final layout = layoutFor(stationId);
    if (layout != null) {
      for (final entry in layout.platforms) {
        if (entry.lineId != lineId) continue;
        if (entry.isOutbound != outbound) continue;
        return PlatformInfo(
          stationId: stationId,
          lineId: lineId,
          platform: entry.platform,
          towardsStationId: towardsStationId,
          level: _level(entry.level),
          verified: layout.verified,
        );
      }
    }

    return PlatformInfo(
      stationId: stationId,
      lineId: lineId,
      platform: _derivePlatform(stationId, lineId, outbound),
      towardsStationId: towardsStationId,
      level: PlatformLevel.concourse,
      verified: false,
    );
  }

  LayoutTransfer? transferFor({
    required String stationId,
    required String fromLineId,
    required String toLineId,
  }) {
    final layout = layoutFor(stationId);
    if (layout == null) return null;

    for (final transfer in layout.transfers) {
      if (transfer.fromLineId == fromLineId && transfer.toLineId == toLineId) {
        return transfer;
      }
    }
    return null;
  }

  String _derivePlatform(String stationId, String lineId, bool outbound) {
    final station = network.station(stationId);
    if (station == null) return outbound ? '1' : '2';

    final ordered = [...station.lineIds]..sort();
    final index = ordered.indexOf(lineId);
    final base = (index < 0 ? 0 : index) * 2;
    return '${base + (outbound ? 1 : 2)}';
  }

  PlatformLevel _level(String raw) {
    switch (raw) {
      case 'upper':
        return PlatformLevel.upper;
      case 'lower':
        return PlatformLevel.lower;
      case 'ground':
        return PlatformLevel.ground;
      default:
        return PlatformLevel.concourse;
    }
  }
}
