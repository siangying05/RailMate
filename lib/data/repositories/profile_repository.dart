import 'package:sqflite/sqflite.dart';

import '../../core/config/supabase_config.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/supabase_service.dart';
import '../models/user_profile.dart';
import 'sync_queue.dart';

class ProfileRepository {
  final AppDatabase _db;
  final SupabaseService _remote;
  final SyncQueue _queue;

  ProfileRepository({
    AppDatabase? database,
    SupabaseService? remote,
    SyncQueue? queue,
  })  : _db = database ?? AppDatabase.instance,
        _remote = remote ?? SupabaseService.instance,
        _queue = queue ?? SyncQueue();

  Future<UserProfile?> readLocal(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableProfiles,
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveLocal(UserProfile profile) async {
    final db = await _db.database;
    await db.insert(
      AppDatabase.tableProfiles,
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserProfile> save(UserProfile profile) async {
    await saveLocal(profile);

    if (profile.isGuest) return profile;

    try {
      if (_remote.isAvailable) {
        await _remote.upsert(
          SupabaseConfig.tableProfiles,
          profile.toRemoteJson(),
        );
      } else {
        await _queue.enqueue(
          entity: SupabaseConfig.tableProfiles,
          entityId: profile.id,
          operation: SyncOperation.upsert,
          payload: profile.toRemoteJson(),
        );
      }
    } on RemoteException {
      await _queue.enqueue(
        entity: SupabaseConfig.tableProfiles,
        entityId: profile.id,
        operation: SyncOperation.upsert,
        payload: profile.toRemoteJson(),
      );
    }

    return profile;
  }

  Future<UserProfile> pullRemote(String userId) async {
    final rows = await _remote.select(
      SupabaseConfig.tableProfiles,
      filters: {'id': userId},
    );
    if (rows.isEmpty) {
      throw const RemoteException('No profile found for this account.');
    }
    final profile = UserProfile.fromRemoteJson(rows.first);
    await saveLocal(profile);
    return profile;
  }

  Future<UserProfile> resolve({
    required String userId,
    required String email,
    required String fullName,
  }) async {
    final local = await readLocal(userId);
    if (local != null) return local;

    if (_remote.isAvailable) {
      UserProfile? remote;
      try {
        remote = await pullRemote(userId);
      } on RemoteException {
        remote = null;
      }
      if (remote != null) return remote;
    }

    final created = UserProfile(
      id: userId,
      fullName: fullName,
      email: email,
      mobile: '',
      passengerType: PassengerType.adult,
      preference: RoutePreference.fastest,
      homeStationId: '',
      arrivalAlerts: true,
      avoidStairs: false,
      walkingSpeedKmh: 4.5,
      updatedAt: DateTime.now(),
    );
    await save(created);
    return created;
  }

  Future<void> deleteLocal(String userId) async {
    final db = await _db.database;
    await db.delete(
      AppDatabase.tableProfiles,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
