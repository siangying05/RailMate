import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/user_profile.dart';
import '../providers/auth_provider.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _speedController = TextEditingController();
  String? _speedError;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _speedController.text = profile.walkingSpeedKmh.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _speedController.dispose();
    super.dispose();
  }

  IconData _iconFor(RoutePreference preference) {
    switch (preference) {
      case RoutePreference.fastest:
        return Icons.bolt_rounded;
      case RoutePreference.leastTransfers:
        return Icons.swap_calls_rounded;
      case RoutePreference.leastCrowded:
        return Icons.groups_rounded;
      case RoutePreference.paidAreaOnly:
        return Icons.door_sliding_rounded;
    }
  }

  Future<void> _saveSpeed() async {
    final error = Validators.walkingSpeed(_speedController.text);
    setState(() => _speedError = error);
    if (error != null) return;

    final auth = context.read<AuthProvider>();
    await auth.updateProfile(
      auth.profile.copyWith(
        walkingSpeedKmh: double.parse(_speedController.text.trim()),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Walking speed updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Journey preferences')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const InfoBanner(
              icon: Icons.tune_rounded,
              message:
                  'RailMate turns this preference into the ranking rule for '
                  'every route search you run.',
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Preferred route type',
              subtitle: 'Applied automatically to every search',
            ),
            Card(
              child: RadioGroup<RoutePreference>(
                groupValue: profile.preference,
                onChanged: (value) {
                  if (value != null) {
                    context.read<AuthProvider>().setPreference(value);
                  }
                },
                child: Column(
                  children: [
                  for (var i = 0; i < RoutePreference.values.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    RadioListTile<RoutePreference>(
                      value: RoutePreference.values[i],
                      title: Text(
                        RoutePreference.values[i].label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(RoutePreference.values[i].description),
                      secondary: Icon(_iconFor(RoutePreference.values[i])),
                    ),
                  ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Accessibility and alerts'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: profile.arrivalAlerts,
                    onChanged: (value) => context
                        .read<AuthProvider>()
                        .updateProfile(
                          profile.copyWith(arrivalAlerts: value),
                        ),
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Arrival alerts'),
                    subtitle: const Text(
                      'Notify me when my interchange or destination is near',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: profile.avoidStairs,
                    onChanged: (value) => context
                        .read<AuthProvider>()
                        .updateProfile(profile.copyWith(avoidStairs: value)),
                    secondary: const Icon(Icons.elevator_outlined),
                    title: const Text('Prefer step free routes'),
                    subtitle: const Text(
                      'Favour lifts and level access when changing trains',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(
              title: 'Walking speed',
              subtitle: 'Used to estimate transfer and exit walking times',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _speedController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'km/h',
                          errorText: _speedError,
                          helperText: 'Between 2.0 and 7.0',
                          prefixIcon: const Icon(Icons.directions_walk_rounded),
                        ),
                        onChanged: (_) {
                          if (_speedError != null) {
                            setState(() => _speedError = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FilledButton(
                        onPressed: _saveSpeed,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(88, 56),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            InfoBanner(
              icon: Icons.info_outline_rounded,
              message: profile.passengerType.concessionNote,
              colour: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}
