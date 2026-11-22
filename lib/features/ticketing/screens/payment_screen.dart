import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../services/payment_service.dart';
import 'ticket_screen.dart';

/// Malaysian online banks offered on the FPX step. This is a fixed list for
/// the simulation - there's no real bank redirect, so the choice only
/// affects what's shown on the receipt afterwards.
const List<String> _fpxBanks = [
  'Maybank2u',
  'CIMB Clicks',
  'Public Bank (PBe)',
  'RHB Now',
  'Hong Leong Connect',
  'Bank Islam GO',
  'Bank Rakyat',
  'AmOnline',
  'BSN',
  'UOB Malaysia',
];

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _fpxUsernameController = TextEditingController();
  String? _fpxBank;

  bool _started = false;
  bool _simulateDecline = false;

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _fpxUsernameController.dispose();
    super.dispose();
  }

  /// Card and FPX collect and validate a form first - the details are never
  /// checked against a real bank, only checked for a plausible format, per
  /// [AppInfo.paymentDisclaimer]. Touch 'n Go has nothing to type (the rider
  /// "scans" a QR and taps "Mark as completed"), so it skips straight to
  /// [_pay].
  Future<void> _submit(PaymentMethod method) async {
    if (method != PaymentMethod.touchNGoEwallet) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }
    await _pay();
  }

  Future<void> _pay() async {
    setState(() => _started = true);

    final userId = context.read<AuthProvider>().profile.id;
    final ticket = await context.read<TicketProvider>().payAndIssue(
          userId: userId,
          forceFailure: _simulateDecline,
        );

    if (!mounted) return;

    if (ticket != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TicketScreen(ticket: ticket)),
        (route) => route.isFirst,
      );
    } else {
      setState(() => _started = false);
    }
  }

  String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(' ', '');
    if (digits.isEmpty) return 'Card number is required';
    if (!RegExp(r'^[0-9]{13,19}$').hasMatch(digits)) {
      return 'Enter a 13 to 19 digit card number';
    }
    return null;
  }

  String? _validateCardExpiry(String? value) {
    final text = value ?? '';
    final match = RegExp(r'^(0[1-9]|1[0-2])/([0-9]{2})$').firstMatch(text);
    if (match == null) return 'Use MM/YY';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final firstInvalid = DateTime(year, month + 1);
    final now = DateTime.now();
    if (firstInvalid.isBefore(DateTime(now.year, now.month))) {
      return 'This card has expired';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    final text = value ?? '';
    if (!RegExp(r'^[0-9]{3,4}$').hasMatch(text)) return '3 or 4 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tickets = context.watch<TicketProvider>();
    final draft = tickets.draft;

    if (draft == null && tickets.lastIssued == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Nothing to pay for',
          message: 'Start a booking from a route first.',
        ),
      );
    }

    final method = tickets.method;
    final showForm = !_started;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        automaticallyImplyLeading: !tickets.isProcessing,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brand, AppColors.brandDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount due',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'RM ${(draft?.amount ?? 0).toStringAsFixed(2)}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${draft?.summary ?? ''}  ·  ${method.label}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (showForm) ...[
                const SizedBox(height: 22),
                const SectionHeader(
                  title: 'Payment details',
                  subtitle: 'This is a simulation - nothing here is checked '
                      'against a real bank or wallet',
                ),
                if (method == PaymentMethod.card) _CardForm(
                  nameController: _cardNameController,
                  numberController: _cardNumberController,
                  expiryController: _cardExpiryController,
                  cvvController: _cardCvvController,
                  validateNumber: _validateCardNumber,
                  validateExpiry: _validateCardExpiry,
                  validateCvv: _validateCvv,
                ),
                if (method == PaymentMethod.fpx) _FpxForm(
                  bank: _fpxBank,
                  onBankChanged: (value) => setState(() => _fpxBank = value),
                  usernameController: _fpxUsernameController,
                ),
                if (method == PaymentMethod.touchNGoEwallet)
                  _TouchNGoSection(
                    amount: draft?.amount ?? 0,
                    reference: draft?.summary ?? '',
                    isProcessing: tickets.isProcessing,
                    onMarkCompleted: () => _submit(method),
                  ),
              ],
              const SizedBox(height: 22),
              const SectionHeader(title: 'Progress'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final stage in PaymentService.flow)
                        _StageRow(
                          stage: stage,
                          current: tickets.stage,
                          done: _isDone(stage, tickets.stage),
                        ),
                      _StageRow(
                        stage: PaymentStage.done,
                        current: tickets.stage,
                        done: tickets.stage == PaymentStage.done,
                      ),
                    ],
                  ),
                ),
              ),
              if (tickets.error != null) ...[
                const SizedBox(height: 16),
                InfoBanner(
                  icon: Icons.error_outline_rounded,
                  message: tickets.error!,
                  colour: theme.colorScheme.error,
                ),
              ],
              const SizedBox(height: 20),
              if (showForm)
                SwitchListTile(
                  value: _simulateDecline,
                  onChanged: (value) =>
                      setState(() => _simulateDecline = value),
                  title: const Text('Simulate a declined payment'),
                  subtitle: const Text(
                    'Useful for demonstrating the failure path',
                  ),
                  secondary: const Icon(Icons.science_outlined),
                ),
              const SizedBox(height: 10),
              if (method != PaymentMethod.touchNGoEwallet || !showForm)
                FilledButton.icon(
                  onPressed:
                      tickets.isProcessing ? null : () => _submit(method),
                  icon: tickets.isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    tickets.isProcessing
                        ? tickets.stage.label
                        : (tickets.error != null
                            ? 'Try again'
                            : 'Confirm payment'),
                  ),
                ),
              const SizedBox(height: 12),
              const InfoBanner(
                icon: Icons.verified_user_outlined,
                message: AppInfo.paymentDisclaimer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDone(PaymentStage stage, PaymentStage current) {
    if (current == PaymentStage.done) return true;
    final order = PaymentService.flow;
    final stageIndex = order.indexOf(stage);
    final currentIndex = order.indexOf(current);
    if (stageIndex < 0 || currentIndex < 0) return false;
    return currentIndex > stageIndex;
  }
}

