import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../datasources/local/app_database.dart';
import '../datasources/local/asset_data_source.dart';
import '../datasources/remote/open_data_api.dart';
import '../models/ridership.dart';

enum RidershipSource { live, cache, bundled }

extension RidershipSourceDisplay on RidershipSource {
  String get label {
    switch (this) {
      case RidershipSource.live:
        return 'Live from data.gov.my';
      case RidershipSource.cache:
        return 'Saved open data on this device';
      case RidershipSource.bundled:
        return 'Bundled open data snapshot';
    }
  }

  bool get isLive => this == RidershipSource.live;
}

class RidershipResult {
  final RidershipDataset dataset;
  final RidershipSource source;
  final String? warning;

  const RidershipResult({
    required this.dataset,
    required this.source,
    this.warning,
  });
}

class RidershipRepository {
  static const Duration freshFor = Duration(hours: 6);

  final OpenDataApi _api;
  final AssetDataSource _assets;
  final AppDatabase _db;

  RidershipRepository({
    OpenDataApi? api,
    AssetDataSource? assets,
    AppDatabase? database,
  })  : _api = api ?? OpenDataApi(),
        _assets = assets ?? const AssetDataSource(),
        _db = database ?? AppDatabase.instance;

  RidershipResult? _memory;

  Future<RidershipResult> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _memory != null) return _memory!;

    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) < freshFor) {
        return _memory = RidershipResult(
          dataset: RidershipDataset(
            records: cached.records,
            retrievedAt: cached.cachedAt,
          ),
          source: RidershipSource.cache,
        );
      }
    }

    try {
      final records = await _api.fetchRidership();
      if (records.isNotEmpty) {
        await _writeCache(records);
        return _memory = RidershipResult(
          dataset: RidershipDataset(
            records: records,
            retrievedAt: DateTime.now(),
          ),
          source: RidershipSource.live,
        );
      }
    } on OpenDataException catch (error) {
      return _memory = await _fallback(error.message);
    }

    return _memory =
        await _fallback('The open data portal returned no records.');
  }

  Future<RidershipResult> _fallback(String warning) async {
    final cached = await _readCache();
    if (cached != null && cached.records.isNotEmpty) {
      return RidershipResult(
        dataset: RidershipDataset(
          records: cached.records,
          retrievedAt: cached.cachedAt,
        ),
        source: RidershipSource.cache,
        warning: warning,
      );
    }

    final bundled = await _assets.loadRidershipSnapshot();
    return RidershipResult(
      dataset: RidershipDataset(
        records: bundled,
        retrievedAt: DateTime.now(),
      ),
      source: RidershipSource.bundled,
      warning: warning,
    );
  }

  Future<_CachedRidership?> _readCache() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        AppDatabase.tableRidershipCache,
        orderBy: 'date DESC',
      );
      if (rows.isEmpty) return null;

      final records = <RidershipRecord>[];
      var latest = 0;
      for (final row in rows) {
        final payload = jsonDecode(row['payload'] as String);
        if (payload is Map<String, dynamic>) {
          records.add(RidershipRecord.fromJson(payload));
        }
        final cachedAt = row['cached_at'] as int? ?? 0;
        if (cachedAt > latest) latest = cachedAt;
      }

      return _CachedRidership(
        records: records,
        cachedAt: DateTime.fromMillisecondsSinceEpoch(latest),
      );
    } on DatabaseException {
      return null;
    }
  }

  Future<void> _writeCache(List<RidershipRecord> records) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      batch.delete(AppDatabase.tableRidershipCache);
      for (final record in records) {
        batch.insert(
          AppDatabase.tableRidershipCache,
          {
            'date': record.date.toIso8601String().split('T').first,
            'payload': jsonEncode(record.toJson()),
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } on DatabaseException {
      return;
    }
  }
}

class _CachedRidership {
  final List<RidershipRecord> records;
  final DateTime cachedAt;

  const _CachedRidership({required this.records, required this.cachedAt});
}
