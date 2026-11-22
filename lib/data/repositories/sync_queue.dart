import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../datasources/local/app_database.dart';
import '../datasources/remote/supabase_service.dart';

enum SyncOperation { upsert, delete }

class PendingChange {
  final int id;
  final String entity;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final int attempts;

  const PendingChange({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.attempts,
  });
}

class SyncResult {
  final int pushed;
  final int remaining;
  final String? error;

  const SyncResult({
    required this.pushed,
    required this.remaining,
    this.error,
  });

  bool get isClean => remaining == 0 && error == null;
}

class SyncQueue {
  static const int maxAttempts = 5;

  final AppDatabase _db;
  final SupabaseService _remote;

  SyncQueue({AppDatabase? database, SupabaseService? remote})
      : _db = database ?? AppDatabase.instance,
        _remote = remote ?? SupabaseService.instance;

  Future<void> enqueue({
    required String entity,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db.database;
    await db.insert(AppDatabase.tableSyncQueue, {
      'entity': entity,
      'entity_id': entityId,
      'operation': operation.name,
      'payload': jsonEncode(payload),
      'queued_at': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
    });
  }

  Future<int> pendingCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppDatabase.tableSyncQueue} '
      'WHERE attempts < ?',
      [maxAttempts],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> abandonedCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppDatabase.tableSyncQueue} '
      'WHERE attempts >= ?',
      [maxAttempts],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> retryAbandoned() async {
    final db = await _db.database;
    await db.update(
      AppDatabase.tableSyncQueue,
      {'attempts': 0},
      where: 'attempts >= ?',
      whereArgs: [maxAttempts],
    );
  }

  Future<List<PendingChange>> pending({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableSyncQueue,
      where: 'attempts < ?',
      whereArgs: [maxAttempts],
      orderBy: 'queued_at ASC',
      limit: limit,
    );

    return rows.map((row) {
      final decoded = jsonDecode(row['payload'] as String);
      return PendingChange(
        id: row['id'] as int,
        entity: row['entity'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] == 'delete'
            ? SyncOperation.delete
            : SyncOperation.upsert,
        payload: decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
        attempts: row['attempts'] as int? ?? 0,
      );
    }).toList();
  }

  Future<SyncResult> drain() async {
    if (!_remote.isAvailable) {
      return SyncResult(
        pushed: 0,
        remaining: await pendingCount(),
        error: 'Offline',
      );
    }

    final db = await _db.database;
    final changes = await pending();
    var pushed = 0;
    String? lastError;

    for (final change in changes) {
      try {
        if (change.operation == SyncOperation.upsert) {
          await _remote.upsert(change.entity, change.payload);
        } else {
          await _remote.deleteWhere(change.entity, change.payload);
        }
        await db.delete(
          AppDatabase.tableSyncQueue,
          where: 'id = ?',
          whereArgs: [change.id],
        );
        pushed++;
      } on RemoteException catch (error) {
        lastError = error.message;
        await db.update(
          AppDatabase.tableSyncQueue,
          {'attempts': change.attempts + 1},
          where: 'id = ?',
          whereArgs: [change.id],
        );
      }
    }

    return SyncResult(
      pushed: pushed,
      remaining: await pendingCount(),
      error: lastError,
    );
  }

  Future<void> clear() async {
    final db = await _db.database;
    await db.delete(AppDatabase.tableSyncQueue);
  }
}
