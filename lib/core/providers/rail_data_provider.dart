import '../../data/models/rail_network.dart';
import '../../data/models/ridership.dart';
import '../../data/repositories/network_repository.dart';
import '../../data/repositories/ridership_repository.dart';
import '../../data/services/crowd_estimator.dart';
import '../../data/services/exit_recommender.dart';
import '../../data/services/platform_directory.dart';
import '../../features/routing/services/fare_engine.dart';
import '../../features/routing/services/route_planner.dart';
import 'safe_notifier.dart';

enum LoadStatus { idle, loading, ready, failed }

class RailDataProvider extends SafeNotifier {
  final NetworkRepository _networkRepository;
  final RidershipRepository _ridershipRepository;

  RailDataProvider({
    NetworkRepository? networkRepository,
    RidershipRepository? ridershipRepository,
  })  : _networkRepository = networkRepository ?? NetworkRepository(),
        _ridershipRepository = ridershipRepository ?? RidershipRepository();

  LoadStatus _status = LoadStatus.idle;
  String? _error;
  String? _dataWarning;

  RailNetwork? _network;
  CrowdEstimator? _crowdEstimator;
  RoutePlanner? _planner;
  FareEngine? _fareEngine;
  ExitRecommender? _exitRecommender;
  PlatformDirectory? _platformDirectory;
  RidershipSource _source = RidershipSource.bundled;
  DateTime? _retrievedAt;

  LoadStatus get status => _status;
  String? get error => _error;
  String? get dataWarning => _dataWarning;
  bool get isReady => _status == LoadStatus.ready;

  RailNetwork get network => _network!;
  CrowdEstimator get crowdEstimator => _crowdEstimator!;
  RoutePlanner get planner => _planner!;
  FareEngine get fareEngine => _fareEngine!;
  ExitRecommender get exitRecommender => _exitRecommender!;
  PlatformDirectory get platformDirectory => _platformDirectory!;

  RidershipSource get source => _source;
  DateTime? get retrievedAt => _retrievedAt;
  bool get isLiveData => _source.isLive;
  String get sourceLabel => _source.label;

  RidershipDataset? get dataset => _crowdEstimator?.dataset;

  String get dataSummary => _crowdEstimator?.dataNarrative() ?? '';

  Future<void> initialise({bool forceRefresh = false}) async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final bundle = await _networkRepository.load();
      final ridership =
          await _ridershipRepository.load(forceRefresh: forceRefresh);

      _network = bundle.network;
      _source = ridership.source;
      _dataWarning = ridership.warning;
      _retrievedAt = ridership.dataset.retrievedAt;

      _crowdEstimator = CrowdEstimator(
        network: bundle.network,
        dataset: ridership.dataset,
        live: ridership.source.isLive,
      );

      _exitRecommender = ExitRecommender(directory: bundle.exits);
      _platformDirectory = PlatformDirectory(
        network: bundle.network,
        layouts: bundle.layouts,
      );
      _fareEngine = FareEngine(network: bundle.network);
      _planner = RoutePlanner(
        network: bundle.network,
        crowdEstimator: _crowdEstimator!,
        fareEngine: _fareEngine!,
      );

      _status = LoadStatus.ready;
    } catch (error) {
      _error = error.toString();
      _status = LoadStatus.failed;
    }

    notifyListeners();
  }

  Future<void> refreshOpenData() async {
    if (_network == null) {
      await initialise(forceRefresh: true);
      return;
    }

    final ridership = await _ridershipRepository.load(forceRefresh: true);
    _source = ridership.source;
    _dataWarning = ridership.warning;
    _retrievedAt = ridership.dataset.retrievedAt;

    _crowdEstimator = CrowdEstimator(
      network: _network!,
      dataset: ridership.dataset,
      live: ridership.source.isLive,
    );
    _planner = RoutePlanner(
      network: _network!,
      crowdEstimator: _crowdEstimator!,
      fareEngine: _fareEngine!,
    );

    notifyListeners();
  }
}
