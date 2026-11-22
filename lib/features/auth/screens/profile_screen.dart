import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/user_profile.dart';
import '../../ticketing/providers/ticket_provider.dart';
import '../providers/auth_provider.dart';
import 'about_screen.dart';
import 'edit_profile_screen.dart';
import 'preferences_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final tickets = context.watch<TicketProvider>();
    final data = context.watch<RailDataProvider>();
    final profile = auth.profile;

    final homeStation = profile.homeStationId.isEmpty
        ? null
        : data.network.station(profile.homeStationId);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProfileHeader(
              initials: profile.initials,
              name: profile.fullName,
              email: profile.isGuest ? 'Guest session' : profile.email,
              badge: profile.passengerType.label,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.confirmation_number_rounded,
                    label: 'Tickets',
                    value: '${tickets.tickets.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.payments_rounded,
                    label: 'Total spend',
                    value: 'RM ${tickets.totalSpend.toStringAsFixed(2)}',
                    tone: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.home_rounded,
                    label: 'Home station',
                    value: homeStation?.name ?? 'Not set',
                    tone: AppColors.crowdModerate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            InfoBanner(
              icon: Icons.card_membership_rounded,
              message: profile.passengerType.concessionNote,
              colour: AppColors.accent,
            ),
            if (auth.unsyncedCount > 0) ...[
              const SizedBox(height: 10),
              InfoBanner(
                icon: Icons.cloud_upload_outlined,
                message: auth.abandonedSyncCount > 0
                    ? '${auth.unsyncedCount} change(s) have not reached your '
                        'RailMate account. ${auth.abandonedSyncCount} stopped '
                        'retrying on their own. Tap Sync to try again.'
                    : '${auth.pendingSyncCount} change(s) are waiting to sync '
                        'to your RailMate account.',
                colour: AppColors.crowdModerate,
                action: TextButton(
                  onPressed: () async {
                    final result = await context.read<AuthProvider>().syncNow();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.isClean
                              ? 'Everything is synced.'
                              : 'Pushed ${result.pushed}, '
                                  '${result.remaining} still waiting.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Sync'),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const SectionHeader(title: 'Account'),
            Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.tune_rounded,
                    title: 'Journey preferences',
                    subtitle: profile.preference.label,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PreferencesScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.edit_rounded,
                    title: 'Edit profile',
                    subtitle:
                        'Name, mobile, passenger type and home station',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                  ),
                  if (!profile.isGuest) ...[
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Change password',
                      subtitle: 'Set a new password for this account',
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                  ],
                  const Divider(height: 1),
                  _MenuTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About RailMate',
                    subtitle: 'Data sources, the team and SDG 9',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  if (!profile.isGuest) ...[
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete account',
                      subtitle: 'Permanently remove your RailMate profile',
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Data'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      data.isLiveData
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: data.isLiveData
                          ? AppColors.crowdLow
                          : AppColors.crowdModerate,
                    ),
                    title: Text(data.sourceLabel),
                    subtitle: Text(data.dataSummary),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Refresh open data',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () =>
                          context.read<RailDataProvider>().refreshOpenData(),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.hub_outlined),
                    title: const Text('Rail network'),
                    subtitle: Text(
                      '${data.network.totalStations} stations, '
                      '${data.network.totalLines} lines, '
                      '${data.network.totalInterchanges} interchanges',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.tonalIcon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(profile.isGuest ? 'End session' : 'Sign out'),
                    content: Text(
                      profile.isGuest
                          ? 'Your guest session will be cleared.'
                          : 'You will need to sign in again to buy tickets.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(profile.isGuest ? 'End' : 'Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await context.read<AuthProvider>().signOut();
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(profile.isGuest ? 'End guest session' : 'Sign out'),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${AppInfo.name} ${AppInfo.version}\n${AppInfo.course}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showChangePasswordDialog(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: Validators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
              validator: (value) =>
                  Validators.confirmPassword(value, passwordController.text),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(dialogContext).pop(true);
            }
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final success = await auth.changePassword(passwordController.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Password updated.'
                : auth.error ?? 'Could not update password.',
          ),
        ),
      );
    }
  }

  passwordController.dispose();
  confirmController.dispose();
}

Future<void> _showDeleteAccountDialog(BuildContext context) async {
  final auth = context.read<AuthProvider>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text(
        'This removes your RailMate profile, favourites and locally stored '
        'trip history from this account. Your ticket records already '
        "issued won't be recoverable afterwards. This can't be undone.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
            foregroundColor: Theme.of(dialogContext).colorScheme.onErrorContainer,
          ),
          child: const Text('Delete my account'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final success = await auth.deleteAccount();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Your RailMate profile has been deleted.'
              : auth.error ?? 'Could not delete your account.',
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String email;
  final String badge;

  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.email,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
