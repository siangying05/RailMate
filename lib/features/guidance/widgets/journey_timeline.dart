import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/crowd_chip.dart';
import '../../../core/widgets/line_badge.dart';
import '../../../data/models/guidance.dart';
import '../../../data/models/interchange.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_network.dart';
import '../services/guidance_builder.dart';
import 'carriage_strip.dart';

class JourneyTimeline extends StatelessWidget {
  final JourneyOption option;
  final JourneyGuidance guidance;
  final RailNetwork network;

  const JourneyTimeline({
    super.key,
    required this.option,
    required this.guidance,
    required this.network,
  });

  @override
  Widget build(BuildContext context) {
    var elapsed = 0;
    final rows = <Widget>[];

    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      final at = option.departAt.add(Duration(seconds: elapsed));

      switch (leg.kind) {
        case LegKind.ride:
          rows.add(
            _RideRow(
              leg: leg,
              network: network,
              arriveAt: at,
              isFirst: i == 0,
              platform: guidance.boardingPlatforms[i],
              carriage: guidance.carriageAdvice[i],
            ),
          );
          break;
        case LegKind.transfer:
          rows.add(_TransferRow(leg: leg, network: network));
          break;
        case LegKind.walk:
          rows.add(_WalkRow(leg: leg, network: network));
          break;
      }

      elapsed += leg.seconds;
    }

    rows.add(
      _ArrivalRow(
        stationName: network.stationName(option.destinationId),
        at: option.arriveAt,
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _RideRow extends StatelessWidget {
  final JourneyLeg leg;
  final RailNetwork network;
  final DateTime arriveAt;
  final bool isFirst;
  final PlatformInfo? platform;
  final CarriageAdvice? carriage;

  const _RideRow({
    required this.leg,
    required this.network,
    required this.arriveAt,
    required this.isFirst,
    required this.platform,
    required this.carriage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = network.line(leg.lineId);
    if (line == null) return const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Spine(colour: line.colour, showDot: true, isFirst: isFirst),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          network.stationName(leg.fromStationId),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        TimeUtils.formatClock(arriveAt),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (platform != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            platform!.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Text(
                          platform!.level.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!platform!.verified)
                          Text(
                            'estimated',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: line.colour.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: line.colour.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LineBadge(line: line, showName: true),
                        const SizedBox(height: 8),
                        Text(
                          'Towards ${network.stationName(leg.towardsStationId)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MiniStat(
                              icon: Icons.schedule_rounded,
                              label: TimeUtils.formatDuration(leg.minutes),
                            ),
                            _MiniStat(
                              icon: Icons.linear_scale_rounded,
                              label: leg.stopCount == 1
                                  ? '1 stop'
                                  : '${leg.stopCount} stops',
                            ),
                            _MiniStat(
                              icon: Icons.straighten_rounded,
                              label: '${leg.km.toStringAsFixed(1)} km',
                            ),
                            if (leg.crowd != null)
                              CrowdChip(forecast: leg.crowd!, compact: true),
                          ],
                        ),
                        if (carriage != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          CarriageStrip(advice: carriage!),
                        ],
                        if (leg.passThroughIds.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _PassThrough(
                            stations: leg.passThroughIds
                                .map(network.stationName)
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  final JourneyLeg leg;
  final RailNetwork network;

  const _TransferRow({required this.leg, required this.network});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = leg.interchangeType == InterchangeType.paid;
    final tone = isPaid ? AppColors.paidArea : AppColors.walkLink;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Spine(colour: theme.dividerColor, showDot: false, isFirst: false),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Icon(
                    isPaid
                        ? Icons.door_sliding_rounded
                        : Icons.hourglass_bottom_rounded,
                    size: 16,
                    color: tone,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${leg.note} at '
                      '${network.stationName(leg.fromStationId)} '
                      '(${leg.minutes} min)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkRow extends StatelessWidget {
  final JourneyLeg leg;
  final RailNetwork network;

  const _WalkRow({required this.leg, required this.network});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Spine(colour: theme.dividerColor, showDot: false, isFirst: false),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.walkLink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.walkLink.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      size: 17,
                      color: AppColors.walkLink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exit and walk to '
                            '${network.stationName(leg.toStationId)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${leg.minutes} min, about '
                            '${(leg.km * 1000).round()} m. Tap out and tap in '
                            'again.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalRow extends StatelessWidget {
  final String stationName;
  final DateTime at;

  const _ArrivalRow({required this.stationName, required this.at});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            stationName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          TimeUtils.formatClock(at),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Spine extends StatelessWidget {
  final Color colour;
  final bool showDot;
  final bool isFirst;

  const _Spine({
    required this.colour,
    required this.showDot,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 22,
      child: Column(
        children: [
          if (showDot)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isFirst ? colour : theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colour, width: 3),
              ),
            )
          else
            const SizedBox(height: 4),
          Expanded(
            child: Container(width: 3, color: colour.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PassThrough extends StatefulWidget {
  final List<String> stations;

  const _PassThrough({required this.stations});

  @override
  State<_PassThrough> createState() => _PassThroughState();
}

class _PassThroughState extends State<_PassThrough> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.stations.length == 1
                      ? '1 station along the way'
                      : '${widget.stations.length} stations along the way',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.stations.join('  ·  '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
