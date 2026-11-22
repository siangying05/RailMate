import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/core/utils/validators.dart';

void main() {
  group('email', () {
    test('accepts a normal address', () {
      expect(Validators.email('chunyuan@example.com'), isNull);
    });

    test('rejects blank, malformed and oversized addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('no-at-sign'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a@@b.com'), isNotNull);
      expect(Validators.email('${'a' * 250}@example.com'), isNotNull);
    });
  });

  group('password', () {
    test('accepts a letter and number combination of the right length', () {
      expect(Validators.password('railmate1'), isNull);
    });

    test('rejects short, letterless and numberless passwords', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('rail1'), isNotNull);
      expect(Validators.password('railmatepass'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
    });

    test('confirmation must match', () {
      expect(Validators.confirmPassword('railmate1', 'railmate1'), isNull);
      expect(Validators.confirmPassword('railmate2', 'railmate1'), isNotNull);
      expect(Validators.confirmPassword('', 'railmate1'), isNotNull);
    });
  });

  group('full name', () {
    test('accepts letters, spaces and apostrophes', () {
      expect(Validators.fullName('Ooi Chun Yuan'), isNull);
      expect(Validators.fullName("D'Cruz"), isNull);
    });

    test('rejects digits, symbols and empty values', () {
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.fullName('A'), isNotNull);
      expect(Validators.fullName('Chun Yuan 123'), isNotNull);
      expect(Validators.fullName('a' * 50), isNotNull);
    });
  });

  group('mobile', () {
    test('accepts Malaysian numbers with or without separators', () {
      expect(Validators.mobile('0123456789'), isNull);
      expect(Validators.mobile('012-345 6789'), isNull);
      expect(Validators.mobile('01123456789'), isNull);
    });

    test('is optional unless required', () {
      expect(Validators.mobile(''), isNull);
      expect(Validators.mobile('', required: true), isNotNull);
    });

    test('rejects non Malaysian formats', () {
      expect(Validators.mobile('123456'), isNotNull);
      expect(Validators.mobile('0312345678'), isNotNull);
      expect(Validators.mobile('01abcd6789'), isNotNull);
    });
  });

  group('otp', () {
    test('accepts every length Supabase can be configured to send', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp('01823189'), isNull);
      expect(Validators.otp('1234567890'), isNull);
    });

    test('rejects wrong length or non digits', () {
      expect(Validators.otp(''), isNotNull);
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('12345678901'), isNotNull);
      expect(Validators.otp('12345a'), isNotNull);
    });
  });

  group('journey stations', () {
    test('requires both stations and rejects duplicates', () {
      expect(Validators.journeyStations(null, 'b'), isNotNull);
      expect(Validators.journeyStations('a', null), isNotNull);
      expect(Validators.journeyStations('a', 'a'), isNotNull);
      expect(Validators.journeyStations('a', 'b'), isNull);
    });
  });

  group('departure time', () {
    test('accepts a time in the near future', () {
      final soon = DateTime.now().add(const Duration(hours: 2));
      expect(Validators.departureTime(soon), isNull);
    });

    test('rejects the past and dates too far ahead', () {
      final past = DateTime.now().subtract(const Duration(hours: 2));
      final far = DateTime.now().add(const Duration(days: 60));
      expect(Validators.departureTime(past), isNotNull);
      expect(Validators.departureTime(far), isNotNull);
    });
  });

  group('passenger count', () {
    test('accepts one to six', () {
      expect(Validators.passengerCount('1'), isNull);
      expect(Validators.passengerCount('6'), isNull);
    });

    test('rejects zero, too many and non numeric input', () {
      expect(Validators.passengerCount('0'), isNotNull);
      expect(Validators.passengerCount('7'), isNotNull);
      expect(Validators.passengerCount('two'), isNotNull);
      expect(Validators.passengerCount(''), isNotNull);
    });
  });

  group('walking speed', () {
    test('accepts a realistic speed', () {
      expect(Validators.walkingSpeed('4.5'), isNull);
    });

    test('rejects out of range values', () {
      expect(Validators.walkingSpeed('1.0'), isNotNull);
      expect(Validators.walkingSpeed('9'), isNotNull);
      expect(Validators.walkingSpeed('fast'), isNotNull);
    });
  });

  group('landmark', () {
    test('is optional but length limited', () {
      expect(Validators.landmark(''), isNull);
      expect(Validators.landmark('Pavilion'), isNull);
      expect(Validators.landmark('a' * 80), isNotNull);
    });
  });
}
