import '../../../core/providers/safe_notifier.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_network.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/ticket_repository.dart';
import '../services/payment_service.dart';
import '../services/qr_pass_service.dart';

class BookingDraft {
  final JourneyOption option;
  final String originName;
  final String destinationName;
  final String lineSummary;
  final int passengers;
  final PassengerType passengerType;
  final FareCard card;
  final double amount;

  const BookingDraft({
    required this.option,
    required this.originName,
    required this.destinationName,
    required this.lineSummary,
    required this.passengers,
    required this.passengerType,
    required this.card,
    required this.amount,
  });

  String get summary => '$originName to $destinationName';
}

class TicketProvider extends SafeNotifier {
  final TicketRepository _repository;
  final PaymentService _payments;
  final QrPassService _qr;

  TicketProvider({
    TicketRepository? repository,
    PaymentService? payments,
    QrPassService? qr,
  })  : _repository = repository ?? TicketRepository(),
        _payments = payments ?? PaymentService(),
        _qr = qr ?? const QrPassService();

  List<Ticket> _tickets = const [];
  bool _loading = true;
  BookingDraft? _draft;
  PaymentMethod _method = PaymentMethod.touchNGoEwallet;
  PaymentStage _stage = PaymentStage.idle;
  PaymentOutcome? _outcome;
  Ticket? _lastIssued;
  String? _error;
  double _totalSpend = 0;

  List<Ticket> get tickets => _tickets;
  bool get loading => _loading;
  BookingDraft? get draft => _draft;
  PaymentMethod get method => _method;
  PaymentStage get stage => _stage;
  PaymentOutcome? get outcome => _outcome;
  Ticket? get lastIssued => _lastIssued;
  String? get error => _error;
  double get totalSpend => _totalSpend;

  QrPassService get qrService => _qr;
  PaymentService get paymentService => _payments;

  List<Ticket> get upcoming =>
      _tickets.where((ticket) => ticket.isUpcoming).toList();

  List<Ticket> get past => _tickets.where((ticket) => ticket.isPast).toList();

  bool get isProcessing =>
      _stage == PaymentStage.authorising ||
      _stage == PaymentStage.processing ||
      _stage == PaymentStage.confirming;

  Future<void> load(String userId) async {
    _loading = true;
    notifyListeners();

    await _repository.pullRemote(userId);
    await _repository.expirePastTickets(userId);
    _tickets = await _repository.all(userId);
    _totalSpend = await _repository.totalSpend(userId);

    _loading = false;
    notifyListeners();
  }

  void startBooking({
    required JourneyOption option,
    required RailNetwork network,
    required int passengers,
    required PassengerType passengerType,
    required FareCard card,
  }) {
    final lines = option.rideLegs
        .map((leg) => network.line(leg.lineId)?.shortName ?? '')
        .where((name) => name.isNotEmpty)
        .join(' to ');

    _draft = BookingDraft(
      option: option,
      originName: network.stationName(option.originId),
      destinationName: network.stationName(option.destinationId),
      lineSummary: lines,
      passengers: passengers,
      passengerType: passengerType,
      card: card,
      amount: option.fare.total,
    );
    _stage = PaymentStage.idle;
    _outcome = null;
    _error = null;
    notifyListeners();
  }

  void setMethod(PaymentMethod method) {
    _method = method;
    notifyListeners();
  }

  void cancelBooking() {
    _draft = null;
    _stage = PaymentStage.idle;
    _outcome = null;
    _error = null;
    notifyListeners();
  }

  Future<Ticket?> payAndIssue({
    required String userId,
    bool forceFailure = false,
  }) async {
    final draft = _draft;
    if (draft == null) return null;

    _error = null;
    _outcome = null;

    await for (final stage in _payments.process(
      method: _method,
      amount: draft.amount,
      forceFailure: forceFailure,
    )) {
      _stage = stage;
      notifyListeners();
    }

    final outcome = _payments.settle(
      method: _method,
      amount: draft.amount,
      forceFailure: forceFailure,
    );
    _outcome = outcome;

    if (!outcome.approved) {
      _stage = PaymentStage.failed;
      _error = outcome.message;
      notifyListeners();
      return null;
    }

    final now = DateTime.now();
    final ticket = Ticket(
      id: '${now.microsecondsSinceEpoch}',
      reference: _qr.generateReference(),
      userId: userId,
      originId: draft.option.originId,
      originName: draft.originName,
      destinationId: draft.option.destinationId,
      destinationName: draft.destinationName,
      departAt: draft.option.departAt,
      issuedAt: now,
      expiresAt: draft.option.departAt.add(const Duration(hours: 4)),
      passengers: draft.passengers,
      passengerType: draft.passengerType,
      fareCard: draft.card,
      paymentMethod: _method,
      amount: draft.amount,
      lineSummary: draft.lineSummary,
      travelMinutes: draft.option.totalMinutes,
      status: TicketStatus.active,
      secret: _qr.generateSecret(),
    );

    await _repository.save(ticket);
    _lastIssued = ticket;
    _stage = PaymentStage.done;
    _draft = null;

    await load(userId);
    return ticket;
  }

  Future<void> markUsed(Ticket ticket, String userId) async {
    await _repository.updateStatus(ticket, TicketStatus.used);
    await load(userId);
  }

  Future<void> cancelTicket(Ticket ticket, String userId) async {
    await _repository.updateStatus(ticket, TicketStatus.cancelled);
    await load(userId);
  }

  QrPass buildPass(Ticket ticket) => _qr.build(ticket);

  void clearOutcome() {
    _stage = PaymentStage.idle;
    _outcome = null;
    _error = null;
    notifyListeners();
  }
}
