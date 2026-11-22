class Validators {
  const Validators._();

  static const int minPasswordLength = 8;
  static const int maxNameLength = 40;
  static const int maxLandmarkLength = 60;
  static const int minOtpLength = 6;
  static const int maxOtpLength = 10;

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
  );
  static final RegExp _name = RegExp(r"^[A-Za-z][A-Za-z '\-\.]*$");
  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _malaysianMobile = RegExp(r'^01\d{8,9}$');
  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasDigit = RegExp(r'\d');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (text.length > 254) return 'Email is too long';
    if (!_email.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    if (!_hasLetter.hasMatch(text)) return 'Include at least one letter';
    if (!_hasDigit.hasMatch(text)) return 'Include at least one number';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? fullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Name is required';
    if (text.length < 2) return 'Name is too short';
    if (text.length > maxNameLength) {
      return 'Keep the name under $maxNameLength characters';
    }
    if (!_name.hasMatch(text)) return 'Use letters, spaces and apostrophes only';
    return null;
  }

  static String? mobile(String? value, {bool required = false}) {
    final text = (value ?? '').replaceAll(RegExp(r'[\s\-]'), '');
    if (text.isEmpty) return required ? 'Mobile number is required' : null;
    if (!_digits.hasMatch(text)) return 'Digits only';
    if (!_malaysianMobile.hasMatch(text)) {
      return 'Enter a Malaysian number, e.g. 0123456789';
    }
    return null;
  }

  static String? otp(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the verification code';
    if (!_digits.hasMatch(text)) return 'The code is digits only';
    if (text.length < minOtpLength || text.length > maxOtpLength) {
      return 'The code is $minOtpLength to $maxOtpLength digits';
    }
    return null;
  }

  static String? landmark(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > maxLandmarkLength) {
      return 'Keep it under $maxLandmarkLength characters';
    }
    return null;
  }

  static String? label(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Give this a name';
    if (text.length > maxNameLength) {
      return 'Keep it under $maxNameLength characters';
    }
    return null;
  }

  static String? passengerCount(String? value, {int max = 6}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter how many passengers';
    if (!_digits.hasMatch(text)) return 'Digits only';
    final count = int.tryParse(text) ?? 0;
    if (count < 1) return 'At least one passenger';
    if (count > max) return 'Maximum $max passengers per booking';
    return null;
  }

  static String? journeyStations(String? originId, String? destinationId) {
    if (originId == null || originId.isEmpty) {
      return 'Choose a departure station';
    }
    if (destinationId == null || destinationId.isEmpty) {
      return 'Choose a destination station';
    }
    if (originId == destinationId) {
      return 'Departure and destination cannot be the same';
    }
    return null;
  }

  static String? departureTime(DateTime value, {int maxDaysAhead = 30}) {
    final now = DateTime.now();
    if (value.isBefore(now.subtract(const Duration(minutes: 5)))) {
      return 'Choose a time in the future';
    }
    if (value.isAfter(now.add(Duration(days: maxDaysAhead)))) {
      return 'Plan at most $maxDaysAhead days ahead';
    }
    return null;
  }

  static String? walkingSpeed(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter a walking speed';
    final speed = double.tryParse(text);
    if (speed == null) return 'Enter a number';
    if (speed < 2.0 || speed > 7.0) return 'Between 2.0 and 7.0 km/h';
    return null;
  }
}
