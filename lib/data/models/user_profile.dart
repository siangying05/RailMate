enum PassengerType { adult, student, senior, oku, child }

extension PassengerTypeDisplay on PassengerType {
  String get label {
    switch (this) {
      case PassengerType.adult:
        return 'Adult';
      case PassengerType.student:
        return 'Student';
      case PassengerType.senior:
        return 'Senior Citizen';
      case PassengerType.oku:
        return 'OKU (Disabled)';
      case PassengerType.child:
        return 'Child';
    }
  }

  double get fareMultiplier {
    switch (this) {
      case PassengerType.adult:
        return 1.0;
      case PassengerType.student:
        return 0.5;
      case PassengerType.senior:
        return 0.5;
      case PassengerType.oku:
        return 0.5;
      case PassengerType.child:
        return 0.5;
    }
  }

  String get concessionNote {
    switch (this) {
      case PassengerType.adult:
        return 'Standard adult fare applies.';
      case PassengerType.student:
        return '50% concession with a valid student card.';
      case PassengerType.senior:
        return '50% concession for Malaysians aged 60 and above.';
      case PassengerType.oku:
        return '50% concession with a valid OKU card.';
      case PassengerType.child:
        return '50% concession for children aged 7 to 12.';
    }
  }

  bool get requiresProof => this != PassengerType.adult;

  static PassengerType parse(String? value) {
    return PassengerType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PassengerType.adult,
    );
  }
}

enum RoutePreference { fastest, leastTransfers, leastCrowded, paidAreaOnly }

extension RoutePreferenceDisplay on RoutePreference {
  String get label {
    switch (this) {
      case RoutePreference.fastest:
        return 'Fastest route';
      case RoutePreference.leastTransfers:
        return 'Least transfers';
      case RoutePreference.leastCrowded:
        return 'Avoid crowds';
      case RoutePreference.paidAreaOnly:
        return 'Paid area transfers only';
    }
  }

  String get description {
    switch (this) {
      case RoutePreference.fastest:
        return 'Shortest total travel time, even if it means more changes.';
      case RoutePreference.leastTransfers:
        return 'Fewest train changes, even if the trip takes longer.';
      case RoutePreference.leastCrowded:
        return 'Quieter trains based on open ridership data.';
      case RoutePreference.paidAreaOnly:
        return 'Never leave the gates to change trains.';
    }
  }

  String get icon {
    switch (this) {
      case RoutePreference.fastest:
        return 'bolt';
      case RoutePreference.leastTransfers:
        return 'swap';
      case RoutePreference.leastCrowded:
        return 'groups';
      case RoutePreference.paidAreaOnly:
        return 'gate';
    }
  }

  static RoutePreference parse(String? value) {
    return RoutePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => RoutePreference.fastest,
    );
  }
}

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final PassengerType passengerType;
  final RoutePreference preference;
  final String homeStationId;
  final bool arrivalAlerts;
  final bool avoidStairs;
  final double walkingSpeedKmh;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.passengerType,
    required this.preference,
    required this.homeStationId,
    required this.arrivalAlerts,
    required this.avoidStairs,
    required this.walkingSpeedKmh,
    required this.updatedAt,
  });

  factory UserProfile.guest() => UserProfile(
        id: 'guest',
        fullName: 'Guest',
        email: '',
        mobile: '',
        passengerType: PassengerType.adult,
        preference: RoutePreference.fastest,
        homeStationId: '',
        arrivalAlerts: true,
        avoidStairs: false,
        walkingSpeedKmh: 4.5,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory UserProfile.fromMap(Map<String, Object?> map) {
    return UserProfile(
      id: map['id'] as String? ?? 'guest',
      fullName: map['full_name'] as String? ?? 'Guest',
      email: map['email'] as String? ?? '',
      mobile: map['mobile'] as String? ?? '',
      passengerType:
          PassengerTypeDisplay.parse(map['passenger_type'] as String?),
      preference: RoutePreferenceDisplay.parse(map['preference'] as String?),
      homeStationId: map['home_station'] as String? ?? '',
      arrivalAlerts: (map['arrival_alerts'] as int? ?? 1) == 1,
      avoidStairs: (map['avoid_stairs'] as int? ?? 0) == 1,
      walkingSpeedKmh:
          (map['walking_speed'] as num?)?.toDouble() ?? 4.5,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'mobile': mobile,
        'passenger_type': passengerType.name,
        'preference': preference.name,
        'home_station': homeStationId,
        'arrival_alerts': arrivalAlerts ? 1 : 0,
        'avoid_stairs': avoidStairs ? 1 : 0,
        'walking_speed': walkingSpeedKmh,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  Map<String, dynamic> toRemoteJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'mobile': mobile,
        'passenger_type': passengerType.name,
        'preference': preference.name,
        'home_station': homeStationId,
        'arrival_alerts': arrivalAlerts,
        'avoid_stairs': avoidStairs,
        'walking_speed': walkingSpeedKmh,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory UserProfile.fromRemoteJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Guest',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      passengerType:
          PassengerTypeDisplay.parse(json['passenger_type'] as String?),
      preference: RoutePreferenceDisplay.parse(json['preference'] as String?),
      homeStationId: json['home_station'] as String? ?? '',
      arrivalAlerts: json['arrival_alerts'] as bool? ?? true,
      avoidStairs: json['avoid_stairs'] as bool? ?? false,
      walkingSpeedKmh: (json['walking_speed'] as num?)?.toDouble() ?? 4.5,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? mobile,
    PassengerType? passengerType,
    RoutePreference? preference,
    String? homeStationId,
    bool? arrivalAlerts,
    bool? avoidStairs,
    double? walkingSpeedKmh,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      passengerType: passengerType ?? this.passengerType,
      preference: preference ?? this.preference,
      homeStationId: homeStationId ?? this.homeStationId,
      arrivalAlerts: arrivalAlerts ?? this.arrivalAlerts,
      avoidStairs: avoidStairs ?? this.avoidStairs,
      walkingSpeedKmh: walkingSpeedKmh ?? this.walkingSpeedKmh,
      updatedAt: DateTime.now(),
    );
  }

  bool get isGuest => id == 'guest';

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'RM';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
