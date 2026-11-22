import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/rail_data_provider.dart';
import '../core/widgets/common_views.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import 'root_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<RailDataProvider>();
    final auth = context.watch<AuthProvider>();

    if (data.status == LoadStatus.failed) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'RailMate could not start',
            message: data.error ?? 'The rail network data could not be loaded.',
            action: FilledButton(
              onPressed: () => context.read<RailDataProvider>().initialise(),
              child: const Text('Try again'),
            ),
          ),
        ),
      );
    }

    if (!data.isReady || auth.stage == AuthStage.checking) {
      return const Scaffold(
        body: LoadingView(message: 'Loading the Malaysian rail network'),
      );
    }

    switch (auth.stage) {
      case AuthStage.signedIn:
        return const RootShell();
      case AuthStage.awaitingOtp:
        return const OtpScreen();
      case AuthStage.signedOut:
      case AuthStage.checking:
        return const SignInScreen();
    }
  }
}
