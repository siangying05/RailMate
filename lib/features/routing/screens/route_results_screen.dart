import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/crowd.dart';
import '../../../data/models/user_profile.dart';
import '../../guidance/providers/guidance_provider.dart';
import '../../guidance/screens/navigation_screen.dart';
import '../../guidance/services/guidance_builder.dart';
import '../providers/journey_provider.dart';
import '../widgets/route_option_card.dart';

class RouteResultsScreen extends StatelessWidget {
  const RouteResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journey = context.watch<JourneyProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Route options')),
      body: SafeArea(top: false, child: _body(context, journey)),
    );
  }

  Widget _body(BuildContext context, JourneyProvider journey) {
    if (journey.status == JourneyStatus.searching) {
      return const LoadingView(
        message: 'Comparing routes across the network',
      );
    }

    if (journey.status == JourneyStatus.empty) {
      return EmptyState(
        icon: Icons.route_rounded,
        title: 'No route found',
        message: journey.message ??
            'RailMate could not connect these two stations by rail.',
        action: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Change stations'),
        ),
      );
    }

    final origin = journey.origin;
    final destination = journey.destination;
    if (origin == null || destination == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _JourneyHeader(
          originName: origin.name,
          destinationName: destination.name,
          departAt: journey.departAt,
          landmark: journey.landmark,
          preference: journey.preference.label,
        ),
        const SizedBox(height: 18),
        if (journey.quieterWindows.isNotEmpty) ...[
          _QuieterWindows(),
          const SizedBox(height: 18),
        ],
        SectionHeader(
          title: journey.options.length == 1
              ? '1 route option'
              : '${journey.options.length} route options',
          subtitle: 'Ranked using your "${journey.preference.label}" preference',
        ),
        for (var i = 0; i < journey.options.length; i++) ...[
          RouteOptionCard(
            option: journey.options[i],
            isPrimary: i == 0,
            onTap: () {
              final option = journey.options[i];
              final data = context.read<RailDataProvider>();
              context.read<JourneyProvider>().select(option);
              context.read<GuidanceProvider>().attach(
                    option,
                    GuidanceBuilder(
                      network: data.network,
                      platforms: data.platformDirectory,
                      crowdEstimator: data.crowdEstimator,
                    ),
                  );
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NavigationScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  final String originName;
  final String destinationName;
  final DateTime departAt;
  final String landmark;
  final String preference;

  const _JourneyHeader({
    required this.originName,
    required this.destinationName,
    required this.departAt,
    required this.landmark,
    required this.preference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  size: 15, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  originName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: SizedBox(
              height: 18,
              child: VerticalDivider(
                color: Colors.white.withValues(alpha: 0.55),
                thickness: 1.4,
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  destinationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(
                icon: Icons.schedule_rounded,
                label: TimeUtils.formatClock(departAt),
              ),
              _HeaderChip(
                icon: Icons.calendar_today_rounded,
                label: TimeUtils.relativeDay(departAt),
              ),
              _HeaderChip(
                icon: Icons.tune_rounded,
                label: preference,
              ),
              if (landmark.isNotEmpty)
                _HeaderChip(icon: Icons.near_me_rounded, label: landmark),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuieterWindows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windows = context.watch<JourneyProvider>().quieterWindows;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.crowdLow.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.crowdLow.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_down_rounded,
                size: 18,
                color: AppColors.crowdLow,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Travel at a quieter time',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.crowdLow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your departure falls in a busy period. Open ridership data '
            'suggests these windows are less crowded.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final window in windows)
                InkWell(
                  onTap: () {
                    context.read<JourneyProvider>().setDepartureTime(
                          TimeUtils.toTimeOfDay(window.startMinutes),
                        );
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: window.forecast.level.colour
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          window.startLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${window.forecast.level.label} '
                          '${window.forecast.percent}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: window.forecast.level.colour,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
