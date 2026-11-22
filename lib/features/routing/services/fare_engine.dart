import 'dart:math' as math;

import '../../../data/models/fare.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_line.dart';
import '../../../data/models/rail_network.dart';
import '../../../data/models/user_profile.dart';

class FareRule {
  final double base;
  final double perKm;
  final double minimum;
  final double maximum;

  const FareRule({
    required this.base,
    required this.perKm,
    required this.minimum,
    required this.maximum,
  });

  double compute(double km) {
    final raw = base + perKm * km;
    return raw.clamp(minimum, maximum);
  }
}

class FareEngine {
  static const Map<LineCategory, FareRule> rules = {
    LineCategory.urban: FareRule(
      base: 0.90,
      perKm: 0.135,
      minimum: 1.20,
      maximum: 6.30,
    ),
    LineCategory.commuter: FareRule(
      base: 0.80,
      perKm: 0.095,
      minimum: 1.00,
      maximum: 18.00,
    ),
    LineCategory.intercity: FareRule(
      base: 7.00,
      perKm: 0.155,
      minimum: 9.00,
      maximum: 165.00,
    ),
  };

  final RailNetwork network;

  const FareEngine({required this.network});

  FareBreakdown compute({
    required List<JourneyLeg> legs,
    required FareCard card,
    required PassengerType passengerType,
    int passengers = 1,
  }) {
    final segments = _segments(legs);
    if (segments.isEmpty) return FareBreakdown.empty;

    final components = <FareComponent>[];
    var baseTotal = 0.0;
    var ungroupedTotal = 0.0;

    for (final segment in segments) {
      final rule = rules[segment.category] ?? rules[LineCategory.urban]!;
      final amount = rule.compute(segment.km);
      baseTotal += amount;

      for (final leg in segment.legs) {
        final line = network.line(leg.lineId);
        if (line == null) continue;
        final share = segment.km <= 0 ? 1.0 : leg.km / segment.km;
        ungroupedTotal += rule.compute(leg.km);
        components.add(
          FareComponent(
            lineId: line.id,
            lineName: line.shortName,
            operator: line.operator,
            km: leg.km,
            stops: leg.stopCount,
            amount: double.parse((amount * share).toStringAsFixed(2)),
          ),
        );
      }
    }

    final discount = math.max(0.0, ungroupedTotal - baseTotal);
    final cardMultiplier = card.multiplier;
    final passengerMultiplier =
        card == FareCard.concession ? 1.0 : passengerType.fareMultiplier;

    final total = baseTotal * cardMultiplier * passengerMultiplier * passengers;

    return FareBreakdown(
      components: components,
      baseTotal: double.parse(baseTotal.toStringAsFixed(2)),
      interchangeDiscount: double.parse(discount.toStringAsFixed(2)),
      card: card,
      cardMultiplier: cardMultiplier,
      passengerMultiplier: passengerMultiplier,
      total: double.parse(total.toStringAsFixed(2)),
    );
  }

  List<_FareSegment> _segments(List<JourneyLeg> legs) {
    final segments = <_FareSegment>[];
    _FareSegment? current;
    var brokeOut = false;

    for (final leg in legs) {
      if (leg.kind == LegKind.walk) {
        brokeOut = true;
        continue;
      }
      if (leg.kind != LegKind.ride) continue;

      final line = network.line(leg.lineId);
      if (line == null) continue;

      final canExtend = current != null &&
          !brokeOut &&
          current.operator == line.operator &&
          current.category == line.category;

      if (canExtend) {
        current.legs.add(leg);
        current.km += leg.km;
      } else {
        current = _FareSegment(
          operator: line.operator,
          category: line.category,
          km: leg.km,
          legs: [leg],
        );
        segments.add(current);
      }
      brokeOut = false;
    }

    return segments;
  }

  double singleLineEstimate(RailLine line, double km) {
    final rule = rules[line.category] ?? rules[LineCategory.urban]!;
    return rule.compute(km);
  }
}

class _FareSegment {
  final String operator;
  final LineCategory category;
  double km;
  final List<JourneyLeg> legs;

  _FareSegment({
    required this.operator,
    required this.category,
    required this.km,
    required this.legs,
  });
}
