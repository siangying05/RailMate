import 'package:flutter/material.dart';

import '../../data/models/crowd.dart';

class CrowdChip extends StatelessWidget {
  final CrowdForecast forecast;
  final bool compact;
  final bool showPercent;

  const CrowdChip({
    super.key,
    required this.forecast,
    this.compact = false,
    this.showPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colour = forecast.level.colour;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 8 : 9,
            height: compact ? 8 : 9,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              showPercent
                  ? '${forecast.level.label} ${forecast.percent}%'
                  : forecast.level.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colour,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CrowdBar extends StatelessWidget {
  final CrowdForecast forecast;
  final double height;

  const CrowdBar({super.key, required this.forecast, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final colour = forecast.level.colour;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: forecast.score.clamp(0.05, 1.0),
        minHeight: height,
        backgroundColor: colour.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation<Color>(colour),
      ),
    );
  }
}
