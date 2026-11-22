import 'package:sqflite/sqflite.dart';

import '../datasources/local/app_database.dart';

class SearchHistoryEntry {
  final int? id;
  final String userId;
  final String originId;
  final String originName;
  final String destinationId;
  final String destinationName;
  final DateTime searchedAt;

  const SearchHistoryEntry({
    this.id,
    required this.userId,
    required this.originId,
    required this.originName,
    required this.destinationId,
    required this.destinationName,
    required this.searchedAt,
  });

  factory SearchHistoryEntry.fromMap(Map<String, Object?> map) {
    return SearchHistoryEntry(
      id: map['id'] as int?,
      userId: map['user_id'] as String? ?? 'guest',
      originId: map['origin_id'] as String,
      originName: map['origin_name'] as String,
      destinationId: map['destination_id'] as String,
      destinationName: map['destination_name'] as String,
      searchedAt: DateTime.fromMillisecondsSinceEpoch(
        map['searched_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'origin_id': originId,
        'origin_name': originName,
        'destination_id': destinationId,
        'destination_name': destinationName,
        'searched_at': searchedAt.millisecondsSinceEpoch,
      };

  String get pairKey => '$originId>$destinationId';
}

class HistoryRepository {
  static const int retained = 20;

  final AppDatabase _db;

  HistoryRepository({AppDatabase? database})
      : _db = database ?? AppDatabase.instance;

  Future<List<SearchHistoryEntry>> recent(String userId, {int limit = 6}) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableHistory,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'searched_at DESC',
      limit: limit,
    );
    return rows.map(SearchHistoryEntry.fromMap).toList();
  }

  Future<void> record(SearchHistoryEntry entry) async {
    final db = await _db.database;
    await db.delete(
      AppDatabase.tableHistory,
      where: 'user_id = ? AND origin_id = ? AND destination_id = ?',
      whereArgs: [entry.userId, entry.originId, entry.destinationId],
    );
    await db.insert(AppDatabase.tableHistory, entry.toMap()..remove('id'));
    await _trim(entry.userId);
  }

  Future<void> clear(String userId) async {
    final db = await _db.database;
    await db.delete(
      AppDatabase.tableHistory,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> count(String userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppDatabase.tableHistory} WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> _trim(String userId) async {
    final db = await _db.database;
    await db.rawDelete(
      '''
      DELETE FROM ${AppDatabase.tableHistory}
      WHERE user_id = ?
        AND id NOT IN (
          SELECT id FROM ${AppDatabase.tableHistory}
          WHERE user_id = ?
          ORDER BY searched_at DESC
          LIMIT $retained
        )
      ''',
      [userId, userId],
    );
  }
}
