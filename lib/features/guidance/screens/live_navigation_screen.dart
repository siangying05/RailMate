import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/widgets/crowd_chip.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_line.dart';
import '../../../data/models/rail_network.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/vehicle_position.dart';
import '../../../data/services/live_train_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ticketing/providers/ticket_provider.dart';
import '../../ticketing/screens/ticket_screen.dart';
import '../providers/guidance_provider.dart';

/// The rider's in-transit view once a ticket is bought - a live map (the
/// rider's own GPS position, the current leg's line drawn between board and
/// alight, and any train the relevant operator's GTFS-Realtime feed is
/// currently publishing) plus a leg-by-leg progress readout that advances
/// itself as the rider's real position nears each interchange, exactly the
/// same way [GuidanceProvider.startTracking]'s arrival alerts do. This is
/// deliberately a different screen from the pre-purchase [NavigationScreen]
/// (which reviews a route before booking, with no live position or ticket
/// to track) - reached only via "Start navigation" / "Resume navigation"
/// on an already-scannable [Ticket].
class LiveNavigationScreen extends StatefulWidget {
  final JourneyOption option;
  final Ticket ticket;

  const LiveNavigationScreen({
    super.key,
    required this.option,
    required this.ticket,
  });

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

class _LiveNavigationScreenState extends State<LiveNavigationScreen> {
  static const _arrivalRadiusMetres = 250.0;

  final _trainService = LiveTrainService();
  final _mapController = MapController();
  Timer? _trainPollTimer;
  List<VehiclePosition> _vehicles = const [];
  bool _isSampleFeed = false;

  int _legIndex = 0;
  bool _completed = false;
  bool _centredOnUser = false;
  GuidanceProvider? _guidance;

  // GPS-in-hand testing (an emulator, or a phone sitting on a desk) can't
  // actually ride a train, so simulated movement is the default - flip to
  // real GPS with the toolbar toggle once there is a device to actually
  // carry along the route. Either way the same [_checkProximity] check
  // drives leg advancement and trip completion.
  bool _useSimulation = true;
  Timer? _simTimer;
  double _simProgress = 0;
  LatLng? _simPosition;
  List<LatLng> _simPath = const [];

  List<JourneyLeg> get _rideLegs => widget.option.rideLegs;
  JourneyLeg get _currentLeg => _rideLegs[_legIndex];
  bool get _isLastLeg => _legIndex == _rideLegs.length - 1;

  @override
  void initState() {
    super.initState();
    if (_rideLegs.isEmpty) return;

    final guidance = context.read<GuidanceProvider>();
    _guidance = guidance;
    guidance.addListener(_onGuidanceChanged);
    _startTracking();
    _pollTrainsForCurrentLeg();
  }

