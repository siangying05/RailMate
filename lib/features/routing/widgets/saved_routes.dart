import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/common_views.dart';
import '../../../data/models/favourite_route.dart';
import '../providers/favourite_provider.dart';

class SavedRoutes extends StatelessWidget {
  final void Function(FavouriteRoute route) onSelect;

  const SavedRoutes({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final favourites = context.watch<FavouriteProvider>();
    if (favourites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Saved routes',
          subtitle: 'Tap to plan it, hold to remove',
        ),
        for (final route in favourites.routes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SavedTile(
              route: route,
              onTap: () => onSelect(route),
              onRemove: () => _confirmRemove(context, route),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    FavouriteRoute route,
  ) async {
    final favourites = context.read<FavouriteProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved route'),
        content: Text('Remove ${route.summary} from your saved routes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await favourites.remove(route);
    messenger.showSnackBar(
      SnackBar(content: Text('Removed ${route.summary}.')),
    );
  }
}

class _SavedTile extends StatelessWidget {
  final FavouriteRoute route;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedTile({
    required this.route,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onRemove,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bookmark_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (route.landmark.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Near ${route.landmark}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
