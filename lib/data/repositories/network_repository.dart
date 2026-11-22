import '../datasources/local/asset_data_source.dart';
import '../models/rail_network.dart';
import '../models/station_exit.dart';

class NetworkBundle {
  final RailNetwork network;
  final Map<String, List<StationExit>> exits;
  final Map<String, StationLayout> layouts;

  const NetworkBundle({
    required this.network,
    required this.exits,
    required this.layouts,
  });
}

class NetworkRepository {
  final AssetDataSource _assets;

  NetworkRepository({AssetDataSource? assets})
      : _assets = assets ?? const AssetDataSource();

  NetworkBundle? _cached;

  Future<NetworkBundle> load() async {
    if (_cached != null) return _cached!;

    final network = await _assets.loadNetwork();
    final exits = await _assets.loadExits();
    final layouts = await _assets.loadLayouts();

    return _cached = NetworkBundle(
      network: network,
      exits: exits,
      layouts: layouts,
    );
  }
}
