import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/user_profile.dart';
import '../providers/ticket_provider.dart';
import 'payment_screen.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tickets = context.watch<TicketProvider>();
    final draft = tickets.draft;

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book ticket')),
        body: const EmptyState(
          icon: Icons.confirmation_number_outlined,
          title: 'No journey selected',
          message: 'Plan a journey first, then book a ticket for it.',
        ),
      );
    }

    final fare = draft.option.fare;

    return Scaffold(
      appBar: AppBar(title: const Text('Review and pay')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.summary,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${TimeUtils.formatDateTime(draft.option.departAt)}  ·  '
                      '${TimeUtils.formatDuration(draft.option.totalMinutes)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PillChip(
                          icon: Icons.route_rounded,
                          label: draft.lineSummary.isEmpty
                              ? 'Direct'
                              : draft.lineSummary,
                          tone: theme.colorScheme.primary,
                        ),
                        PillChip(
                          icon: Icons.people_rounded,
                          label: '${draft.passengers} passenger'
                              '${draft.passengers > 1 ? "s" : ""}',
                          tone: AppColors.accent,
                        ),
                        PillChip(
                          icon: Icons.badge_rounded,
                          label: draft.passengerType.label,
                          tone: AppColors.crowdModerate,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Fare breakdown',
              subtitle: 'Distance based fares with integrated interchange',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final component in fare.components)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    component.lineName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${component.km.toStringAsFixed(1)} km  ·  '
                                    '${component.stops} stops',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'RM ${component.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 20),
                    if (fare.hasDiscount) ...[
                      _FareRow(
                        label: 'Each leg priced separately',
                        value:
                            'RM ${fare.separateLegsTotal.toStringAsFixed(2)}',
                      ),
                      _FareRow(
                        label: 'Integrated interchange saving',
                        value:
                            '- RM ${fare.interchangeDiscount.toStringAsFixed(2)}',
                        tone: AppColors.crowdLow,
                      ),
                    ],
                    _FareRow(
                      label: 'Base fare',
                      value: 'RM ${fare.baseTotal.toStringAsFixed(2)}',
                    ),
                    _FareRow(
                      label: '${fare.card.label} rate',
                      value: '× ${fare.cardMultiplier.toStringAsFixed(2)}',
                    ),
                    if (fare.passengerMultiplier != 1.0)
                      _FareRow(
                        label: '${draft.passengerType.label} concession',
                        value:
                            '× ${fare.passengerMultiplier.toStringAsFixed(2)}',
                        tone: AppColors.accent,
                      ),
                    if (draft.passengers > 1)
                      _FareRow(
                        label: 'Passengers',
                        value: '× ${draft.passengers}',
                      ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          fare.formatted,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Payment method'),
            Card(
              child: RadioGroup<PaymentMethod>(
                groupValue: tickets.method,
                onChanged: (value) {
                  if (value != null) {
                    context.read<TicketProvider>().setMethod(value);
                  }
                },
                child: Column(
                  children: [
                    for (var i = 0; i < PaymentMethod.values.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      RadioListTile<PaymentMethod>(
                        value: PaymentMethod.values[i],
                        title: Text(
                          PaymentMethod.values[i].label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(PaymentMethod.values[i].hint),
                        secondary: Icon(_iconFor(PaymentMethod.values[i])),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.shield_outlined,
              message: tickets.paymentService.describe(tickets.method),
              colour: AppColors.crowdModerate,
            ),
            const SizedBox(height: 10),
            const InfoBanner(
              icon: Icons.info_outline_rounded,
              message: AppInfo.paymentDisclaimer,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaymentScreen()),
              ),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text('Pay ${fare.formatted}'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                context.read<TicketProvider>().cancelBooking();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.touchNGoEwallet:
        return Icons.account_balance_wallet_rounded;
      case PaymentMethod.card:
        return Icons.credit_card_rounded;
      case PaymentMethod.fpx:
        return Icons.account_balance_rounded;
    }
  }
}

class _FareRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? tone;

  const _FareRow({required this.label, required this.value, this.tone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}