  @override
  void dispose() {
    _guidance?.removeListener(_onGuidanceChanged);
    _trainPollTimer?.cancel();
    _simTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startTracking() {
    if (_useSimulation) {
      _startSimulation();
    } else {
      _simTimer?.cancel();
      final network = context.read<RailDataProvider>().network;
      final guidance = context.read<GuidanceProvider>();
      if (!guidance.tracking) guidance.startTracking(network);
    }
  }

  void _startSimulation() {
    _simTimer?.cancel();
    final network = context.read<RailDataProvider>().network;

    // Walk the same via-station polyline the map draws, not a straight line
    // between board and alight - a straight line visibly cuts across the
    // map on any line with a bend in it, which looks wrong next to the
    // actual track drawn underneath it.
    _simPath = _legPolyline(network);
    if (_simPath.isEmpty) return;

    // Not wrapped in setState: every call site (initState, the GPS/sim
    // toggle, leg advancement) already triggers a rebuild of its own in the
    // same tick, so the next build simply picks up this new value.
    _simPosition = _simPath.first;
    _simTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_completed || !mounted) return;
      setState(() {
        _simProgress = (_simProgress + 0.04).clamp(0.0, 1.0);
        _simPosition = _pointAlongPath(_simPath, _simProgress);
      });
      _checkProximity(_simPosition!.latitude, _simPosition!.longitude);
    });
  }

  /// The point [progress] (0..1) of the way along [path] by cumulative
  /// distance, walked segment by segment - so simulated movement follows
  /// the line's actual bends instead of a straight line that would cut
  /// across the map ignoring them.
  LatLng _pointAlongPath(List<LatLng> path, double progress) {
    if (path.isEmpty) return _simPosition ?? const LatLng(3.1390, 101.6869);
    if (path.length == 1 || progress <= 0) return path.first;
    if (progress >= 1) return path.last;

    final segmentMetres = <double>[];
    var totalMetres = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      final metres = GeoUtils.distanceMetres(
        path[i].latitude,
        path[i].longitude,
        path[i + 1].latitude,
        path[i + 1].longitude,
      );
      segmentMetres.add(metres);
      totalMetres += metres;
    }
    if (totalMetres <= 0) return path.first;

    final targetMetres = totalMetres * progress;
    var coveredMetres = 0.0;
    for (var i = 0; i < segmentMetres.length; i++) {
      final segment = segmentMetres[i];
      final reachesTarget = coveredMetres + segment >= targetMetres;
      if (reachesTarget || i == segmentMetres.length - 1) {
        final segmentProgress = segment > 0
            ? ((targetMetres - coveredMetres) / segment).clamp(0.0, 1.0)
            : 0.0;
        final a = path[i];
        final b = path[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * segmentProgress,
          a.longitude + (b.longitude - a.longitude) * segmentProgress,
        );
      }
      coveredMetres += segment;
    }
    return path.last;
  }

  void _onGuidanceChanged() {
    if (_useSimulation) return;
    final fix = _guidance?.fix;
    if (fix == null || _completed || !mounted) return;
    _checkProximity(fix.latitude, fix.longitude);
  }

  void _pollTrainsForCurrentLeg() {
    _trainPollTimer?.cancel();
    _fetchTrainsOnce();
    _trainPollTimer = Timer.periodic(
      _trainService.pollingInterval,
      (_) => _fetchTrainsOnce(),
    );
  }

  Future<void> _fetchTrainsOnce() async {
    final network = context.read<RailDataProvider>().network;
    final line = network.line(_currentLeg.lineId);
    final source = (line?.category == LineCategory.urban)
        ? LiveFeedSource.rapidRailKl
        : LiveFeedSource.ktmb;

    try {
      final vehicles = await _trainService.fetchLive(source);
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _isSampleFeed = false;
      });
    } catch (_) {
      if (!mounted) return;
      try {
        final sample = await _trainService.loadBundledSample();
        if (!mounted) return;
        setState(() {
          _vehicles = sample;
          _isSampleFeed = sample.isNotEmpty;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _vehicles = const []);
      }
    }
  }

  void _checkProximity(double lat, double lon) {
    final network = context.read<RailDataProvider>().network;
    final alight = network.station(_currentLeg.toStationId);
    if (alight == null) return;

    final metres = GeoUtils.distanceMetres(lat, lon, alight.lat, alight.lon);
    if (metres > _arrivalRadiusMetres) return;

    if (_isLastLeg) {
      _completeTrip();
    } else {
      final nextLine =
          network.line(_rideLegs[_legIndex + 1].lineId)?.shortName ?? '';
      setState(() {
        _legIndex++;
        _simProgress = 0;
      });
      _pollTrainsForCurrentLeg();
      if (_useSimulation) _startSimulation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arrived at ${alight.name} - continue on $nextLine.',
          ),
        ),
      );
    }
  }

  Future<void> _completeTrip() async {
    if (_completed) return;
    _completed = true;
    _simTimer?.cancel();

    final userId = context.read<AuthProvider>().profile.id;
    await context.read<TicketProvider>().markUsed(widget.ticket, userId);
    if (!mounted) return;

    final network = context.read<RailDataProvider>().network;
    final destinationName = network.stationName(_currentLeg.toStationId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trip completed'),
        content: Text(
          'You have arrived at $destinationName. This trip has been '
          'marked as used in My Trips.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    // Deliberately not a single pop back to the ticket this screen was
    // opened from - the trip is over, so returning to that ticket would
    // read as "book again". Go straight back to the app's root instead.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  double _legProgress(RailNetwork network, GuidanceProvider guidance) {
    final fix = guidance.fix;
    if (fix == null) return 0;
    final board = network.station(_currentLeg.fromStationId);
    final alight = network.station(_currentLeg.toStationId);
    if (board == null || alight == null) return 0;

    final total = GeoUtils.distanceMetres(
      board.lat,
      board.lon,
      alight.lat,
      alight.lon,
    );
    if (total <= 0) return 0;
    final remaining = GeoUtils.distanceMetres(
      fix.latitude,
      fix.longitude,
      alight.lat,
      alight.lon,
    );
    return (1 - remaining / total).clamp(0.0, 1.0);
  }

  List<LatLng> _legPolyline(RailNetwork network) {
    final points = <LatLng>[];
    void add(String id) {
      final station = network.station(id);
      if (station == null) return;
      final point = LatLng(station.lat, station.lon);
      if (points.isEmpty || points.last != point) points.add(point);
    }

    add(_currentLeg.fromStationId);
    for (final via in _currentLeg.viaStationIds) {
      add(via);
    }
    add(_currentLeg.toStationId);
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_rideLegs.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('This ticket has no rail legs to navigate.')),
      );
    }

    final data = context.read<RailDataProvider>();
    final network = data.network;
    final guidance = context.watch<GuidanceProvider>();
    final leg = _currentLeg;
    final line = network.line(leg.lineId);
    final crowd = leg.crowd ?? widget.option.crowd;
    final board = network.station(leg.fromStationId);
    final alight = network.station(leg.toStationId);
    final visibleVehicles = _vehicles.where((v) => v.hasFix).toList();

    final progress = _useSimulation
        ? _simProgress
        : _legProgress(network, guidance);
    final userPoint = _useSimulation
        ? _simPosition
        : (guidance.fix != null
            ? LatLng(guidance.fix!.latitude, guidance.fix!.longitude)
            : null);
    final mapCentre = userPoint ??
        (board != null ? LatLng(board.lat, board.lon) : const LatLng(3.1390, 101.6869));

    if (userPoint != null && !_centredOnUser) {
      _centredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(mapCentre, 14);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Leg ${_legIndex + 1} / ${_rideLegs.length}'),
        actions: [
          IconButton(
            tooltip: _useSimulation
                ? 'Simulating movement - tap for real GPS'
                : 'Using real GPS - tap to simulate',
            icon: Icon(
              _useSimulation ? Icons.smart_toy_outlined : Icons.gps_fixed,
            ),
            onPressed: () {
              setState(() => _useSimulation = !_useSimulation);
              _startTracking();
            },
          ),
          IconButton(
            tooltip: 'View ticket',
            icon: const Icon(Icons.confirmation_number_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TicketScreen(ticket: widget.ticket),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: mapCentre, initialZoom: 13),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'my.railmate.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _legPolyline(network),
                          strokeWidth: 4,
                          color: line?.colour ?? theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (board != null)
                          Marker(
                            point: LatLng(board.lat, board.lon),
                            width: 22,
                            height: 22,
                            child: const Icon(Icons.circle_rounded,
                                color: AppColors.crowdLow, size: 16),
                          ),
                        if (alight != null)
                          Marker(
                            point: LatLng(alight.lat, alight.lon),
                            width: 24,
                            height: 24,
                            child: const Icon(Icons.flag_rounded,
                                color: AppColors.crowdHigh, size: 22),
                          ),
                        for (final vehicle in visibleVehicles)
                          Marker(
                            point: LatLng(vehicle.latitude, vehicle.longitude),
                            width: 30,
                            height: 30,
                            child: Tooltip(
                              message: vehicle.vehicleLabel ?? vehicle.tripId,
                              child: Transform.rotate(
                                angle: vehicle.bearing * math.pi / 180,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.navigation_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        if (userPoint != null)
                          Marker(
                            point: userPoint,
                            width: 32,
                            height: 32,
                            child: const Tooltip(
                              message: 'You are here',
                              child: Icon(Icons.person_pin_circle_rounded,
                                  color: AppColors.accent, size: 34),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (userPoint == null)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: _StatusPill(
                      text: guidance.locating
                          ? 'Finding your location...'
                          : (guidance.notice?.isNotEmpty ?? false)
                              ? guidance.notice!
                              : 'Waiting for a GPS fix...',
                      icon: Icons.location_searching_rounded,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${line?.shortName ?? leg.lineId} towards '
                        '${network.stationName(leg.toStationId)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    CrowdChip(forecast: crowd),
                  ],
                ),
                const SizedBox(height: 12),
                _InstructionBanner(
                  legLabel: line?.shortName ?? leg.lineId,
                  stationName: network.stationName(leg.toStationId),
                  progress: progress,
                  isLastLeg: _isLastLeg,
                  hasFix: userPoint != null,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
                const SizedBox(height: 6),
                Text(
                  '${network.stationName(leg.fromStationId)} → '
                  '${network.stationName(leg.toStationId)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  visibleVehicles.isNotEmpty
                      ? (_isSampleFeed
                          ? 'Showing a bundled sample feed - the live '
                              "data.gov.my endpoint isn't reachable right now."
                          : 'Live train position available for '
                              '${line?.operator ?? ''} (updates every '
                              '~${_trainService.pollingInterval.inSeconds}s).')
                      : 'No live train position right now for '
                          '${line?.operator ?? ''} - showing your progress '
                          'along the route instead.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Remaining steps',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = _legIndex; i < _rideLegs.length; i++)
                  _RemainingStepTile(
                    active: i == _legIndex,
                    label: '${network.line(_rideLegs[i].lineId)?.shortName ?? _rideLegs[i].lineId}: '
                        '${network.stationName(_rideLegs[i].fromStationId)} → '
                        '${network.stationName(_rideLegs[i].toStationId)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _StatusPill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.crowdModerate),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: theme.textTheme.labelSmall)),
        ],
      ),
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  final String legLabel;
  final String stationName;
  final double progress;
  final bool isLastLeg;
  final bool hasFix;

  const _InstructionBanner({
    required this.legLabel,
    required this.stationName,
    required this.progress,
    required this.isLastLeg,
    required this.hasFix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String text;
    IconData icon;

    if (!hasFix) {
      text = 'Board $legLabel towards $stationName.';
      icon = Icons.directions_walk_rounded;
    } else if (progress < 0.15) {
      text = 'Board $legLabel towards $stationName.';
      icon = Icons.directions_walk_rounded;
    } else if (progress < 0.85) {
      text = 'In transit towards $stationName.';
      icon = Icons.train_rounded;
    } else if (!isLastLeg) {
      text = 'Prepare to alight and transfer at $stationName.';
      icon = Icons.compare_arrows_rounded;
    } else {
      text = 'Prepare to alight at $stationName - your destination.';
      icon = Icons.flag_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _RemainingStepTile extends StatelessWidget {
  final bool active;
  final String label;

  const _RemainingStepTile({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            active ? Icons.radio_button_checked_rounded : Icons.circle_outlined,
            size: 18,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
