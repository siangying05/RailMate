import 'fare.dart';
import 'user_profile.dart';

enum PaymentMethod { touchNGoEwallet, card, fpx }

extension PaymentMethodDisplay on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.touchNGoEwallet:
        return "Touch 'n Go eWallet";
      case PaymentMethod.card:
        return 'Credit / Debit Card';
      case PaymentMethod.fpx:
        return 'FPX Online Banking';
    }
  }

  String get hint {
    switch (this) {
      case PaymentMethod.touchNGoEwallet:
        return 'Pay from your eWallet balance';
      case PaymentMethod.card:
        return 'Visa or Mastercard';
      case PaymentMethod.fpx:
        return 'Direct transfer from your bank';
    }
  }

  static PaymentMethod parse(String? value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => PaymentMethod.touchNGoEwallet,
    );
  }
}

enum TicketStatus { pending, active, used, expired, cancelled }

extension TicketStatusDisplay on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.pending:
        return 'Awaiting payment';
      case TicketStatus.active:
        return 'Ready to scan';
      case TicketStatus.used:
        return 'Completed';
      case TicketStatus.expired:
        return 'Expired';
      case TicketStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isScannable => this == TicketStatus.active;

  static TicketStatus parse(String? value) {
    return TicketStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TicketStatus.pending,
    );
  }
}

class Ticket {
  final String id;
  final String reference;
  final String userId;
  final String originId;
  final String originName;
  final String destinationId;
  final String destinationName;
  final DateTime departAt;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int passengers;
  final PassengerType passengerType;
  final FareCard fareCard;
  final PaymentMethod paymentMethod;
  final double amount;
  final String lineSummary;
  final int travelMinutes;
  final TicketStatus status;
  final String secret;

  const Ticket({
    required this.id,
    required this.reference,
    required this.userId,
    required this.originId,
    required this.originName,
    required this.destinationId,
    required this.destinationName,
    required this.departAt,
    required this.issuedAt,
    required this.expiresAt,
    required this.passengers,
    required this.passengerType,
    required this.fareCard,
    required this.paymentMethod,
    required this.amount,
    required this.lineSummary,
    required this.travelMinutes,
    required this.status,
    required this.secret,
  });

  factory Ticket.fromMap(Map<String, Object?> map) {
    return Ticket(
      id: map['id'] as String,
      reference: map['reference'] as String,
      userId: map['user_id'] as String? ?? 'guest',
      originId: map['origin_id'] as String,
      originName: map['origin_name'] as String,
      destinationId: map['destination_id'] as String,
      destinationName: map['destination_name'] as String,
      departAt: DateTime.fromMillisecondsSinceEpoch(map['depart_at'] as int),
      issuedAt: DateTime.fromMillisecondsSinceEpoch(map['issued_at'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      passengers: map['passengers'] as int? ?? 1,
      passengerType:
          PassengerTypeDisplay.parse(map['passenger_type'] as String?),
      fareCard: FareCardDisplay.parse(map['fare_card'] as String?),
      paymentMethod:
          PaymentMethodDisplay.parse(map['payment_method'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      lineSummary: map['line_summary'] as String? ?? '',
      travelMinutes: map['travel_minutes'] as int? ?? 0,
      status: TicketStatusDisplay.parse(map['status'] as String?),
      secret: map['secret'] as String? ?? '',
    );
  }

  factory Ticket.fromRemoteJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      reference: json['reference'] as String,
      userId: json['user_id'] as String? ?? 'guest',
      originId: json['origin_id'] as String,
      originName: json['origin_name'] as String,
      destinationId: json['destination_id'] as String,
      destinationName: json['destination_name'] as String,
      departAt: DateTime.parse(json['depart_at'] as String).toLocal(),
      issuedAt: DateTime.parse(json['issued_at'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      passengers: (json['passengers'] as num?)?.toInt() ?? 1,
      passengerType:
          PassengerTypeDisplay.parse(json['passenger_type'] as String?),
      fareCard: FareCardDisplay.parse(json['fare_card'] as String?),
      paymentMethod:
          PaymentMethodDisplay.parse(json['payment_method'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      lineSummary: json['line_summary'] as String? ?? '',
      travelMinutes: (json['travel_minutes'] as num?)?.toInt() ?? 0,
      status: TicketStatusDisplay.parse(json['status'] as String?),
      secret: '',
    );
  }

  bool get canShowPass => secret.isNotEmpty;

  Map<String, Object?> toMap() => {
        'id': id,
        'reference': reference,
        'user_id': userId,
        'origin_id': originId,
        'origin_name': originName,
        'destination_id': destinationId,
        'destination_name': destinationName,
        'depart_at': departAt.millisecondsSinceEpoch,
        'issued_at': issuedAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'passengers': passengers,
        'passenger_type': passengerType.name,
        'fare_card': fareCard.name,
        'payment_method': paymentMethod.name,
        'amount': amount,
        'line_summary': lineSummary,
        'travel_minutes': travelMinutes,
        'status': status.name,
        'secret': secret,
      };

  Map<String, dynamic> toRemoteJson() => {
        'id': id,
        'reference': reference,
        'user_id': userId,
        'origin_id': originId,
        'origin_name': originName,
        'destination_id': destinationId,
        'destination_name': destinationName,
        'depart_at': departAt.toIso8601String(),
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'passengers': passengers,
        'passenger_type': passengerType.name,
        'fare_card': fareCard.name,
        'payment_method': paymentMethod.name,
        'amount': amount,
        'line_summary': lineSummary,
        'travel_minutes': travelMinutes,
        'status': status.name,
      };

  Ticket copyWith({TicketStatus? status}) => Ticket(
        id: id,
        reference: reference,
        userId: userId,
        originId: originId,
        originName: originName,
        destinationId: destinationId,
        destinationName: destinationName,
        departAt: departAt,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        passengers: passengers,
        passengerType: passengerType,
        fareCard: fareCard,
        paymentMethod: paymentMethod,
        amount: amount,
        lineSummary: lineSummary,
        travelMinutes: travelMinutes,
        status: status ?? this.status,
        secret: secret,
      );

  bool isScannableAt(DateTime at) =>
      status == TicketStatus.active && expiresAt.isAfter(at);

  bool get isUpcoming => isScannableAt(DateTime.now());

  bool get isPast =>
      status == TicketStatus.used ||
      status == TicketStatus.expired ||
      (status == TicketStatus.active && expiresAt.isBefore(DateTime.now()));

  String get journeySummary => '$originName to $destinationName';

  String get formattedAmount => 'RM ${amount.toStringAsFixed(2)}';
}
