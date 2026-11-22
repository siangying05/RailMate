import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/common_views.dart';
import '../../../data/repositories/history_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/journey_provider.dart';

class RecentSearches extends StatelessWidget {
  final void Function(SearchHistoryEntry entry) onSelect;

  const RecentSearches({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final journey = context.watch<JourneyProvider>();
    if (journey.recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent searches',
          subtitle: 'Tap to plan the same journey again',
          trailing: TextButton(
            onPressed: () {
              final userId = context.read<AuthProvider>().profile.id;
              context.read<JourneyProvider>().clearRecent(userId);
            },
            child: const Text('Clear'),
          ),
        ),
        for (final entry in journey.recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentTile(entry: entry, onTap: () => onSelect(entry)),
          ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final SearchHistoryEntry entry;
  final VoidCallback onTap;

  const _RecentTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${entry.originName}  to  ${entry.destinationName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.north_east_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
