import 'package:sqflite/sqflite.dart';

import '../../core/config/supabase_config.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/supabase_service.dart';
import '../models/favourite_route.dart';
import 'sync_queue.dart';

class FavouriteRepository {
  final AppDatabase _db;
  final SupabaseService _remote;
  final SyncQueue _queue;

  FavouriteRepository({
    AppDatabase? database,
    SupabaseService? remote,
    SyncQueue? queue,
  })  : _db = database ?? AppDatabase.instance,
        _remote = remote ?? SupabaseService.instance,
        _queue = queue ?? SyncQueue();

  Future<List<FavouriteRoute>> all(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableFavourites,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(FavouriteRoute.fromMap).toList();
  }

  Future<FavouriteRoute?> add(FavouriteRoute route) async {
    final db = await _db.database;
    final id = await db.insert(
      AppDatabase.tableFavourites,
      route.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id == 0) return null;

    final rows = await db.query(
      AppDatabase.tableFavourites,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final saved = FavouriteRoute.fromMap(rows.first);
    await _push(saved, SyncOperation.upsert);
    return saved;
  }

  Future<void> update(FavouriteRoute route) async {
    if (route.id == null) return;
    final db = await _db.database;
    await db.update(
      AppDatabase.tableFavourites,
      route.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [route.id],
    );
    await _push(route, SyncOperation.upsert);
  }

  Future<void> remove(FavouriteRoute route) async {
    if (route.id == null) return;
    final db = await _db.database;
    await db.delete(
      AppDatabase.tableFavourites,
      where: 'id = ?',
      whereArgs: [route.id],
    );
    await _push(route, SyncOperation.delete);
  }

  Future<bool> exists(
    String userId,
    String originId,
    String destinationId,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableFavourites,
      where: 'user_id = ? AND origin_id = ? AND destination_id = ?',
      whereArgs: [userId, originId, destinationId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> count(String userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppDatabase.tableFavourites} WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> pullRemote(String userId) async {
    if (userId == 'guest' || !_remote.isAvailable) return 0;

    final List<Map<String, dynamic>> rows;
    try {
      rows = await _remote.select(
        SupabaseConfig.tableFavourites,
        filters: {'user_id': userId},
      );
    } on RemoteException {
      return 0;
    }
    if (rows.isEmpty) return 0;

    final db = await _db.database;
    var added = 0;

    for (final row in rows) {
      final route = FavouriteRoute.fromRemoteJson(row);
      if (await exists(userId, route.originId, route.destinationId)) continue;

      await db.insert(
        AppDatabase.tableFavourites,
        route.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      added++;
    }

    return added;
  }

  Future<void> _push(FavouriteRoute route, SyncOperation operation) async {
    if (route.userId == 'guest') return;

    final payload = operation == SyncOperation.delete
        ? {
            'user_id': route.userId,
            'origin_id': route.originId,
            'destination_id': route.destinationId,
          }
        : route.toRemoteJson();

    var pushed = false;
    try {
      if (_remote.isAvailable) {
        if (operation == SyncOperation.upsert) {
          await _remote.upsert(SupabaseConfig.tableFavourites, payload);
        } else {
          await _remote.deleteWhere(SupabaseConfig.tableFavourites, payload);
        }
        pushed = true;
      }
    } on RemoteException {
      pushed = false;
    }
    if (pushed) return;

    await _queue.enqueue(
      entity: SupabaseConfig.tableFavourites,
      entityId: '${route.originId}>${route.destinationId}',
      operation: operation,
      payload: payload,
    );
  }
}
