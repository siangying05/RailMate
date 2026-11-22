import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_network.dart';
import '../../../data/models/vehicle_position.dart';
import '../../../data/services/live_train_service.dart';

/// Shows real, currently-running trains from data.gov.my's GTFS-Realtime
/// feed on an OpenStreetMap base layer. This is the one place in RailMate
/// that reflects an actual train's live position rather than a
/// schedule-based estimate or the rider's own GPS - everywhere else in the
/// app (arrival alerts, crowd levels) is explicit that it isn't this.
class LiveMapScreen extends StatefulWidget {
  final JourneyOption? option;
  final RailNetwork network;

  const LiveMapScreen({super.key, this.option, required this.network});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _service = LiveTrainService();
  final _mapController = MapController();
  StreamSubscription<LiveFeedSnapshot>? _subscription;
  List<VehiclePosition> _vehicles = const [];
  bool _isSample = false;
  DateTime? _lastUpdated;
  bool _loading = true;
  String? _error;

  static const _klCentre = LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _subscription = _service.watchAll().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _vehicles = snapshot.vehicles;
          _isSample = snapshot.isSample;
          _lastUpdated = DateTime.now();
          _loading = false;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not reach the live train feed.';
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _initialCentre {
    final option = widget.option;
    if (option != null) {
      final origin = widget.network.station(option.originId);
      if (origin != null) return LatLng(origin.lat, origin.lon);
    }
    return _klCentre;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _vehicles.where((v) => v.hasFix).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live train positions'),
        actions: [
          IconButton(
            tooltip: 'Centre map',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () => _mapController.move(_initialCentre, 12),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _initialCentre, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'my.railmate.app',
              ),
              MarkerLayer(
                markers: [
                  for (final vehicle in visible)
                    Marker(
                      point: LatLng(vehicle.latitude, vehicle.longitude),
                      width: 34,
                      height: 34,
                      child: Tooltip(
                        message: vehicle.vehicleLabel ?? vehicle.tripId,
                        child: Transform.rotate(
                          angle: vehicle.bearing * math.pi / 180,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_loading)
            const Positioned.fill(
              child: LoadingView(message: 'Finding trains currently running'),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _LiveMapLegend(
              count: visible.length,
              lastUpdated: _lastUpdated,
              error: _error,
              isSample: _isSample,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMapLegend extends StatelessWidget {
  final int count;
  final DateTime? lastUpdated;
  final String? error;
  final bool isSample;

  const _LiveMapLegend({
    required this.count,
    required this.lastUpdated,
    required this.error,
    required this.isSample,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = error ??
        (lastUpdated == null
            ? 'Loading live positions...'
            : isSample
                ? "Showing a bundled sample feed - the live data.gov.my "
                    'endpoint is unreachable right now'
                : '$count train${count == 1 ? '' : 's'} currently running · '
                    'updated ${_ago(lastUpdated!)}');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            error != null
                ? Icons.cloud_off_rounded
                : isSample
                    ? Icons.info_outline_rounded
                    : Icons.train_rounded,
            size: 18,
            color: error != null || isSample
                ? AppColors.crowdModerate
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime time) {
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '${seconds}s ago';
    return '${(seconds / 60).floor()}m ago';
  }
}
