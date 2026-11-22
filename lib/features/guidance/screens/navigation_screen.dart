import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/common_views.dart';
import '../../../core/widgets/crowd_chip.dart';
import '../../../data/models/crowd.dart';
import '../../../data/models/guidance.dart';
import '../../../data/models/interchange.dart';
import '../../../data/models/station_exit.dart';
import '../../auth/providers/auth_provider.dart';
import '../../routing/providers/journey_provider.dart';
import '../../ticketing/providers/ticket_provider.dart';
import '../../ticketing/screens/booking_screen.dart';
import '../providers/guidance_provider.dart';
import '../widgets/journey_timeline.dart';
import 'live_map_screen.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = context.read<RailDataProvider>();
    final journey = context.watch<JourneyProvider>();
    final guidanceProvider = context.watch<GuidanceProvider>();

    final option = journey.selected;
    final guidance = guidanceProvider.guidance;

    if (option == null || guidance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Navigation')),
        body: const EmptyState(
          icon: Icons.navigation_rounded,
          title: 'No route selected',
          message: 'Choose one of the route options to see the full guidance.',
        ),
      );
    }

    final network = data.network;
    final exitSuggestion = data.exitRecommender.recommend(
      network.stationName(option.destinationId),
      journey.landmark,
      preferStepFree: context.read<AuthProvider>().profile.avoidStairs,
    );
    final exits = data.exitRecommender
        .exitsFor(network.stationName(option.destinationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        actions: [
          IconButton(
            tooltip: 'Live navigation',
            icon: const Icon(Icons.map_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveMapScreen(option: option, network: network),
              ),
            ),
          ),
          IconButton(
            tooltip: guidanceProvider.tracking
                ? 'Stop arrival alerts'
                : 'Start arrival alerts',
            icon: Icon(
              guidanceProvider.tracking
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: guidanceProvider.tracking ? AppColors.accent : null,
            ),
            onPressed: () async {
              final provider = context.read<GuidanceProvider>();
              if (provider.tracking) {
                provider.stopTracking();
              } else {
                await provider.startTracking(network);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              '${network.stationName(option.originId)}  to  '
              '${network.stationName(option.destinationId)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Departing ${TimeUtils.formatClock(option.departAt)}, arriving '
              '${TimeUtils.formatClock(option.arriveAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.schedule_rounded,
                    label: 'Travel time',
                    value: TimeUtils.formatDuration(option.totalMinutes),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.swap_calls_rounded,
                    label: 'Transfers',
                    value: option.transferCount == 0
                        ? 'Direct'
                        : '${option.transferCount}',
                    tone: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.confirmation_number_rounded,
                    label: 'Estimated fare',
                    value: option.fare.formatted,
                    tone: AppColors.brandDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.groups_rounded,
                    label: 'Crowd level',
                    value: option.crowd.level.label,
                    tone: option.crowd.level.colour,
                  ),
                ),
              ],
            ),
            if (guidanceProvider.notice != null) ...[
              const SizedBox(height: 16),
              InfoBanner(
                icon: Icons.info_outline_rounded,
                message: guidanceProvider.notice!,
                colour: AppColors.accent,
                action: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () =>
                      context.read<GuidanceProvider>().clearNotice(),
                ),
              ),
            ],
            if (guidance.transfers.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Transfer guidance',
                subtitle: 'Where to change, and whether you leave the gates',
              ),
              for (final transfer in guidance.transfers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TransferCard(
                    transfer: transfer,
                    stationName: network.stationName(transfer.stationId),
                    fromLine: network.line(transfer.fromLineId)?.shortName ?? '',
                    toLine: network.line(transfer.toLineId)?.shortName ?? '',
                  ),
                ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Step by step',
                    subtitle: 'Platform, direction and carriage for each leg',
                  ),
                ),
                CrowdChip(
                  forecast: option.crowd,
                  compact: true,
                  showPercent: true,
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: JourneyTimeline(
                  option: option,
                  guidance: guidance,
                  network: network,
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (exitSuggestion != null)
              _ExitCard(
                suggestion: exitSuggestion,
                allExits: exits,
                stationName: network.stationName(option.destinationId),
                hasLandmark: journey.landmark.isNotEmpty,
              )
            else
              InfoBanner(
                icon: Icons.info_outline_rounded,
                message:
                    'Exit information is not yet available for '
                    '${network.stationName(option.destinationId)}.',
              ),
            const SizedBox(height: 18),
            InfoBanner(
              icon: Icons.insights_rounded,
              message: '${option.crowd.level.advice} '
                  '${data.crowdEstimator.dataNarrative()}',
              colour: option.crowd.level.colour,
            ),
            const SizedBox(height: 10),
            const InfoBanner(
              icon: Icons.my_location_rounded,
              message:
                  'Arrival alerts use your own GPS position to tell you when '
                  'your interchange or destination is close. Tap the map '
                  'icon above for live navigation - your position and '
                  "real, currently-running trains from data.gov.my's live "
                  'feed, together on one map.',
              colour: AppColors.crowdModerate,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                if (auth.isGuest) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sign in to buy a ticket for this route.'),
                    ),
                  );
                  return;
                }

                context.read<TicketProvider>().startBooking(
                      option: option,
                      network: network,
                      passengers: journey.passengers,
                      passengerType: auth.profile.passengerType,
                      card: journey.card,
                    );
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookingScreen()),
                );
              },
              icon: const Icon(Icons.confirmation_number_rounded),
              label: Text('Book this journey  ·  ${option.fare.formatted}'),
            ),
            const SizedBox(height: 10),
            Text(
              AppInfo.paymentDisclaimer,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final TransferGuidance transfer;
  final String stationName;
  final String fromLine;
  final String toLine;

  const _TransferCard({
    required this.transfer,
    required this.stationName,
    required this.fromLine,
    required this.toLine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = transfer.type == InterchangeType.paid;
    final tone = isPaid ? AppColors.paidArea : AppColors.walkLink;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaid
                    ? Icons.door_sliding_rounded
                    : Icons.directions_walk_rounded,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stationName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  transfer.type.shortLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlatformBox(
                  label: 'Arrive',
                  line: fromLine,
                  platform: transfer.arrivePlatform,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 18),
              ),
              Expanded(
                child: _PlatformBox(
                  label: 'Depart',
                  line: toLine,
                  platform: transfer.departPlatform,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            transfer.instruction,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: tone),
                  const SizedBox(width: 5),
                  Text(
                    '${transfer.walkMinutes} min',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    transfer.stepFree
                        ? Icons.elevator_rounded
                        : Icons.stairs_rounded,
                    size: 14,
                    color: tone,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    transfer.stepFree ? 'Step free' : 'Steps likely',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformBox extends StatelessWidget {
  final String label;
  final String line;
  final PlatformInfo? platform;

  const _PlatformBox({
    required this.label,
    required this.line,
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            platform?.label ?? 'Platform',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitCard extends StatelessWidget {
  final ExitSuggestion suggestion;
  final List<StationExit> allExits;
  final String stationName;
  final bool hasLandmark;

  const _ExitCard({
    required this.suggestion,
    required this.allExits,
    required this.stationName,
    required this.hasLandmark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exit = suggestion.exit;
    final confident = suggestion.isConfident;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.exit_to_app_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Recommended exit',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    exit.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exit.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      confident
                          ? 'Closest exit for ${suggestion.matchedLandmark}, '
                              'about ${exit.walkMinutes} min on foot.'
                          : 'Shortest walk out of $stationName, about '
                              '${exit.walkMinutes} min on foot.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!confident && !hasLandmark) ...[
            const SizedBox(height: 10),
            Text(
              'Add a landmark on the search screen for a more precise exit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (exit.landmarks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final landmark in exit.landmarks)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(landmark, style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
          ],
          if (allExits.length > 1) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'OTHER EXITS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final other in allExits.where((e) => e.code != exit.code))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        other.code,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        other.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${other.walkMinutes} min',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
