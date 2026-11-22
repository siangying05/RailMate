import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/ticket_provider.dart';
import '../services/ticket_navigation.dart';
import 'ticket_screen.dart';

class MyTripsScreen extends StatelessWidget {
  final VoidCallback onPlanJourney;

  const MyTripsScreen({super.key, required this.onPlanJourney});

  @override
  Widget build(BuildContext context) {
    final tickets = context.watch<TicketProvider>();
    final auth = context.watch<AuthProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Trips'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: tickets.loading
              ? const LoadingView(message: 'Loading your trips')
              : TabBarView(
                  children: [
                    _TripList(
                      tickets: tickets.upcoming,
                      emptyTitle: 'No upcoming trips',
                      emptyMessage: auth.isGuest
                          ? 'Sign in to buy tickets and keep them here.'
                          : 'Plan a journey and book a ticket to see it here.',
                      onPlanJourney: onPlanJourney,
                    ),
                    _TripList(
                      tickets: tickets.past,
                      emptyTitle: 'No past trips yet',
                      emptyMessage:
                          'Completed and expired tickets appear here with '
                          'their receipts.',
                      onPlanJourney: onPlanJourney,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  final List<Ticket> tickets;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onPlanJourney;

  const _TripList({
    required this.tickets,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onPlanJourney,
  });

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: emptyTitle,
        message: emptyMessage,
        action: FilledButton(
          onPressed: onPlanJourney,
          child: const Text('Plan a journey'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _TicketCard(ticket: tickets[index]),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scannable = ticket.status.isScannable;
    final tone = scannable ? AppColors.crowdLow : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TicketScreen(ticket: ticket)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.journeySummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ticket.status.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: tone,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    TimeUtils.formatDateTime(ticket.departAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  ticket.formattedAmount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillChip(
                  icon: Icons.tag_rounded,
                  label: ticket.reference,
                  tone: theme.colorScheme.primary,
                ),
                PillChip(
                  icon: Icons.people_rounded,
                  label: '${ticket.passengers} × '
                      '${ticket.passengerType.label}',
                  tone: AppColors.accent,
                ),
                if (ticket.lineSummary.isNotEmpty)
                  PillChip(
                    icon: Icons.route_rounded,
                    label: ticket.lineSummary,
                    tone: AppColors.crowdModerate,
                  ),
              ],
            ),
            if (scannable) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => openNavigationForTicket(context, ticket),
                  icon: const Icon(Icons.navigation_rounded, size: 16),
                  label: const Text('Resume navigation'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
