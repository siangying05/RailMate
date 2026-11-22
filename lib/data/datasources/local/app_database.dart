import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static String fileName = 'railmate.db';
  static const int schemaVersion = 2;

  static const String tableProfiles = 'profiles';
  static const String tableFavourites = 'favourites';
  static const String tableHistory = 'search_history';
  static const String tableTickets = 'tickets';
  static const String tableRidershipCache = 'ridership_cache';
  static const String tableSyncQueue = 'sync_queue';

  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getDatabasesPath();
    final path = p.join(directory, fileName);

    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _rebuildSchema,
      onDowngrade: _rebuildSchema,
    );
  }

  Future<void> _rebuildSchema(Database db, int from, int to) async {
    const tables = [
      tableProfiles,
      tableFavourites,
      tableHistory,
      tableTickets,
      tableRidershipCache,
      tableSyncQueue,
    ];

    for (final table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }

    await _createSchema(db, to);
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableProfiles (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        mobile TEXT NOT NULL DEFAULT '',
        passenger_type TEXT NOT NULL DEFAULT 'adult',
        preference TEXT NOT NULL DEFAULT 'fastest',
        home_station TEXT NOT NULL DEFAULT '',
        arrival_alerts INTEGER NOT NULL DEFAULT 1,
        avoid_stairs INTEGER NOT NULL DEFAULT 0,
        walking_speed REAL NOT NULL DEFAULT 4.5,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFavourites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        label TEXT NOT NULL,
        origin_id TEXT NOT NULL,
        origin_name TEXT NOT NULL,
        destination_id TEXT NOT NULL,
        destination_name TEXT NOT NULL,
        landmark TEXT NOT NULL DEFAULT '',
        preferred_departure INTEGER NOT NULL DEFAULT 480,
        created_at INTEGER NOT NULL,
        UNIQUE (user_id, origin_id, destination_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        origin_id TEXT NOT NULL,
        origin_name TEXT NOT NULL,
        destination_id TEXT NOT NULL,
        destination_name TEXT NOT NULL,
        searched_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_history_time ON $tableHistory (user_id, searched_at DESC)',
    );

    await db.execute('''
      CREATE TABLE $tableTickets (
        id TEXT PRIMARY KEY,
        reference TEXT NOT NULL UNIQUE,
        user_id TEXT NOT NULL,
        origin_id TEXT NOT NULL,
        origin_name TEXT NOT NULL,
        destination_id TEXT NOT NULL,
        destination_name TEXT NOT NULL,
        depart_at INTEGER NOT NULL,
        issued_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        passengers INTEGER NOT NULL DEFAULT 1,
        passenger_type TEXT NOT NULL,
        fare_card TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        amount REAL NOT NULL,
        line_summary TEXT NOT NULL DEFAULT '',
        travel_minutes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        secret TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_tickets_user ON $tableTickets (user_id, depart_at DESC)',
    );

    await db.execute('''
      CREATE TABLE $tableRidershipCache (
        date TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSyncQueue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        queued_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
