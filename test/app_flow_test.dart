import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:railmate/app/auth_gate.dart';
import 'package:railmate/core/providers/rail_data_provider.dart';
import 'package:railmate/core/theme/app_theme.dart';
import 'package:railmate/data/datasources/local/asset_data_source.dart';
import 'package:railmate/data/models/favourite_route.dart';
import 'package:railmate/data/models/ridership.dart';
import 'package:railmate/data/models/ticket.dart';
import 'package:railmate/data/models/user_profile.dart';
import 'package:railmate/data/repositories/favourite_repository.dart';
import 'package:railmate/data/repositories/history_repository.dart';
import 'package:railmate/data/repositories/profile_repository.dart';
import 'package:railmate/data/repositories/ridership_repository.dart';
import 'package:railmate/data/repositories/sync_queue.dart';
import 'package:railmate/data/repositories/ticket_repository.dart';
import 'package:railmate/features/auth/providers/auth_provider.dart';
import 'package:railmate/features/auth/screens/sign_in_screen.dart';
import 'package:railmate/features/guidance/providers/guidance_provider.dart';
import 'package:railmate/features/guidance/screens/navigation_screen.dart';
import 'package:railmate/features/routing/providers/favourite_provider.dart';
import 'package:railmate/features/routing/providers/journey_provider.dart';
import 'package:railmate/features/routing/screens/plan_screen.dart';
import 'package:railmate/features/routing/screens/route_results_screen.dart';
import 'package:railmate/features/routing/screens/station_picker_screen.dart';
import 'package:railmate/features/routing/widgets/route_option_card.dart';
import 'package:railmate/features/ticketing/providers/ticket_provider.dart';

class FakeRidershipRepository extends RidershipRepository {
  FakeRidershipRepository(this.records);

  final List<RidershipRecord> records;

  @override
  Future<RidershipResult> load({bool forceRefresh = false}) async {
    return RidershipResult(
      dataset: RidershipDataset(
        records: records,
        retrievedAt: DateTime.now(),
      ),
      source: RidershipSource.bundled,
    );
  }
}

class FakeProfileRepository extends ProfileRepository {
  UserProfile? stored;

  @override
  Future<UserProfile?> readLocal(String userId) async => stored;

  @override
  Future<void> saveLocal(UserProfile profile) async => stored = profile;

  @override
  Future<UserProfile> save(UserProfile profile) async {
    stored = profile;
    return profile;
  }

  @override
  Future<UserProfile> resolve({
    required String userId,
    required String email,
    required String fullName,
  }) async {
    return stored ??= UserProfile.guest();
  }
}

class FakeSyncQueue extends SyncQueue {
  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<SyncResult> drain() async =>
      const SyncResult(pushed: 0, remaining: 0);

