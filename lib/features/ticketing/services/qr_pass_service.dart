import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../data/models/ticket.dart';

class QrPass {
  final String payload;
  final int window;
  final DateTime generatedAt;
  final Duration validFor;

  const QrPass({
    required this.payload,
    required this.window,
    required this.generatedAt,
    required this.validFor,
  });

  int get secondsRemaining {
    final elapsed = DateTime.now().difference(generatedAt).inSeconds;
    final left = validFor.inSeconds - elapsed;
    return left < 0 ? 0 : left;
  }
}

class QrPassService {
  static const String prefix = 'RAILMATE2';
  static const int rotationSeconds = 30;
  static const int signatureLength = 16;

  const QrPassService();

  String generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String generateReference() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'RM-$code';
  }

  int windowFor(DateTime at) =>
      at.millisecondsSinceEpoch ~/ (rotationSeconds * 1000);

  String sign({required String body, required String secret}) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(body));
    return digest.toString().substring(0, signatureLength).toUpperCase();
  }

  String bodyFor(Ticket ticket, int window) => [
        ticket.reference,
        ticket.originId,
        ticket.destinationId,
        '${ticket.passengers}',
        '$window',
      ].join('|');

  QrPass build(Ticket ticket, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final window = windowFor(at);
    final body = bodyFor(ticket, window);
    final signature = sign(body: body, secret: ticket.secret);

    final payload = '$prefix|$body|$signature';

    final elapsedInWindow = at.millisecondsSinceEpoch % (rotationSeconds * 1000);
    final remaining = (rotationSeconds * 1000) - elapsedInWindow;

    return QrPass(
      payload: payload,
      window: window,
      generatedAt: at,
      validFor: Duration(milliseconds: remaining),
    );
  }

  bool verify(String payload, Ticket ticket, {DateTime? now}) {
    final at = now ?? DateTime.now();

    if (!ticket.isScannableAt(at)) return false;

    final parts = payload.split('|');
    if (parts.length != 7) return false;
    if (parts[0] != prefix) return false;

    final window = int.tryParse(parts[5]);
    if (window == null) return false;

    final current = windowFor(at);
    if ((current - window).abs() > 1) return false;

    final body = parts.sublist(1, 6).join('|');
    final expected = sign(body: body, secret: ticket.secret);
    if (parts[6] != expected) return false;

    return body == bodyFor(ticket, window);
  }
}
