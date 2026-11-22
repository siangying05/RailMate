import 'package:sqflite/sqflite.dart';

import '../../core/config/supabase_config.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/supabase_service.dart';
import '../models/ticket.dart';
import 'sync_queue.dart';

class TicketRepository {
  final AppDatabase _db;
  final SupabaseService _remote;
  final SyncQueue _queue;

  TicketRepository({
    AppDatabase? database,
    SupabaseService? remote,
    SyncQueue? queue,
  })  : _db = database ?? AppDatabase.instance,
        _remote = remote ?? SupabaseService.instance,
        _queue = queue ?? SyncQueue();

  Future<List<Ticket>> all(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableTickets,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'depart_at DESC',
    );
    return rows.map(Ticket.fromMap).toList();
  }

  Future<Ticket?> byId(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableTickets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Ticket.fromMap(rows.first);
  }

  Future<Ticket?> byReference(String reference) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableTickets,
      where: 'reference = ?',
      whereArgs: [reference],
      limit: 1,
    );
    return rows.isEmpty ? null : Ticket.fromMap(rows.first);
  }

  Future<void> save(Ticket ticket) async {
    final db = await _db.database;
    await db.insert(
      AppDatabase.tableTickets,
      ticket.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _push(ticket);
  }

  Future<Ticket> updateStatus(Ticket ticket, TicketStatus status) async {
    final updated = ticket.copyWith(status: status);
    await save(updated);
    return updated;
  }

  Future<int> expirePastTickets(String userId) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    const where = 'user_id = ? AND status = ? AND expires_at < ?';
    final args = [userId, TicketStatus.active.name, now];

    final stale = await db.query(
      AppDatabase.tableTickets,
      where: where,
      whereArgs: args,
    );
    if (stale.isEmpty) return 0;

    final changed = await db.update(
      AppDatabase.tableTickets,
      {'status': TicketStatus.expired.name},
      where: where,
      whereArgs: args,
    );

    for (final row in stale) {
      await _push(Ticket.fromMap(row).copyWith(status: TicketStatus.expired));
    }

    return changed;
  }

  Future<double> totalSpend(String userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT SUM(amount) AS total FROM ${AppDatabase.tableTickets}
      WHERE user_id = ? AND status <> ?
      ''',
      [userId, TicketStatus.cancelled.name],
    );
    final value = rows.first['total'];
    return value is num ? value.toDouble() : 0;
  }

  Future<int> count(String userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppDatabase.tableTickets} WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> pullRemote(String userId) async {
    if (userId == 'guest' || !_remote.isAvailable) return 0;

    final List<Map<String, dynamic>> rows;
    try {
      rows = await _remote.select(
        SupabaseConfig.tableTickets,
        filters: {'user_id': userId},
      );
    } on RemoteException {
      return 0;
    }
    if (rows.isEmpty) return 0;

    final db = await _db.database;
    var added = 0;

    for (final row in rows) {
      final ticket = Ticket.fromRemoteJson(row);
      final existing = await db.query(
        AppDatabase.tableTickets,
        columns: const ['id'],
        where: 'id = ?',
        whereArgs: [ticket.id],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;

      await db.insert(
        AppDatabase.tableTickets,
        ticket.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      added++;
    }

    return added;
  }

  Future<void> _push(Ticket ticket) async {
    if (ticket.userId == 'guest') return;

    var pushed = false;
    try {
      if (_remote.isAvailable) {
        await _remote.upsert(SupabaseConfig.tableTickets, ticket.toRemoteJson());
        pushed = true;
      }
    } on RemoteException {
      pushed = false;
    }
    if (pushed) return;

    await _queue.enqueue(
      entity: SupabaseConfig.tableTickets,
      entityId: ticket.id,
      operation: SyncOperation.upsert,
      payload: ticket.toRemoteJson(),
    );
  }
}
