import 'dart:math';

import '../../../data/models/ticket.dart';

enum PaymentStage { idle, authorising, processing, confirming, done, failed }

extension PaymentStageDisplay on PaymentStage {
  String get label {
    switch (this) {
      case PaymentStage.idle:
        return 'Ready';
      case PaymentStage.authorising:
        return 'Authorising with your provider';
      case PaymentStage.processing:
        return 'Processing payment';
      case PaymentStage.confirming:
        return 'Confirming with RailMate';
      case PaymentStage.done:
        return 'Payment approved';
      case PaymentStage.failed:
        return 'Payment declined';
    }
  }
}

class PaymentOutcome {
  final bool approved;
  final String transactionId;
  final String message;
  final DateTime at;

  const PaymentOutcome({
    required this.approved,
    required this.transactionId,
    required this.message,
    required this.at,
  });
}

class PaymentService {
  static const List<PaymentStage> flow = [
    PaymentStage.authorising,
    PaymentStage.processing,
    PaymentStage.confirming,
  ];

  static const Duration stageDelay = Duration(milliseconds: 850);

  final Random _random;

  PaymentService({Random? random}) : _random = random ?? Random();

  String describe(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.touchNGoEwallet:
        return 'RailMate will open a simulated eWallet authorisation screen. '
            'No real balance is deducted.';
      case PaymentMethod.card:
        return 'A simulated card authorisation runs locally. RailMate never '
            'asks for or stores a real card number.';
      case PaymentMethod.fpx:
        return 'A simulated FPX bank redirect runs locally. No bank login is '
            'requested.';
    }
  }

  Stream<PaymentStage> process({
    required PaymentMethod method,
    required double amount,
    bool forceFailure = false,
  }) async* {
    for (final stage in flow) {
      yield stage;
      await Future<void>.delayed(stageDelay);
    }

    if (forceFailure) {
      yield PaymentStage.failed;
      return;
    }

    yield PaymentStage.done;
  }

  PaymentOutcome settle({
    required PaymentMethod method,
    required double amount,
    bool forceFailure = false,
  }) {
    if (forceFailure) {
      return PaymentOutcome(
        approved: false,
        transactionId: '',
        message: 'The simulated provider declined this payment.',
        at: DateTime.now(),
      );
    }

    return PaymentOutcome(
      approved: true,
      transactionId: _transactionId(method),
      message: 'Simulated payment of RM ${amount.toStringAsFixed(2)} approved.',
      at: DateTime.now(),
    );
  }

  String _transactionId(PaymentMethod method) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    final code = List.generate(
      10,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();

    switch (method) {
      case PaymentMethod.touchNGoEwallet:
        return 'TNG$code';
      case PaymentMethod.card:
        return 'CRD$code';
      case PaymentMethod.fpx:
        return 'FPX$code';
    }
  }
}