  @override
  Future<void> enqueue({
    required String entity,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {}
}

class FakeHistoryRepository extends HistoryRepository {
  final List<SearchHistoryEntry> entries = [];

  @override
  Future<List<SearchHistoryEntry>> recent(String userId, {int limit = 6}) async {
    return entries.take(limit).toList();
  }

  @override
  Future<void> record(SearchHistoryEntry entry) async {
    entries.removeWhere((existing) => existing.pairKey == entry.pairKey);
    entries.insert(0, entry);
  }

  @override
  Future<void> clear(String userId) async => entries.clear();

  @override
  Future<int> count(String userId) async => entries.length;
}

class FakeTicketRepository extends TicketRepository {
  final List<Ticket> tickets = [];

  @override
  Future<List<Ticket>> all(String userId) async => List.of(tickets);

  @override
  Future<void> save(Ticket ticket) async {
    tickets.removeWhere((existing) => existing.id == ticket.id);
    tickets.add(ticket);
  }

  @override
  Future<int> expirePastTickets(String userId) async => 0;

  @override
  Future<double> totalSpend(String userId) async =>
      tickets.fold<double>(0, (sum, ticket) => sum + ticket.amount);

  @override
  Future<int> count(String userId) async => tickets.length;
}

class FakeFavouriteRepository extends FavouriteRepository {
  @override
  Future<List<FavouriteRoute>> all(String userId) async => const [];

  @override
  Future<int> count(String userId) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RidershipRecord> ridership;

  setUpAll(() async {
    ridership = await const AssetDataSource().loadRidershipSnapshot();
  });

  Widget harness(RailDataProvider railData) {
    final history = FakeHistoryRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RailDataProvider>.value(value: railData),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            profiles: FakeProfileRepository(),
            syncQueue: FakeSyncQueue(),
          )..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => JourneyProvider(history: history),
        ),
        ChangeNotifierProvider(
          create: (_) => FavouriteProvider(repository: FakeFavouriteRepository()),
        ),
        ChangeNotifierProvider(create: (_) => GuidanceProvider()),
        ChangeNotifierProvider(
          create: (_) => TicketProvider(repository: FakeTicketRepository()),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const AuthGate()),
    );
  }

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int attempts = 120,
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .take(12)
        .toList();
    fail('Timed out waiting for $finder. On screen: $texts');
  }

  Future<void> settle(WidgetTester tester, {int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20; i++) {
      if (tester.any(finder)) return;
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -320));
      await settle(tester, frames: 3);
    }
    expect(finder, findsWidgets, reason: 'never scrolled into view');
  }

  Future<void> bootAsGuest(WidgetTester tester) async {
    usePhoneScreen(tester);

    final railData = RailDataProvider(
      ridershipRepository: FakeRidershipRepository(ridership),
    );
    await tester.runAsync(railData.initialise);
    addTearDown(railData.dispose);

    await tester.pumpWidget(harness(railData));
    await waitFor(tester, find.text('Continue as a guest'));
    await settle(tester);

    await tester.tap(find.text('Continue as a guest'));
    await waitFor(tester, find.text('Find routes'));
    await settle(tester);
  }

  Finder pickerField() => find.descendant(
        of: find.byType(StationPickerScreen),
        matching: find.byType(TextField),
      );

  Future<void> pickStation(
    WidgetTester tester,
    String placeholder,
    String query,
    String stationName,
  ) async {
    await tester.tap(find.text(placeholder));
    await waitFor(tester, find.byType(StationPickerScreen));
    await settle(tester);
    await tester.enterText(pickerField(), query);
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, stationName).first);
    await waitFor(tester, find.text('Find routes'));
    await settle(tester);
  }

  testWidgets('the app opens on the sign in screen', (tester) async {
    usePhoneScreen(tester);

    final railData = RailDataProvider(
      ridershipRepository: FakeRidershipRepository(ridership),
    );
    await tester.runAsync(railData.initialise);
    addTearDown(railData.dispose);

    await tester.pumpWidget(harness(railData));
    await waitFor(tester, find.byType(SignInScreen));
    await settle(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('guest mode reaches the plan screen', (tester) async {
    await bootAsGuest(tester);

    expect(find.byType(PlanScreen), findsOneWidget);
    expect(find.text('Hello, Guest'), findsOneWidget);
    expect(find.text('Select departure station'), findsOneWidget);

    await scrollTo(tester, find.text('Predicted crowd levels'));
    expect(find.text('Predicted crowd levels'), findsOneWidget);
  });

  testWidgets('all four route preferences are offered', (tester) async {
    await bootAsGuest(tester);

    expect(find.text('Fastest route'), findsOneWidget);
    expect(find.text('Least transfers'), findsOneWidget);
    expect(find.text('Avoid crowds'), findsOneWidget);
    expect(find.text('Paid area transfers only'), findsOneWidget);
  });

  testWidgets('the station picker filters by name', (tester) async {
    await bootAsGuest(tester);

    await tester.tap(find.text('Select departure station'));
    await waitFor(tester, find.byType(StationPickerScreen));
    await settle(tester);

    await tester.enterText(pickerField(), 'gombak');
    await settle(tester);

    expect(find.widgetWithText(ListTile, 'Gombak'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Kajang'), findsNothing);
  });

  testWidgets('a full search reaches the navigation screen', (tester) async {
    await bootAsGuest(tester);

    await pickStation(tester, 'Select departure station', 'gombak', 'Gombak');
    await pickStation(tester, 'Select destination station', 'kajang', 'Kajang');

    await tester.tap(find.text('Find routes'));
    await waitFor(tester, find.byType(RouteOptionCard));
    await settle(tester);

    expect(find.byType(RouteResultsScreen), findsOneWidget);
    expect(find.textContaining('route option'), findsWidgets);

    await tester.tap(find.byType(RouteOptionCard).first);
    await waitFor(tester, find.byType(NavigationScreen));
    await settle(tester);

    expect(find.text('Transfer guidance'), findsOneWidget);
    expect(find.text('Step by step'), findsOneWidget);

    await scrollTo(tester, find.textContaining('Book this journey'));
    expect(find.textContaining('Book this journey'), findsOneWidget);
  });

  testWidgets('the search form rejects an identical origin and destination',
      (tester) async {
    await bootAsGuest(tester);

    await pickStation(tester, 'Select departure station', 'gombak', 'Gombak');

    await tester.tap(find.text('Select destination station'));
    await waitFor(tester, find.byType(StationPickerScreen));
    await settle(tester);
    await tester.enterText(pickerField(), 'gombak');
    await settle(tester);

    expect(find.widgetWithText(ListTile, 'Gombak'), findsNothing);
  });

  testWidgets('a guest cannot book a ticket', (tester) async {
    await bootAsGuest(tester);

    await pickStation(tester, 'Select departure station', 'gombak', 'Gombak');
    await pickStation(tester, 'Select destination station', 'kajang', 'Kajang');

    await tester.tap(find.text('Find routes'));
    await waitFor(tester, find.byType(RouteOptionCard));
    await settle(tester);

    await tester.tap(find.byType(RouteOptionCard).first);
    await waitFor(tester, find.byType(NavigationScreen));
    await settle(tester);

    await scrollTo(tester, find.textContaining('Book this journey'));
    await tester.tap(find.textContaining('Book this journey'));
    await settle(tester);

    expect(
      find.text('Sign in to buy a ticket for this route.'),
      findsOneWidget,
    );
  });
}
