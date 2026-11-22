class FavouriteRoute {
  final int? id;
  final String userId;
  final String label;
  final String originId;
  final String originName;
  final String destinationId;
  final String destinationName;
  final String landmark;
  final int preferredDepartureMinutes;
  final DateTime createdAt;

  const FavouriteRoute({
    this.id,
    required this.userId,
    required this.label,
    required this.originId,
    required this.originName,
    required this.destinationId,
    required this.destinationName,
    required this.landmark,
    required this.preferredDepartureMinutes,
    required this.createdAt,
  });

  factory FavouriteRoute.fromMap(Map<String, Object?> map) {
    return FavouriteRoute(
      id: map['id'] as int?,
      userId: map['user_id'] as String? ?? 'guest',
      label: map['label'] as String,
      originId: map['origin_id'] as String,
      originName: map['origin_name'] as String,
      destinationId: map['destination_id'] as String,
      destinationName: map['destination_name'] as String,
      landmark: map['landmark'] as String? ?? '',
      preferredDepartureMinutes: map['preferred_departure'] as int? ?? 480,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
    );
  }

  factory FavouriteRoute.fromRemoteJson(Map<String, dynamic> json) {
    return FavouriteRoute(
      userId: json['user_id'] as String? ?? 'guest',
      label: json['label'] as String? ?? 'Saved route',
      originId: json['origin_id'] as String,
      originName: json['origin_name'] as String,
      destinationId: json['destination_id'] as String,
      destinationName: json['destination_name'] as String,
      landmark: json['landmark'] as String? ?? '',
      preferredDepartureMinutes:
          (json['preferred_departure'] as num?)?.toInt() ?? 480,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'label': label,
        'origin_id': originId,
        'origin_name': originName,
        'destination_id': destinationId,
        'destination_name': destinationName,
        'landmark': landmark,
        'preferred_departure': preferredDepartureMinutes,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Map<String, dynamic> toRemoteJson() => {
        'user_id': userId,
        'label': label,
        'origin_id': originId,
        'origin_name': originName,
        'destination_id': destinationId,
        'destination_name': destinationName,
        'landmark': landmark,
        'preferred_departure': preferredDepartureMinutes,
        'created_at': createdAt.toIso8601String(),
      };

  FavouriteRoute copyWith({
    String? label,
    String? landmark,
    int? preferredDepartureMinutes,
  }) {
    return FavouriteRoute(
      id: id,
      userId: userId,
      label: label ?? this.label,
      originId: originId,
      originName: originName,
      destinationId: destinationId,
      destinationName: destinationName,
      landmark: landmark ?? this.landmark,
      preferredDepartureMinutes:
          preferredDepartureMinutes ?? this.preferredDepartureMinutes,
      createdAt: createdAt,
    );
  }

  String get summary => '$originName to $destinationName';
}
