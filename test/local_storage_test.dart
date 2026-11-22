import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/data/datasources/local/app_database.dart';
import 'package:railmate/data/models/favourite_route.dart';
import 'package:railmate/data/models/fare.dart';
import 'package:railmate/data/models/ticket.dart';
import 'package:railmate/data/models/user_profile.dart';
import 'package:railmate/data/repositories/favourite_repository.dart';
import 'package:railmate/data/repositories/history_repository.dart';
import 'package:railmate/data/repositories/profile_repository.dart';
import 'package:railmate/data/repositories/sync_queue.dart';
import 'package:railmate/data/repositories/ticket_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String userId = 'user-under-test';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FavouriteRepository favourites;
  late HistoryRepository history;
  late ProfileRepository profiles;
  late TicketRepository tickets;
  late SyncQueue queue;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.fileName = 'railmate_storage_test.db';
    await AppDatabase.instance.close();
    await deleteDatabase('${await getDatabasesPath()}/${AppDatabase.fileName}');

    favourites = FavouriteRepository();
    history = HistoryRepository();
    profiles = ProfileRepository();
    tickets = TicketRepository();
    queue = SyncQueue();
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
  });

  FavouriteRoute sampleFavourite({
    String origin = 'rr_KJ01',
    String destination = 'rr_KJ15',
  }) {
    return FavouriteRoute(
      userId: userId,
      label: 'Morning commute',
      originId: origin,
      originName: 'Gombak',
      destinationId: destination,
      destinationName: 'KL Sentral',
      landmark: 'Nu Sentral',
      preferredDepartureMinutes: 8 * 60,
      createdAt: DateTime.now(),
    );
  }

  Ticket sampleTicket({
    String id = 'ticket-1',
    String reference = 'RM-AAA111',
    TicketStatus status = TicketStatus.active,
    DateTime? departAt,
  }) {
    final now = departAt ?? DateTime.now().add(const Duration(hours: 1));
    return Ticket(
      id: id,
      reference: reference,
      userId: userId,
      originId: 'rr_KJ01',
      originName: 'Gombak',
      destinationId: 'rr_KJ15',
      destinationName: 'KL Sentral',
      departAt: now,
      issuedAt: DateTime.now(),
      expiresAt: now.add(const Duration(hours: 4)),
      passengers: 1,
      passengerType: PassengerType.adult,
      fareCard: FareCard.touchNGo,
      paymentMethod: PaymentMethod.touchNGoEwallet,
      amount: 4.20,
      lineSummary: 'Kelana Jaya',
      travelMinutes: 32,
      status: status,
      secret: 'secret-value',
    );
  }

  group('profiles', () {
    test('saves locally and reads back every field', () async {
      final profile = UserProfile(
        id: userId,
        fullName: 'Ooi Chun Yuan',
        email: 'chunyuan@example.com',
        mobile: '0123456789',
        passengerType: PassengerType.student,
        preference: RoutePreference.leastCrowded,
        homeStationId: 'rr_KJ02',
        arrivalAlerts: false,
        avoidStairs: true,
        walkingSpeedKmh: 5.2,
        updatedAt: DateTime.now(),
      );

      await profiles.saveLocal(profile);
      final loaded = await profiles.readLocal(userId);

      expect(loaded, isNotNull);
      expect(loaded!.fullName, 'Ooi Chun Yuan');
      expect(loaded.passengerType, PassengerType.student);
      expect(loaded.preference, RoutePreference.leastCrowded);
      expect(loaded.arrivalAlerts, isFalse);
      expect(loaded.avoidStairs, isTrue);
      expect(loaded.walkingSpeedKmh, closeTo(5.2, 0.001));
      expect(loaded.initials, 'OY');
    });

    test('resolve creates a profile when none exists', () async {
      final created = await profiles.resolve(
        userId: 'brand-new-user',
        email: 'new@example.com',
        fullName: 'New Commuter',
      );

      expect(created.id, 'brand-new-user');
      expect(created.passengerType, PassengerType.adult);
      expect(await profiles.readLocal('brand-new-user'), isNotNull);
    });
  });

  group('favourites', () {
    test('adds a route and returns it with an id', () async {
      final saved = await favourites.add(sampleFavourite());

      expect(saved, isNotNull);
      expect(saved!.id, isNotNull);
      expect(saved.landmark, 'Nu Sentral');
      expect(await favourites.count(userId), 1);
    });

    test('the same pair cannot be saved twice', () async {
      expect(await favourites.add(sampleFavourite()), isNull);
      expect(await favourites.count(userId), 1);
    });

    test('updates and removes a route', () async {
      final existing = (await favourites.all(userId)).first;

      await favourites.update(
        existing.copyWith(label: 'Weekend trip', preferredDepartureMinutes: 600),
      );
      final updated = (await favourites.all(userId)).first;
      expect(updated.label, 'Weekend trip');
      expect(updated.preferredDepartureMinutes, 600);

      expect(await favourites.exists(userId, 'rr_KJ01', 'rr_KJ15'), isTrue);

      await favourites.remove(updated);
      expect(await favourites.count(userId), 0);
    });

    test('favourites are scoped to the user', () async {
      await favourites.add(sampleFavourite());
      expect(await favourites.count(userId), 1);
      expect(await favourites.count('someone-else'), 0);
    });
  });

  group('search history', () {
    test('keeps only the newest entry per station pair', () async {
      Future<void> record(String destination, DateTime at) {
        return history.record(
          SearchHistoryEntry(
            userId: userId,
            originId: 'rr_KJ15',
            originName: 'KL Sentral',
            destinationId: destination,
            destinationName: destination,
            searchedAt: at,
          ),
        );
      }

      await record('klcc', DateTime(2026, 9, 3, 8));
      await record('kajang', DateTime(2026, 9, 3, 9));
      await record('klcc', DateTime(2026, 9, 3, 10));

      final recent = await history.recent(userId);
      expect(recent.length, 2);
      expect(recent.first.destinationId, 'klcc');
      expect(recent.first.searchedAt.hour, 10);
    });

    test('is trimmed to the retention limit and can be cleared', () async {
      for (var i = 0; i < HistoryRepository.retained + 8; i++) {
        await history.record(
          SearchHistoryEntry(
            userId: userId,
            originId: 'origin_$i',
            originName: 'Origin $i',
            destinationId: 'destination_$i',
            destinationName: 'Destination $i',
            searchedAt: DateTime(2026, 9, 3).add(Duration(minutes: i)),
          ),
        );
      }

      expect(await history.count(userId), HistoryRepository.retained);

      await history.clear(userId);
      expect(await history.count(userId), 0);
    });
  });

  group('tickets', () {
    test('saves and reads a ticket by id and reference', () async {
      await tickets.save(sampleTicket());

      expect(await tickets.byId('ticket-1'), isNotNull);
      final byReference = await tickets.byReference('RM-AAA111');
      expect(byReference, isNotNull);
      expect(byReference!.amount, closeTo(4.20, 0.001));
      expect(byReference.passengerType, PassengerType.adult);
    });

    test('separates upcoming from past tickets', () async {
      await tickets.save(
        sampleTicket(
          id: 'ticket-2',
          reference: 'RM-BBB222',
          status: TicketStatus.used,
          departAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      final all = await tickets.all(userId);
      expect(all.length, 2);
      expect(all.where((t) => t.isUpcoming).length, 1);
      expect(all.where((t) => t.isPast).length, 1);
    });

    test('expires active tickets that are past their expiry', () async {
      final stale = DateTime.now().subtract(const Duration(days: 2));
      await tickets.save(
        sampleTicket(
          id: 'ticket-3',
          reference: 'RM-CCC333',
          departAt: stale,
        ),
      );

      final expired = await tickets.expirePastTickets(userId);
      expect(expired, greaterThanOrEqualTo(1));

      final reloaded = await tickets.byId('ticket-3');
      expect(reloaded!.status, TicketStatus.expired);
    });


    test('totals the amount spent, ignoring cancellations', () async {
      final total = await tickets.totalSpend(userId);
      expect(total, greaterThan(0));
      expect(await tickets.count(userId), 3);
    });

    test('expiring queues the change so the server learns about it', () async {
      await queue.clear();
      expect(await queue.pendingCount(), 0);

      await tickets.save(
        sampleTicket(
          id: 'ticket-4',
          reference: 'RM-DDD444',
          departAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );
      await queue.clear();

      final expired = await tickets.expirePastTickets(userId);
      expect(expired, 1);

      expect(
        await queue.pendingCount(),
        greaterThanOrEqualTo(1),
        reason: 'the expired status must be sent on, not just written locally',
      );
    });

    test('expiring nothing does not queue anything', () async {
      await queue.clear();
      expect(await tickets.expirePastTickets(userId), 0);
      expect(await queue.pendingCount(), 0);
    });
  });

  group('offline sync queue', () {
    test('queues changes while the remote is unavailable', () async {
      await queue.clear();
      await queue.enqueue(
        entity: 'profiles',
        entityId: userId,
        operation: SyncOperation.upsert,
        payload: {'id': userId, 'full_name': 'Ooi Chun Yuan'},
      );

      expect(await queue.pendingCount(), 1);

      final pending = await queue.pending();
      expect(pending.first.entity, 'profiles');
      expect(pending.first.operation, SyncOperation.upsert);
      expect(pending.first.payload['full_name'], 'Ooi Chun Yuan');
    });

    test('reports offline rather than losing the change', () async {
      final result = await queue.drain();
      expect(result.pushed, 0);
      expect(result.remaining, greaterThan(0));
      expect(result.isClean, isFalse);

      await queue.clear();
      expect(await queue.pendingCount(), 0);
    });
  });
}
