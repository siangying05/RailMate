import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_views.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthProvider>().verifyOtp(_code.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'Enter the code we sent to ${auth.pendingEmail}.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.error != null) ...[
              InfoBanner(
                icon: Icons.error_outline_rounded,
                message: auth.error!,
                colour: theme.colorScheme.error,
              ),
              const SizedBox(height: 18),
            ],
            if (auth.notice != null) ...[
              InfoBanner(
                icon: Icons.mark_email_read_outlined,
                message: auth.notice!,
                colour: AppColors.accent,
              ),
              const SizedBox(height: 18),
            ],
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: Validators.maxOtpLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
              ),
              decoration: const InputDecoration(
                counterText: '',
              ),
              validator: Validators.otp,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: auth.busy ? null : _submit,
              child: auth.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify and continue'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  auth.busy ? null : () => context.read<AuthProvider>().resendOtp(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Send a new code'),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => context.read<AuthProvider>().backToSignIn(),
              child: const Text('Use a different account'),
            ),
          ],
        ),
      ),
    );
  }
}
