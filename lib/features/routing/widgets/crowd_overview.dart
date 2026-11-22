import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../core/widgets/common_views.dart';
import '../../../core/widgets/crowd_chip.dart';
import '../../../core/widgets/line_badge.dart';
import '../../../data/models/crowd.dart';
import '../../../data/models/rail_line.dart';
import '../providers/journey_provider.dart';

class CrowdOverview extends StatelessWidget {
  const CrowdOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<RailDataProvider>();
    final journey = context.watch<JourneyProvider>();
    final network = data.network;
    final estimator = data.crowdEstimator;
    final at = journey.departAt;

    final stations = network.majorStations.take(10).toList();
    final forecasts = {
      for (final station in stations)
        station.id: estimator.forStation(station, at),
    };

    final sorted = [...stations]..sort(
        (a, b) => forecasts[b.id]!.score.compareTo(forecasts[a.id]!.score),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Predicted crowd levels',
          subtitle: 'Busiest interchanges for ${journey.departureLabel}',
          trailing: IconButton(
            tooltip: 'Refresh open data',
            onPressed: () => context.read<RailDataProvider>().refreshOpenData(),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final station = sorted[index];
              return _StationCrowdCard(
                name: station.name,
                operator: station.operator,
                forecast: forecasts[station.id]!,
                lines: network.linesFor(station.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StationCrowdCard extends StatelessWidget {
  final String name;
  final String operator;
  final CrowdForecast forecast;
  final List<RailLine> lines;

  const _StationCrowdCard({
    required this.name,
    required this.operator,
    required this.forecast,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 176,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LineStripe(lines: lines),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            operator,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          CrowdBar(forecast: forecast),
          const SizedBox(height: 8),
          CrowdChip(forecast: forecast, compact: true, showPercent: true),
        ],
      ),
    );
  }
}
