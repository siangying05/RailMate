import 'package:flutter/material.dart';

import '../../../core/providers/safe_notifier.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/crowd.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/station.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/services/crowd_estimator.dart';
import '../services/route_planner.dart';

enum JourneyStatus { idle, searching, ready, empty }

class JourneyProvider extends SafeNotifier {
  final HistoryRepository _history;

  JourneyProvider({HistoryRepository? history})
      : _history = history ?? HistoryRepository();

  Station? _origin;
  Station? _destination;
  String _landmark = '';
  DateTime _departureDate = DateTime.now();
  TimeOfDay _departureTime = TimeOfDay.now();
  RoutePreference _preference = RoutePreference.fastest;
  FareCard _card = FareCard.touchNGo;
  PassengerType _passengerType = PassengerType.adult;
  int _passengers = 1;
  int _maxTransfers = 4;

  JourneyStatus _status = JourneyStatus.idle;
  List<JourneyOption> _options = const [];
  JourneyOption? _selected;
  String? _message;
  String? _formError;
  List<TravelWindow> _quieterWindows = const [];
  List<SearchHistoryEntry> _recent = const [];

  Station? get origin => _origin;
  Station? get destination => _destination;
  String get landmark => _landmark;
  DateTime get departureDate => _departureDate;
  TimeOfDay get departureTime => _departureTime;
  RoutePreference get preference => _preference;
  FareCard get card => _card;
  PassengerType get passengerType => _passengerType;
  int get passengers => _passengers;
  int get maxTransfers => _maxTransfers;

  JourneyStatus get status => _status;
  List<JourneyOption> get options => _options;
  JourneyOption? get selected => _selected;
  String? get message => _message;
  String? get formError => _formError;
  List<TravelWindow> get quieterWindows => _quieterWindows;
  List<SearchHistoryEntry> get recent => _recent;

  bool get hasResults => _options.isNotEmpty;

  DateTime get departAt => DateTime(
        _departureDate.year,
        _departureDate.month,
        _departureDate.day,
        _departureTime.hour,
        _departureTime.minute,
      );

  int get departureMinutes => TimeUtils.minutesOf(_departureTime);

  bool get isPeakDeparture => TimeUtils.isPeak(departureMinutes);

  String get departureLabel =>
      '${TimeUtils.relativeDay(_departureDate)}, '
      '${TimeUtils.formatMinutes(departureMinutes)}';

  String? validate() {
    final stations = Validators.journeyStations(_origin?.id, _destination?.id);
    if (stations != null) return stations;

    final landmarkError = Validators.landmark(_landmark);
    if (landmarkError != null) return landmarkError;

    return Validators.departureTime(departAt);
  }

  bool get canSearch => validate() == null;

  void setOrigin(Station? station) {
    _origin = station;
    _formError = null;
    notifyListeners();
  }

  void setDestination(Station? station) {
    _destination = station;
    _formError = null;
    notifyListeners();
  }

  void setLandmark(String value) {
    _landmark = value;
    notifyListeners();
  }

  void setDepartureDate(DateTime date) {
    _departureDate = date;
    _formError = null;
    notifyListeners();
  }

  void setDepartureTime(TimeOfDay time) {
    _departureTime = time;
    _formError = null;
    notifyListeners();
  }

  void useNow() {
    final now = DateTime.now();
    _departureDate = now;
    _departureTime = TimeOfDay.fromDateTime(now);
    _formError = null;
    notifyListeners();
  }

  void setPreference(RoutePreference preference) {
    _preference = preference;
    notifyListeners();
  }

  void setCard(FareCard card) {
    _card = card;
    notifyListeners();
  }

  void setPassengerType(PassengerType type) {
    _passengerType = type;
    notifyListeners();
  }

  void setPassengers(int count) {
    _passengers = count.clamp(1, 6);
    notifyListeners();
  }

  void setMaxTransfers(int value) {
    _maxTransfers = value.clamp(0, 5);
    notifyListeners();
  }

  void swap() {
    final previous = _origin;
    _origin = _destination;
    _destination = previous;
    notifyListeners();
  }

  void applyPair(Station origin, Station destination, {String landmark = ''}) {
    _origin = origin;
    _destination = destination;
    _landmark = landmark;
    _formError = null;
    notifyListeners();
  }

  Future<void> loadRecent(String userId) async {
    _recent = await _history.recent(userId);
    notifyListeners();
  }

  Future<void> clearRecent(String userId) async {
    await _history.clear(userId);
    _recent = const [];
    notifyListeners();
  }

  Future<bool> search({
    required RoutePlanner planner,
    required CrowdEstimator crowdEstimator,
    required String userId,
  }) async {
    final error = validate();
    if (error != null) {
      _formError = error;
      notifyListeners();
      return false;
    }

    _status = JourneyStatus.searching;
    _formError = null;
    _message = null;
    _options = const [];
    _selected = null;
    _quieterWindows = const [];
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 200));

    final result = planner.plan(
      PlanRequest(
        originId: _origin!.id,
        destinationId: _destination!.id,
        departAt: departAt,
        preference: _preference,
        card: _card,
        passengerType: _passengerType,
        passengers: _passengers,
        maxTransfers: _maxTransfers,
      ),
    );

    _options = result.options;
    _message = result.message;
    _selected = result.best;

    if (_options.isEmpty) {
      _status = JourneyStatus.empty;
      notifyListeners();
      return false;
    }

    if (_options.first.crowd.level == CrowdLevel.high) {
      _quieterWindows = crowdEstimator.quieterAlternatives(
        _options.first.lineIds,
        departAt,
      );
    }

    await _history.record(
      SearchHistoryEntry(
        userId: userId,
        originId: _origin!.id,
        originName: _origin!.name,
        destinationId: _destination!.id,
        destinationName: _destination!.name,
        searchedAt: DateTime.now(),
      ),
    );
    await loadRecent(userId);

    _status = JourneyStatus.ready;
    notifyListeners();
    return true;
  }

  void select(JourneyOption option) {
    _selected = option;
    notifyListeners();
  }

  void reset() {
    _status = JourneyStatus.idle;
    _options = const [];
    _selected = null;
    _message = null;
    _formError = null;
    _quieterWindows = const [];
    notifyListeners();
  }
}
