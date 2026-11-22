import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/data/models/fare.dart';
import 'package:railmate/data/models/ticket.dart';
import 'package:railmate/data/models/user_profile.dart';
import 'package:railmate/features/ticketing/services/payment_service.dart';
import 'package:railmate/features/ticketing/services/qr_pass_service.dart';

Ticket buildTicket(QrPassService service) {
  final now = DateTime(2026, 9, 3, 9, 0);
  return Ticket(
    id: 'ticket-1',
    reference: service.generateReference(),
    userId: 'user-1',
    originId: 'rr_KJ01',
    originName: 'Gombak',
    destinationId: 'rr_KJ15',
    destinationName: 'KL Sentral',
    departAt: now,
    issuedAt: now,
    expiresAt: now.add(const Duration(hours: 4)),
    passengers: 2,
    passengerType: PassengerType.student,
    fareCard: FareCard.touchNGo,
    paymentMethod: PaymentMethod.touchNGoEwallet,
    amount: 4.20,
    lineSummary: 'Kelana Jaya',
    travelMinutes: 32,
    status: TicketStatus.active,
    secret: service.generateSecret(),
  );
}

void main() {
  const service = QrPassService();

  final base = DateTime(2026, 9, 3, 9, 0);

  test('reference has the RailMate prefix and a readable code', () {
    final reference = service.generateReference();
    expect(reference, startsWith('RM-'));
    expect(reference.length, 9);
    expect(RegExp(r'^RM-[A-Z2-9]{6}$').hasMatch(reference), isTrue);
  });

  test('secrets are unique per ticket', () {
    final first = service.generateSecret();
    final second = service.generateSecret();
    expect(first, isNot(second));
    expect(first.length, greaterThan(20));
  });

  test('a freshly built pass verifies against its own ticket', () {
    final ticket = buildTicket(service);
    final pass = service.build(ticket, now: base);

    expect(pass.payload, startsWith(QrPassService.prefix));
    expect(pass.payload.split('|').length, 7);
    expect(service.verify(pass.payload, ticket, now: base), isTrue);
  });

  test('the payload changes when the rotation window changes', () {
    final ticket = buildTicket(service);
    final first = service.build(ticket, now: DateTime(2026, 9, 3, 9, 0, 0));
    final second = service.build(ticket, now: DateTime(2026, 9, 3, 9, 0, 45));

    expect(first.window, isNot(second.window));
    expect(first.payload, isNot(second.payload));
  });

  test('an old pass is rejected once the window has moved on', () {
    final ticket = buildTicket(service);
    final old = service.build(ticket, now: DateTime(2026, 9, 3, 9, 0, 0));

    expect(
      service.verify(old.payload, ticket, now: DateTime(2026, 9, 3, 9, 0, 20)),
      isTrue,
    );
    expect(
      service.verify(old.payload, ticket, now: DateTime(2026, 9, 3, 9, 5, 0)),
      isFalse,
    );
  });

  test('a tampered payload fails verification', () {
    final ticket = buildTicket(service);
    final pass = service.build(ticket, now: base);
    final parts = pass.payload.split('|');

    parts[4] = '99';
    expect(service.verify(parts.join('|'), ticket, now: base), isFalse);

    final wrongSignature = pass.payload.split('|')..last = 'DEADBEEFDEADBEEF';
    expect(service.verify(wrongSignature.join('|'), ticket, now: base), isFalse);
  });

  test('a pass from one ticket does not verify against another', () {
    final first = buildTicket(service);
    final second = buildTicket(service);
    final pass = service.build(first, now: base);

    expect(service.verify(pass.payload, second, now: base), isFalse);
  });

  test('a used or cancelled ticket is rejected even with a valid signature',
      () {
    final ticket = buildTicket(service);
    final pass = service.build(ticket, now: base);

    expect(service.verify(pass.payload, ticket, now: base), isTrue);

    for (final status in [
      TicketStatus.used,
      TicketStatus.cancelled,
      TicketStatus.expired,
    ]) {
      expect(
        service.verify(pass.payload, ticket.copyWith(status: status),
            now: base),
        isFalse,
        reason: 'a $status ticket must not open a gate',
      );
    }
  });

  test('a pass stops working once the ticket has expired', () {
    final ticket = buildTicket(service);
    final afterExpiry = ticket.expiresAt.add(const Duration(minutes: 1));
    final pass = service.build(ticket, now: afterExpiry);

    expect(service.verify(pass.payload, ticket, now: afterExpiry), isFalse);
  });

  group('simulated payment', () {
    final payments = PaymentService();

    test('runs through every stage and approves', () async {
      final stages = await payments
          .process(method: PaymentMethod.card, amount: 5)
          .toList();

      expect(stages.first, PaymentStage.authorising);
      expect(stages.last, PaymentStage.done);
      expect(stages.length, PaymentService.flow.length + 1);
    });

    test('can be forced to fail for the demonstration', () async {
      final stages = await payments
          .process(
            method: PaymentMethod.fpx,
            amount: 5,
            forceFailure: true,
          )
          .toList();

      expect(stages.last, PaymentStage.failed);

      final outcome = payments.settle(
        method: PaymentMethod.fpx,
        amount: 5,
        forceFailure: true,
      );
      expect(outcome.approved, isFalse);
      expect(outcome.transactionId, isEmpty);
    });

    test('approved payments carry a method specific transaction id', () {
      final tng = payments.settle(
        method: PaymentMethod.touchNGoEwallet,
        amount: 5,
      );
      final card = payments.settle(method: PaymentMethod.card, amount: 5);
      final fpx = payments.settle(method: PaymentMethod.fpx, amount: 5);

      expect(tng.transactionId, startsWith('TNG'));
      expect(card.transactionId, startsWith('CRD'));
      expect(fpx.transactionId, startsWith('FPX'));
      expect(tng.approved, isTrue);
    });
  });
}
