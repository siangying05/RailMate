import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'auth_gate.dart';

class RailMateApp extends StatelessWidget {
  const RailMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RailMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
