import 'package:flutter/material.dart';

import '../../data/models/rail_line.dart';
import '../theme/app_colors.dart';

class LineBadge extends StatelessWidget {
  final RailLine line;
  final bool compact;
  final bool showName;

  const LineBadge({
    super.key,
    required this.line,
    this.compact = false,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    final colour = line.colour;
    final foreground = AppColors.onColour(colour);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        line.code,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10 : 11,
          letterSpacing: 0.4,
        ),
      ),
    );

    if (!showName) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            line.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class LineStripe extends StatelessWidget {
  final List<RailLine> lines;
  final double height;

  const LineStripe({super.key, required this.lines, this.height = 5});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines)
              Expanded(child: ColoredBox(color: line.colour)),
          ],
        ),
      ),
    );
  }
}