class _CardForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController numberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final String? Function(String?) validateNumber;
  final String? Function(String?) validateExpiry;
  final String? Function(String?) validateCvv;

  const _CardForm({
    required this.nameController,
    required this.numberController,
    required this.expiryController,
    required this.cvvController,
    required this.validateNumber,
    required this.validateExpiry,
    required this.validateCvv,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name on card'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Enter the name on the card'
                      : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: numberController,
              keyboardType: TextInputType.number,
              maxLength: 19,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Card number',
                counterText: '',
              ),
              validator: validateNumber,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: expiryController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    inputFormatters: [_ExpiryDateFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'MM/YY',
                      counterText: '',
                    ),
                    validator: validateExpiry,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      counterText: '',
                    ),
                    validator: validateCvv,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'This is a demo - the card is never checked against a real '
              'bank. Any number that passes the format check above will '
              'work.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FpxForm extends StatelessWidget {
  final String? bank;
  final ValueChanged<String?> onBankChanged;
  final TextEditingController usernameController;

  const _FpxForm({
    required this.bank,
    required this.onBankChanged,
    required this.usernameController,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: bank,
              decoration: const InputDecoration(labelText: 'Choose your bank'),
              items: [
                for (final name in _fpxBanks)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onBankChanged,
              validator: (value) => value == null ? 'Choose a bank' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: usernameController,
              decoration:
                  const InputDecoration(labelText: 'Online banking username'),
              validator: (value) => (value == null || value.trim().length < 4)
                  ? 'Enter at least 4 characters'
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              "This is a demo - you won't be redirected to a real bank "
              'login, and no real banking credentials are checked.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TouchNGoSection extends StatelessWidget {
  final double amount;
  final String reference;
  final bool isProcessing;
  final VoidCallback onMarkCompleted;

  const _TouchNGoSection({
    required this.amount,
    required this.reference,
    required this.isProcessing,
    required this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Scan with the Touch 'n Go eWallet app",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: 'TNG-PAY-DEMO|RM${amount.toStringAsFixed(2)}|$reference',
                version: QrVersions.auto,
                size: 180,
                gapless: true,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'RM ${amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This is a demo QR - there is no real eWallet connection. Tap '
              'below once you have "paid" to continue.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isProcessing ? null : onMarkCompleted,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Mark as completed'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Auto-inserts the "/" in a card expiry field as the rider types, e.g.
/// "1225" becomes "12/25" without them having to type the separator.
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits =
        newValue.text.replaceAll(RegExp(r'[^0-9]'), '').substring(
              0,
              newValue.text.replaceAll(RegExp(r'[^0-9]'), '').length > 4
                  ? 4
                  : null,
            );
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 && digits.length > 2) buffer.write('/');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _StageRow extends StatelessWidget {
  final PaymentStage stage;
  final PaymentStage current;
  final bool done;

  const _StageRow({
    required this.stage,
    required this.current,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = stage == current;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: done
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.crowdLow,
                    size: 22,
                  )
                : active
                    ? const CircularProgressIndicator(strokeWidth: 2.4)
                    : Icon(
                        Icons.circle_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stage.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: active || done ? FontWeight.w700 : FontWeight.w500,
                color: active || done
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
