import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/crowd_chip.dart';
import '../../../core/widgets/line_badge.dart';
import '../../../data/models/interchange.dart';
import '../../../data/models/journey.dart';

class RouteOptionCard extends StatelessWidget {
  final JourneyOption option;
  final bool isPrimary;
  final VoidCallback onTap;

  const RouteOptionCard({
    super.key,
    required this.option,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final network = context.read<RailDataProvider>().network;

    final transferNames = <String>[];
    for (var i = 1; i < option.rideLegs.length; i++) {
      transferNames.add(
        network.stationName(option.rideLegs[i].fromStationId),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPrimary
                ? theme.colorScheme.primary.withValues(alpha: 0.55)
                : theme.dividerColor,
            width: isPrimary ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (option.strategies.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPrimary
                          ? Icons.star_rounded
                          : Icons.check_circle_rounded,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        option.strategies
                            .map((strategy) => strategy.label)
                            .join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TimeUtils.formatDuration(option.totalMinutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${TimeUtils.formatClock(option.departAt)} to '
                              '${TimeUtils.formatClock(option.arriveAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      CrowdChip(forecast: option.crowd, compact: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _LineFlow(option: option),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _Metric(
                        icon: Icons.swap_calls_rounded,
                        label: option.transferCount == 0
                            ? 'Direct'
                            : '${option.transferCount} transfer'
                                '${option.transferCount > 1 ? "s" : ""}',
                      ),
                      _Metric(
                        icon: Icons.confirmation_number_rounded,
                        label: option.fare.formatted,
                      ),
                      _Metric(
                        icon: Icons.linear_scale_rounded,
                        label: option.stationCount == 1
                            ? '1 stop'
                            : '${option.stationCount} stops',
                      ),
                    ],
                  ),
                  if (transferNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: (option.isPaidAreaOnly
                                ? AppColors.paidArea
                                : AppColors.walkLink)
                            .withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option.isPaidAreaOnly
                                ? Icons.door_sliding_rounded
                                : Icons.directions_walk_rounded,
                            size: 15,
                            color: option.isPaidAreaOnly
                                ? AppColors.paidArea
                                : AppColors.walkLink,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${option.isPaidAreaOnly ? "Inside gates" : "Exit and walk"}'
                              ' at ${transferNames.join(", ")}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineFlow extends StatelessWidget {
  final JourneyOption option;

  const _LineFlow({required this.option});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final network = context.read<RailDataProvider>().network;

    final items = <Widget>[];
    for (final leg in option.legs) {
      if (leg.kind == LegKind.ride) {
        final line = network.line(leg.lineId);
        if (line == null) continue;
        items.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: line.colour.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: line.colour.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LineBadge(line: line, compact: true),
                const SizedBox(width: 7),
                Text(
                  '${leg.minutes}m',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (leg.kind == LegKind.walk) {
        items.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_walk_rounded,
                size: 15,
                color: AppColors.walkLink,
              ),
              Text(
                '${leg.minutes}m',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.walkLink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      } else if (leg.kind == LegKind.transfer &&
          leg.interchangeType == InterchangeType.paid &&
          !leg.note.startsWith('Wait')) {
        items.add(
          Icon(
            Icons.door_sliding_rounded,
            size: 15,
            color: AppColors.paidArea,
          ),
        );
      }
    }

    final withArrows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      withArrows.add(items[i]);
      if (i < items.length - 1) {
        withArrows.add(
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: withArrows,
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
