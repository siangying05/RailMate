import '../../../core/providers/safe_notifier.dart';
import '../../../data/models/favourite_route.dart';
import '../../../data/models/station.dart';
import '../../../data/repositories/favourite_repository.dart';

class FavouriteProvider extends SafeNotifier {
  final FavouriteRepository _repository;

  FavouriteProvider({FavouriteRepository? repository})
      : _repository = repository ?? FavouriteRepository();

  List<FavouriteRoute> _routes = const [];
  String _userId = 'guest';
  bool _busy = false;

  List<FavouriteRoute> get routes => _routes;
  bool get busy => _busy;
  bool get isEmpty => _routes.isEmpty;

  static const int maxRoutes = 12;

  bool get isFull => _routes.length >= maxRoutes;

  Future<void> load(String userId) async {
    _userId = userId;
    if (userId == 'guest') {
      _routes = const [];
      notifyListeners();
      return;
    }

    _busy = true;
    notifyListeners();

    await _repository.pullRemote(userId);
    _routes = await _repository.all(userId);
    _busy = false;
    notifyListeners();
  }

  FavouriteRoute? find(String originId, String destinationId) {
    for (final route in _routes) {
      if (route.originId == originId && route.destinationId == destinationId) {
        return route;
      }
    }
    return null;
  }

  bool isSaved(String originId, String destinationId) =>
      find(originId, destinationId) != null;

  Future<String> toggle({
    required Station origin,
    required Station destination,
    String landmark = '',
    int preferredDepartureMinutes = 480,
  }) async {
    if (_userId == 'guest') {
      return 'Sign in to save a route to your account.';
    }

    final existing = find(origin.id, destination.id);
    if (existing != null) {
      await _repository.remove(existing);
      _routes = _routes.where((route) => route.id != existing.id).toList();
      notifyListeners();
      return 'Removed ${existing.summary} from your saved routes.';
    }

    if (isFull) {
      return 'You already have $maxRoutes saved routes. Remove one first.';
    }

    final saved = await _repository.add(
      FavouriteRoute(
        userId: _userId,
        label: '${origin.name} to ${destination.name}',
        originId: origin.id,
        originName: origin.name,
        destinationId: destination.id,
        destinationName: destination.name,
        landmark: landmark,
        preferredDepartureMinutes: preferredDepartureMinutes,
        createdAt: DateTime.now(),
      ),
    );

    if (saved == null) return 'That route is already saved.';

    _routes = [saved, ..._routes];
    notifyListeners();
    return 'Saved ${saved.summary}.';
  }

  Future<void> remove(FavouriteRoute route) async {
    await _repository.remove(route);
    _routes = _routes.where((item) => item.id != route.id).toList();
    notifyListeners();
  }

  Future<void> rename(FavouriteRoute route, String label) async {
    final updated = route.copyWith(label: label);
    await _repository.update(updated);
    _routes = [
      for (final item in _routes) item.id == route.id ? updated : item,
    ];
    notifyListeners();
  }

  void clear() {
    _userId = 'guest';
    _routes = const [];
    notifyListeners();
  }
}
