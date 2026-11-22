import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color brand = Color(0xFF0B4F9E);
  static const Color brandDark = Color(0xFF06305F);
  static const Color accent = Color(0xFF00B894);

  static const Color surfaceLight = Color(0xFFF5F7FB);
  static const Color cardLight = Colors.white;
  static const Color surfaceDark = Color(0xFF0E1116);
  static const Color cardDark = Color(0xFF171B22);

  static const Color textPrimary = Color(0xFF11161F);
  static const Color textSecondary = Color(0xFF5A6472);
  static const Color divider = Color(0xFFE2E7F0);

  static const Color crowdLow = Color(0xFF12A150);
  static const Color crowdModerate = Color(0xFFE8A100);
  static const Color crowdHigh = Color(0xFFD92D20);

  static const Color paidArea = Color(0xFF0B7285);
  static const Color walkLink = Color(0xFF9A6700);

  static Color parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final value = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(value, radix: 16) ?? 0xFF808080);
  }

  static Color onColour(Color background) {
    return background.computeLuminance() > 0.55 ? textPrimary : Colors.white;
  }
}
