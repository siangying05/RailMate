import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/common_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/journey_provider.dart';
import '../widgets/crowd_overview.dart';
import '../widgets/recent_searches.dart';
import '../widgets/saved_routes.dart';
import '../widgets/search_card.dart';
import 'route_results_screen.dart';

class PlanScreen extends StatelessWidget {
  final VoidCallback onOpenTrips;

  const PlanScreen({super.key, required this.onOpenTrips});

  Future<void> _search(BuildContext context) async {
    final data = context.read<RailDataProvider>();
    final journey = context.read<JourneyProvider>();
    final profile = context.read<AuthProvider>().profile;
    final userId = profile.id;

    journey.setPassengerType(profile.passengerType);

    final started = journey.search(
      planner: data.planner,
      crowdEstimator: data.crowdEstimator,
      userId: userId,
    );

    if (journey.validate() != null) return;

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RouteResultsScreen()),
    );

    await started;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = context.watch<RailDataProvider>();
    final journey = context.watch<JourneyProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<RailDataProvider>().refreshOpenData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${auth.profile.fullName.split(' ').first}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Where are you heading today?',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DataPill(live: data.isLiveData),
                ],
              ),
              const SizedBox(height: 18),
              SearchCard(onSearch: () => _search(context)),
              if (journey.isPeakDeparture) ...[
                const SizedBox(height: 12),
                InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  message:
                      '${TimeUtils.formatMinutes(journey.departureMinutes)} '
                      'falls inside a peak period. Expect busier trains.',
                  colour: AppColors.crowdModerate,
                ),
              ],
              const SizedBox(height: 24),
              SavedRoutes(
                onSelect: (route) {
                  final origin = data.network.station(route.originId);
                  final destination =
                      data.network.station(route.destinationId);
                  if (origin == null || destination == null) return;
                  final journey = context.read<JourneyProvider>();
                  journey.applyPair(origin, destination);
                  if (route.landmark.isNotEmpty) {
                    journey.setLandmark(route.landmark);
                  }
                  _search(context);
                },
              ),
              const CrowdOverview(),
              const SizedBox(height: 24),
              RecentSearches(
                onSelect: (entry) {
                  final origin = data.network.station(entry.originId);
                  final destination =
                      data.network.station(entry.destinationId);
                  if (origin == null || destination == null) return;
                  context
                      .read<JourneyProvider>()
                      .applyPair(origin, destination);
                  _search(context);
                },
              ),
              const SizedBox(height: 8),
              InfoBanner(
                icon: Icons.public_rounded,
                message: data.dataSummary,
                colour: data.isLiveData
                    ? AppColors.crowdLow
                    : theme.colorScheme.primary,
              ),
              if (data.dataWarning != null) ...[
                const SizedBox(height: 10),
                InfoBanner(
                  icon: Icons.cloud_off_rounded,
                  message: data.dataWarning!,
                  colour: AppColors.crowdModerate,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.location_on_rounded,
                      label: 'Stations',
                      value: '${data.network.totalStations}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.linear_scale_rounded,
                      label: 'Rail lines',
                      value: '${data.network.totalLines}',
                      tone: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.swap_calls_rounded,
                      label: 'Interchanges',
                      value: '${data.network.totalInterchanges}',
                      tone: AppColors.crowdModerate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataPill extends StatelessWidget {
  final bool live;

  const _DataPill({required this.live});

  @override
  Widget build(BuildContext context) {
    final colour = live ? AppColors.crowdLow : AppColors.crowdModerate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            live ? 'Live data' : 'Offline data',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}
