import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/data/models/favourite_route.dart';
import 'package:railmate/data/models/station.dart';
import 'package:railmate/data/repositories/favourite_repository.dart';
import 'package:railmate/features/routing/providers/favourite_provider.dart';

class FakeFavouriteRepository extends FavouriteRepository {
  final List<FavouriteRoute> rows = [];
  var _nextId = 1;

  @override
  Future<List<FavouriteRoute>> all(String userId) async =>
      rows.where((row) => row.userId == userId).toList();

  @override
  Future<FavouriteRoute?> add(FavouriteRoute route) async {
    final clash = rows.any(
      (row) =>
          row.userId == route.userId &&
          row.originId == route.originId &&
          row.destinationId == route.destinationId,
    );
    if (clash) return null;

    final saved = FavouriteRoute.fromMap({
      ...route.toMap(),
      'id': _nextId++,
      'created_at': route.createdAt.millisecondsSinceEpoch,
    });
    rows.add(saved);
    return saved;
  }

  @override
  Future<void> update(FavouriteRoute route) async {
    final index = rows.indexWhere((row) => row.id == route.id);
    if (index >= 0) rows[index] = route;
  }

  @override
  Future<void> remove(FavouriteRoute route) async {
    rows.removeWhere((row) => row.id == route.id);
  }

  @override
  Future<int> count(String userId) async =>
      rows.where((row) => row.userId == userId).length;
}

Station station(String id, String name) => Station(
      id: id,
      name: name,
      lat: 3.1,
      lon: 101.6,
      operator: 'Rapid Rail',
      accessible: true,
      lineIds: const ['rr_KJ'],
    );

void main() {
  late FakeFavouriteRepository repository;
  late FavouriteProvider provider;

  final gombak = station('rr_KJ01', 'Gombak');
  final klSentral = station('rr_KJ15', 'KL Sentral');
  final kajang = station('rr_KG35', 'Kajang');

  setUp(() async {
    repository = FakeFavouriteRepository();
    provider = FavouriteProvider(repository: repository);
    await provider.load('user-1');
  });

  test('a guest is told to sign in and nothing is written', () async {
    final guest = FavouriteProvider(repository: repository);
    await guest.load('guest');

    final message = await guest.toggle(origin: gombak, destination: kajang);

    expect(message, contains('Sign in'));
    expect(repository.rows, isEmpty);
    expect(guest.isEmpty, isTrue);
  });

  test('saving then tapping again removes the route', () async {
    final saved = await provider.toggle(origin: gombak, destination: kajang);
    expect(saved, contains('Saved'));
    expect(provider.isSaved('rr_KJ01', 'rr_KG35'), isTrue);
    expect(provider.routes, hasLength(1));

    final removed = await provider.toggle(origin: gombak, destination: kajang);
    expect(removed, contains('Removed'));
    expect(provider.isSaved('rr_KJ01', 'rr_KG35'), isFalse);
    expect(provider.routes, isEmpty);
  });

  test('the saved route carries the landmark and departure time', () async {
    await provider.toggle(
      origin: gombak,
      destination: klSentral,
      landmark: 'Nu Sentral',
      preferredDepartureMinutes: 540,
    );

    final route = provider.routes.single;
    expect(route.landmark, 'Nu Sentral');
    expect(route.preferredDepartureMinutes, 540);
    expect(route.label, 'Gombak to KL Sentral');
  });

  test('the opposite direction is a different route', () async {
    await provider.toggle(origin: gombak, destination: kajang);
    await provider.toggle(origin: kajang, destination: gombak);

    expect(provider.routes, hasLength(2));
    expect(provider.isSaved('rr_KJ01', 'rr_KG35'), isTrue);
    expect(provider.isSaved('rr_KG35', 'rr_KJ01'), isTrue);
  });

  test('the limit is enforced and reported', () async {
    for (var i = 0; i < FavouriteProvider.maxRoutes; i++) {
      await provider.toggle(
        origin: gombak,
        destination: station('dest_$i', 'Stop $i'),
      );
    }
    expect(provider.routes, hasLength(FavouriteProvider.maxRoutes));
    expect(provider.isFull, isTrue);

    final message = await provider.toggle(
      origin: gombak,
      destination: station('dest_extra', 'One too many'),
    );

    expect(message, contains('Remove one first'));
    expect(provider.routes, hasLength(FavouriteProvider.maxRoutes));
  });

  test('load only returns the signed in user routes', () async {
    await provider.toggle(origin: gombak, destination: kajang);

    repository.rows.add(
      FavouriteRoute(
        id: 999,
        userId: 'someone-else',
        label: 'Not mine',
        originId: 'rr_KJ01',
        originName: 'Gombak',
        destinationId: 'rr_KJ15',
        destinationName: 'KL Sentral',
        landmark: '',
        preferredDepartureMinutes: 480,
        createdAt: DateTime(2026, 9, 3),
      ),
    );

    await provider.load('user-1');
    expect(provider.routes, hasLength(1));
    expect(provider.routes.single.userId, 'user-1');
  });

  test('renaming keeps the pair and updates the label', () async {
    await provider.toggle(origin: gombak, destination: kajang);
    await provider.rename(provider.routes.single, 'Morning commute');

    expect(provider.routes.single.label, 'Morning commute');
    expect(provider.isSaved('rr_KJ01', 'rr_KG35'), isTrue);
  });
}
