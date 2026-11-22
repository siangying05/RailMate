import 'package:flutter/material.dart';

import '../../../data/models/crowd.dart';
import '../../../data/models/guidance.dart';

class CarriageStrip extends StatelessWidget {
  final CarriageAdvice advice;

  const CarriageStrip({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loads = advice.loads.isEmpty
        ? List<CarriageLoad>.generate(
            advice.totalCarriages,
            (index) => CarriageLoad(
              carriage: index + 1,
              level: CrowdLevel.moderate,
              recommended: advice.recommended.contains(index + 1),
              reason: '',
            ),
          )
        : advice.loads;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  advice.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: advice.confidence == AdviceConfidence.verified
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                advice.confidence.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: advice.confidence == AdviceConfidence.verified
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  for (final load in loads) ...[
                    Expanded(
                      child: _Carriage(load: load),
                    ),
                    if (load.carriage != loads.last.carriage)
                      const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          advice.reason,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _Carriage extends StatelessWidget {
  final CarriageLoad load;

  const _Carriage({required this.load});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = load.level.colour;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: load.recommended ? 0.28 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: load.recommended
              ? colour
              : colour.withValues(alpha: 0.3),
          width: load.recommended ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${load.carriage}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: colour,
            ),
          ),
          if (load.recommended)
            Icon(Icons.check_rounded, size: 12, color: colour),
        ],
      ),
    );
  }
}
