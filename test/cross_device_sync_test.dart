import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/core/config/supabase_config.dart';
import 'package:railmate/data/datasources/local/app_database.dart';
import 'package:railmate/data/datasources/remote/supabase_service.dart';
import 'package:railmate/data/models/fare.dart';
import 'package:railmate/data/models/favourite_route.dart';
import 'package:railmate/data/models/ticket.dart';
import 'package:railmate/data/models/user_profile.dart';
import 'package:railmate/data/repositories/favourite_repository.dart';
import 'package:railmate/data/repositories/ticket_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String userId = 'user-with-two-phones';

class FakeRemote extends SupabaseService {
  FakeRemote() : super.stub();

  final Map<String, List<Map<String, dynamic>>> tables = {};
  bool online = true;
  bool failSelect = false;

  @override
  bool get isAvailable => online;

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic> filters = const {},
    String? orderBy,
    bool ascending = false,
  }) async {
    if (failSelect) throw const RemoteException('offline');
    final rows = tables[table] ?? const [];
    return rows.where((row) {
      return filters.entries.every((f) => row[f.key] == f.value);
    }).toList();
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) async {
    tables.putIfAbsent(table, () => []).add(row);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRemote remote;
  late TicketRepository tickets;
  late FavouriteRepository favourites;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.fileName = 'railmate_sync_test.db';
    await AppDatabase.instance.close();
    await deleteDatabase('${await getDatabasesPath()}/${AppDatabase.fileName}');
  });

  setUp(() {
    remote = FakeRemote();
    tickets = TicketRepository(remote: remote);
    favourites = FavouriteRepository(remote: remote);
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
  });

  Map<String, dynamic> remoteTicket(String id, String reference) {
    final depart = DateTime.now().add(const Duration(hours: 2));
    return Ticket(
      id: id,
      reference: reference,
      userId: userId,
      originId: 'rr_KJ01',
      originName: 'Gombak',
      destinationId: 'rr_KG35',
      destinationName: 'Kajang',
      departAt: depart,
      issuedAt: DateTime.now(),
      expiresAt: depart.add(const Duration(hours: 4)),
      passengers: 1,
      passengerType: PassengerType.student,
      fareCard: FareCard.touchNGo,
      paymentMethod: PaymentMethod.touchNGoEwallet,
      amount: 2.98,
      lineSummary: 'Kelana Jaya to Kajang',
      travelMinutes: 83,
      status: TicketStatus.active,
      secret: 'secret-that-never-leaves-the-first-device',
    ).toRemoteJson();
  }

  Map<String, dynamic> remoteFavourite(String origin, String destination) {
    return FavouriteRoute(
      userId: userId,
      label: 'Morning commute',
      originId: origin,
      originName: 'Gombak',
      destinationId: destination,
      destinationName: 'KL Sentral',
      landmark: 'Nu Sentral',
      preferredDepartureMinutes: 480,
      createdAt: DateTime.now(),
    ).toRemoteJson();
  }

  group('tickets bought on another device', () {
    test('are pulled down and listed here', () async {
      remote.tables[SupabaseConfig.tableTickets] = [
        remoteTicket('t-1', 'RM-AAA111'),
        remoteTicket('t-2', 'RM-BBB222'),
      ];

      expect(await tickets.all(userId), isEmpty);

      final added = await tickets.pullRemote(userId);
      expect(added, 2);

      final local = await tickets.all(userId);
      expect(local.length, 2);
      expect(local.map((t) => t.reference), containsAll(['RM-AAA111', 'RM-BBB222']));
    });

    test('cannot be turned into a pass, because the secret stays put',
        () async {
      final restored = (await tickets.all(userId)).first;
      expect(restored.secret, isEmpty);
      expect(restored.canShowPass, isFalse);
    });

    test('pulling twice does not duplicate them', () async {
      expect(await tickets.pullRemote(userId), 0);
      expect((await tickets.all(userId)).length, 2);
    });

    test('a ticket bought here keeps its secret when the pull runs', () async {
      final mine = Ticket(
        id: 't-local',
        reference: 'RM-LOCAL1',
        userId: userId,
        originId: 'rr_KJ01',
        originName: 'Gombak',
        destinationId: 'rr_KG35',
        destinationName: 'Kajang',
        departAt: DateTime.now().add(const Duration(hours: 1)),
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 5)),
        passengers: 1,
        passengerType: PassengerType.adult,
        fareCard: FareCard.touchNGo,
        paymentMethod: PaymentMethod.touchNGoEwallet,
        amount: 5.95,
        lineSummary: 'Kelana Jaya to Kajang',
        travelMinutes: 83,
        status: TicketStatus.active,
        secret: 'my-own-secret',
      );
      await tickets.save(mine);

      await tickets.pullRemote(userId);

      final reloaded = await tickets.byId('t-local');
      expect(reloaded!.secret, 'my-own-secret');
      expect(reloaded.canShowPass, isTrue);
    });

    test('an offline pull changes nothing and does not throw', () async {
      final before = (await tickets.all(userId)).length;
      remote.online = false;
      expect(await tickets.pullRemote(userId), 0);
      remote.online = true;
      remote.failSelect = true;
      expect(await tickets.pullRemote(userId), 0);
      expect((await tickets.all(userId)).length, before);
    });

    test('a guest never pulls anything', () async {
      remote.failSelect = false;
      expect(await tickets.pullRemote('guest'), 0);
    });
  });

  group('routes saved on another device', () {
    test('are pulled down and listed here', () async {
      remote.tables[SupabaseConfig.tableFavourites] = [
        remoteFavourite('rr_KJ01', 'rr_KJ15'),
      ];

      expect(await favourites.all(userId), isEmpty);
      expect(await favourites.pullRemote(userId), 1);

      final local = await favourites.all(userId);
      expect(local.length, 1);
      expect(local.first.label, 'Morning commute');
      expect(local.first.landmark, 'Nu Sentral');
    });

    test('pulling twice does not duplicate the same station pair', () async {
      expect(await favourites.pullRemote(userId), 0);
      expect((await favourites.all(userId)).length, 1);
    });
  });
}
