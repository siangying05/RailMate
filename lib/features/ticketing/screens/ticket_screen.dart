import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/ticket_provider.dart';
import '../services/qr_pass_service.dart';
import '../services/ticket_navigation.dart';

class TicketScreen extends StatefulWidget {
  final Ticket ticket;

  const TicketScreen({super.key, required this.ticket});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late QrPass _pass;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pass = const QrPassService().build(widget.ticket);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _pass = const QrPassService().build(widget.ticket);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticket = widget.ticket;
    final scannable = ticket.status.isScannable && ticket.canShowPass;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your ticket'),
        actions: [
          IconButton(
            tooltip: 'Receipt',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => _showReceipt(context, ticket),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.journeySummary,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              TimeUtils.formatDateTime(ticket.departAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (scannable
                                  ? AppColors.crowdLow
                                  : theme.colorScheme.onSurfaceVariant)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          ticket.status.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scannable
                                ? AppColors.crowdLow
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (scannable) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: _pass.payload,
                        version: QrVersions.auto,
                        size: 220,
                        gapless: true,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            value: _pass.secondsRemaining /
                                QrPassService.rotationSeconds,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Code refreshes in ${_pass.secondsRemaining}s',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ticket.canShowPass
                                ? 'This pass is no longer scannable.'
                                : 'This trip was bought on another device, so '
                                    'the pass cannot be shown here. Open it on '
                                    'that device to scan at the gate.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Reference', value: ticket.reference),
                  _DetailRow(
                    label: 'Passengers',
                    value: '${ticket.passengers} × '
                        '${ticket.passengerType.label}',
                  ),
                  _DetailRow(label: 'Fare card', value: ticket.fareCard.label),
                  _DetailRow(
                    label: 'Route',
                    value: ticket.lineSummary.isEmpty
                        ? 'Direct'
                        : ticket.lineSummary,
                  ),
                  _DetailRow(
                    label: 'Valid until',
                    value: TimeUtils.formatDateTime(ticket.expiresAt),
                  ),
                  _DetailRow(
                    label: 'Amount paid',
                    value: ticket.formattedAmount,
                    emphasise: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const InfoBanner(
              icon: Icons.qr_code_scanner_rounded,
              message:
                  'Show this dynamic QR pass at the gate. The code is signed '
                  'and rotates every 30 seconds so a screenshot cannot be '
                  'reused.',
            ),
            const SizedBox(height: 18),
            if (scannable) ...[
              FilledButton.icon(
                onPressed: () => openNavigationForTicket(context, ticket),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Start navigation'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final userId = context.read<AuthProvider>().profile.id;
                  await context
                      .read<TicketProvider>()
                      .markUsed(ticket, userId);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Mark journey as completed'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReceipt(BuildContext context, Ticket ticket) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digital receipt',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'RailMate simulated transaction',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _DetailRow(label: 'Reference', value: ticket.reference),
              _DetailRow(label: 'Issued', value: TimeUtils.formatDateTime(ticket.issuedAt)),
              _DetailRow(label: 'Journey', value: ticket.journeySummary),
              _DetailRow(
                label: 'Depart',
                value: TimeUtils.formatDateTime(ticket.departAt),
              ),
              _DetailRow(
                label: 'Passengers',
                value: '${ticket.passengers} × ${ticket.passengerType.label}',
              ),
              _DetailRow(
                label: 'Payment method',
                value: ticket.paymentMethod.label,
              ),
              _DetailRow(
                label: 'Total',
                value: ticket.formattedAmount,
                emphasise: true,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;

  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (emphasise
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodySmall)
                  ?.copyWith(
                fontWeight: emphasise ? FontWeight.w900 : FontWeight.w600,
                color: emphasise ? theme.colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
