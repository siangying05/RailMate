class RidershipRecord {
  final DateTime date;
  final Map<String, int> values;

  const RidershipRecord({required this.date, required this.values});

  factory RidershipRecord.fromJson(Map<String, dynamic> json) {
    final values = <String, int>{};
    json.forEach((key, value) {
      if (key == 'date') return;
      if (value is num) values[key] = value.round();
    });

    return RidershipRecord(
      date: DateTime.parse(json['date'] as String),
      values: values,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T').first,
        ...values,
      };

  int forKey(String key) => values[key] ?? 0;

  bool get isWeekend =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

class RidershipDataset {
  final List<RidershipRecord> records;
  final DateTime retrievedAt;

  RidershipDataset({required this.records, required this.retrievedAt});

  final Map<String, double> _averageCache = {};
  final Map<String, double> _weekdayCache = {};

  late final List<RidershipRecord> _newestFirst = [...records]
    ..sort((a, b) => b.date.compareTo(a.date));

  bool get isEmpty => records.isEmpty;

  int get dayCount => records.length;

  DateTime? get latestDate =>
      _newestFirst.isEmpty ? null : _newestFirst.first.date;

  double averageFor(String key, {int lastDays = 60}) {
    final cacheKey = '$key#$lastDays';
    final cached = _averageCache[cacheKey];
    if (cached != null) return cached;

    var total = 0;
    var count = 0;
    for (final record in _newestFirst.take(lastDays)) {
      final value = record.forKey(key);
      if (value <= 0) continue;
      total += value;
      count++;
    }

    final average = count == 0 ? 0.0 : total / count;
    _averageCache[cacheKey] = average;
    return average;
  }

  double weekdayFactorFor(String key, int weekday) {
    final cacheKey = '$key#$weekday';
    final cached = _weekdayCache[cacheKey];
    if (cached != null) return cached;

    var total = 0;
    var count = 0;
    for (final record in records) {
      if (record.date.weekday != weekday) continue;
      final value = record.forKey(key);
      if (value <= 0) continue;
      total += value;
      count++;
    }

    final overall = averageFor(key, lastDays: records.length);
    final factor =
        (count == 0 || overall <= 0) ? 1.0 : (total / count) / overall;

    _weekdayCache[cacheKey] = factor;
    return factor;
  }

  int latestFor(String key) {
    for (final record in _newestFirst) {
      final value = record.forKey(key);
      if (value > 0) return value;
    }
    return 0;
  }
}
