class Station {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String operator;
  final bool accessible;
  final List<String> lineIds;

  const Station({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.operator,
    required this.accessible,
    required this.lineIds,
  });

  factory Station.fromJson(String id, Map<String, dynamic> json) {
    return Station(
      id: id,
      name: json['name'] as String? ?? id,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      operator: json['operator'] as String? ?? '',
      accessible: json['accessible'] as bool? ?? false,
      lineIds: (json['lines'] as List?)?.cast<String>() ?? const [],
    );
  }

  bool get isInterchange => lineIds.length > 1;

  String get searchKey => '$name $operator $id'.toLowerCase();

  @override
  bool operator ==(Object other) => other is Station && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Station($id, $name)';
}
