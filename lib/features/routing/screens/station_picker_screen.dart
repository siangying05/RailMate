import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/widgets/common_views.dart';
import '../../../core/widgets/line_badge.dart';
import '../../../data/models/rail_network.dart';
import '../../../data/models/station.dart';
import '../../guidance/providers/guidance_provider.dart';

class StationPickerScreen extends StatefulWidget {
  final String title;
  final String? excludeStationId;

  const StationPickerScreen({
    super.key,
    required this.title,
    this.excludeStationId,
  });

  @override
  State<StationPickerScreen> createState() => _StationPickerScreenState();
}

class _StationPickerScreenState extends State<StationPickerScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  List<NearbyStation> _nearby = const [];
  bool _locating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _findNearby() async {
    setState(() => _locating = true);

    final network = context.read<RailDataProvider>().network;
    final guidance = context.read<GuidanceProvider>();
    final results = await guidance.nearbyStations(network, limit: 5);

    if (!mounted) return;
    setState(() {
      _nearby = results;
      _locating = false;
    });

    if (results.isEmpty && guidance.notice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(guidance.notice!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final network = context.read<RailDataProvider>().network;
    final results = network
        .search(_query, limit: 60)
        .where((station) => station.id != widget.excludeStationId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search station or line',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (_query.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _findNearby,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    _locating
                        ? 'Finding your location'
                        : 'Use my current location',
                  ),
                ),
              ),
            Expanded(
              child: results.isEmpty && _nearby.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No station found',
                      message:
                          'Check the spelling, or search by the line name such '
                          'as Kelana Jaya or Komuter.',
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (_nearby.isNotEmpty && _query.isEmpty) ...[
                          const _SectionLabel('NEAREST TO YOU'),
                          for (final nearby in _nearby)
                            _StationTile(
                              station: nearby.station,
                              trailingText:
                                  '${GeoUtils.formatDistance(nearby.metres)} '
                                  'away',
                              onTap: () =>
                                  Navigator.of(context).pop(nearby.station),
                            ),
                          const SizedBox(height: 8),
                        ],
                        _SectionLabel(
                          _query.isEmpty ? 'MAJOR STATIONS' : 'RESULTS',
                        ),
                        for (final station in results)
                          _StationTile(
                            station: station,
                            onTap: () => Navigator.of(context).pop(station),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  final Station station;
  final String? trailingText;
  final VoidCallback onTap;

  const _StationTile({
    required this.station,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final network = context.read<RailDataProvider>().network;
    final lines = network.linesFor(station.id);
    final connections = network.linksFrom(station.id).length;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        station.isInterchange || connections > 0
            ? Icons.swap_calls_rounded
            : Icons.train_rounded,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        station.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final line in lines) LineBadge(line: line, compact: true),
            Text(
              station.operator,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (station.accessible)
              Icon(
                Icons.accessible_rounded,
                size: 14,
                color: AppColors.accent,
              ),
          ],
        ),
      ),
      trailing: trailingText == null
          ? const Icon(Icons.chevron_right_rounded)
          : Text(
              trailingText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
