enum FareCard { touchNGo, cashToken, concession }

extension FareCardDisplay on FareCard {
  String get label {
    switch (this) {
      case FareCard.touchNGo:
        return "Touch 'n Go";
      case FareCard.cashToken:
        return 'Cash / Token';
      case FareCard.concession:
        return 'Concession Card';
    }
  }

  String get description {
    switch (this) {
      case FareCard.touchNGo:
        return 'Stored value card, the cheapest everyday option.';
      case FareCard.cashToken:
        return 'Single journey token bought at the station.';
      case FareCard.concession:
        return 'Student, senior citizen or OKU concession card.';
    }
  }

  double get multiplier {
    switch (this) {
      case FareCard.touchNGo:
        return 1.0;
      case FareCard.cashToken:
        return 1.25;
      case FareCard.concession:
        return 0.5;
    }
  }

  static FareCard parse(String? value) {
    return FareCard.values.firstWhere(
      (card) => card.name == value,
      orElse: () => FareCard.touchNGo,
    );
  }
}

class FareComponent {
  final String lineId;
  final String lineName;
  final String operator;
  final double km;
  final int stops;
  final double amount;

  const FareComponent({
    required this.lineId,
    required this.lineName,
    required this.operator,
    required this.km,
    required this.stops,
    required this.amount,
  });
}

class FareBreakdown {
  final List<FareComponent> components;
  final double baseTotal;
  final double interchangeDiscount;
  final FareCard card;
  final double cardMultiplier;
  final double passengerMultiplier;
  final double total;

  const FareBreakdown({
    required this.components,
    required this.baseTotal,
    required this.interchangeDiscount,
    required this.card,
    required this.cardMultiplier,
    required this.passengerMultiplier,
    required this.total,
  });

  static const FareBreakdown empty = FareBreakdown(
    components: [],
    baseTotal: 0,
    interchangeDiscount: 0,
    card: FareCard.touchNGo,
    cardMultiplier: 1,
    passengerMultiplier: 1,
    total: 0,
  );

  double get totalKm =>
      components.fold<double>(0, (sum, item) => sum + item.km);

  double get separateLegsTotal => baseTotal + interchangeDiscount;

  String get formatted => 'RM ${total.toStringAsFixed(2)}';

  bool get hasDiscount => interchangeDiscount > 0.005;
}
