import 'package:collection/collection.dart';

import '../../../core/utils/time_utils.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/interchange.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/rail_network.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/crowd_estimator.dart';
import 'fare_engine.dart';

class PlannerWeights {
  final int transferPenaltySeconds;
  final int walkPenaltySeconds;
  final double crowdPenalty;
  final double farePenaltyPerRinggit;
  final bool paidAreaOnly;

  const PlannerWeights({
    required this.transferPenaltySeconds,
    required this.crowdPenalty,
    this.walkPenaltySeconds = 420,
    this.farePenaltyPerRinggit = 60,
    this.paidAreaOnly = false,
  });

  static const PlannerWeights fastest = PlannerWeights(
    transferPenaltySeconds: 240,
    crowdPenalty: 0,
  );

  static const PlannerWeights leastTransfers = PlannerWeights(
    transferPenaltySeconds: 1800,
    crowdPenalty: 0,
  );

  static const PlannerWeights leastCrowded = PlannerWeights(
    transferPenaltySeconds: 360,
    crowdPenalty: 1200,
  );

  static const PlannerWeights gatedOnly = PlannerWeights(
    transferPenaltySeconds: 240,
    crowdPenalty: 0,
    paidAreaOnly: true,
  );
}

class PlanRequest {
  final String originId;
  final String destinationId;
  final DateTime departAt;
  final RoutePreference preference;
  final FareCard card;
  final PassengerType passengerType;
  final int passengers;
  final int maxTransfers;
  final Set<String> avoidLineIds;

  const PlanRequest({
    required this.originId,
    required this.destinationId,
    required this.departAt,
    this.preference = RoutePreference.fastest,
    this.card = FareCard.touchNGo,
    this.passengerType = PassengerType.adult,
    this.passengers = 1,
    this.maxTransfers = 4,
    this.avoidLineIds = const {},
  });
}

class PlanResult {
  final List<JourneyOption> options;
  final String? message;

  const PlanResult({required this.options, this.message});

  bool get isEmpty => options.isEmpty;

  JourneyOption? get best => options.isEmpty ? null : options.first;
}

class RoutePlanner {
  static const String originNode = '__origin__';
  static const String destinationNode = '__destination__';
  static const int paidPlatformChangeSeconds = 150;

  final RailNetwork network;
  final CrowdEstimator crowdEstimator;
  final FareEngine fareEngine;

  const RoutePlanner({
    required this.network,
    required this.crowdEstimator,
    required this.fareEngine,
  });

  PlanResult plan(PlanRequest request) {
    if (request.originId == request.destinationId) {
      return const PlanResult(
        options: [],
        message: 'Departure and destination cannot be the same station.',
      );
    }

    if (network.station(request.originId) == null ||
        network.station(request.destinationId) == null) {
      return const PlanResult(
        options: [],
        message: 'One of the selected stations is not in the rail network.',
      );
    }

    final graph = _buildGraph(request.departAt);

    final attempts = <RouteStrategy, PlannerWeights>{
      RouteStrategy.fastest: PlannerWeights.fastest,
      RouteStrategy.leastTransfers: PlannerWeights.leastTransfers,
      RouteStrategy.leastCrowded: PlannerWeights.leastCrowded,
    };

    final bySignature = <String, JourneyOption>{};
    final strategyBySignature = <String, Set<RouteStrategy>>{};

    attempts.forEach((strategy, weights) {
      final effective = request.preference == RoutePreference.paidAreaOnly
          ? PlannerWeights(
              transferPenaltySeconds: weights.transferPenaltySeconds,
              crowdPenalty: weights.crowdPenalty,
              paidAreaOnly: true,
            )
          : weights;

      final path = _search(graph, request, effective);
      if (path == null) return;

      final option = _buildOption(path, request);
      if (option == null) return;
      if (option.transferCount > request.maxTransfers) return;

      bySignature.putIfAbsent(option.signature, () => option);
      strategyBySignature
          .putIfAbsent(option.signature, () => <RouteStrategy>{})
          .add(strategy);
    });

    if (bySignature.isEmpty) {
      final reason = request.preference == RoutePreference.paidAreaOnly
          ? 'No route was found using paid area interchanges only. Turn that preference off to allow walking connections.'
          : 'No rail connection was found between these two stations.';
      return PlanResult(options: const [], message: reason);
    }

    for (final extra in _diversify(graph, request, bySignature.values.first)) {
      if (extra.transferCount <= request.maxTransfers) {
        bySignature.putIfAbsent(extra.signature, () => extra);
      }
    }

    final options = bySignature.values
        .map(
          (option) => option.copyWith(
            strategies:
                strategyBySignature[option.signature] ?? const <RouteStrategy>{},
          ),
        )
        .toList();

    options.sort((a, b) {
      final byPreference =
          _preferenceRank(b, request).compareTo(_preferenceRank(a, request));
      if (byPreference != 0) return byPreference;
      return a.totalSeconds.compareTo(b.totalSeconds);
    });

    return PlanResult(options: options.take(3).toList());
  }

  int _preferenceRank(JourneyOption option, PlanRequest request) {
    var score = option.strategies.length;

    switch (request.preference) {
      case RoutePreference.fastest:
        if (option.strategies.contains(RouteStrategy.fastest)) score += 5;
        break;
      case RoutePreference.leastTransfers:
        if (option.strategies.contains(RouteStrategy.leastTransfers)) score += 5;
        break;
      case RoutePreference.leastCrowded:
        if (option.strategies.contains(RouteStrategy.leastCrowded)) score += 5;
        break;
      case RoutePreference.paidAreaOnly:
        if (option.isPaidAreaOnly) score += 5;
        break;
    }

    return score;
  }

  List<JourneyOption> _diversify(
    _Graph graph,
    PlanRequest request,
    JourneyOption primary,
  ) {
    if (primary.rideLegs.isEmpty) return const [];

    final candidates = (primary.rideLegs.toList()
          ..sort((a, b) => b.seconds.compareTo(a.seconds)))
        .map((leg) => leg.lineId)
        .toList();

    final found = <String, JourneyOption>{primary.signature: primary};
    final extras = <JourneyOption>[];

    for (final lineId in candidates) {
      if (extras.length >= 2) break;

      final alternative = PlanRequest(
        originId: request.originId,
        destinationId: request.destinationId,
        departAt: request.departAt,
        preference: request.preference,
        card: request.card,
        passengerType: request.passengerType,
        passengers: request.passengers,
        maxTransfers: request.maxTransfers,
        avoidLineIds: {...request.avoidLineIds, lineId},
      );

      final path = _search(graph, alternative, PlannerWeights.fastest);
      if (path == null) continue;

      final option = _buildOption(path, request);
      if (option == null) continue;
      if (option.totalSeconds > primary.totalSeconds * 1.9) continue;
      if (found.containsKey(option.signature)) continue;

      found[option.signature] = option;
      extras.add(option);
    }

    return extras;
  }

  _Graph _buildGraph(DateTime departAt) {
    final adjacency = <String, List<_Edge>>{};

    void connect(String from, _Edge edge) {
      adjacency.putIfAbsent(from, () => <_Edge>[]).add(edge);
    }

    final peak = TimeUtils.isPeak(departAt.hour * 60 + departAt.minute);

    for (final line in network.lines) {
      final waitSeconds = (line.headwaySecs(peak: peak) / 2).round();
      final crowd = crowdEstimator.forLine(line, departAt).score;

      for (var i = 0; i < line.stationIds.length; i++) {
        final stationId = line.stationIds[i];
        final node = _node(stationId, line.id);

        connect(
          originNode,
          _Edge(
            to: node,
            seconds: waitSeconds,
            km: 0,
            kind: _EdgeKind.board,
            lineId: line.id,
            crowd: crowd,
            boardStationId: stationId,
          ),
        );

        connect(
          node,
          _Edge(
            to: destinationNode,
            seconds: 0,
            km: 0,
            kind: _EdgeKind.alight,
            lineId: '',
            crowd: 0,
            alightStationId: stationId,
          ),
        );

        if (i < line.stationIds.length - 1) {
          final nextId = line.stationIds[i + 1];
          final seconds = line.hopSecondsAt(i);
          final km = line.hopKmAt(i);

          connect(
            node,
            _Edge(
              to: _node(nextId, line.id),
              seconds: seconds,
              km: km,
              kind: _EdgeKind.ride,
              lineId: line.id,
              crowd: crowd,
            ),
          );
          connect(
            _node(nextId, line.id),
            _Edge(
              to: node,
              seconds: seconds,
              km: km,
              kind: _EdgeKind.ride,
              lineId: line.id,
              crowd: crowd,
            ),
          );
        }
      }
    }

    for (final station in network.stations.values) {
      if (station.lineIds.length < 2) continue;
      for (final fromLine in station.lineIds) {
        for (final toLine in station.lineIds) {
          if (fromLine == toLine) continue;
          final target = network.line(toLine);
          if (target == null) continue;

          connect(
            _node(station.id, fromLine),
            _Edge(
              to: _node(station.id, toLine),
              seconds: paidPlatformChangeSeconds +
                  (target.headwaySecs(peak: peak) / 2).round(),
              km: 0,
              kind: _EdgeKind.transfer,
              lineId: toLine,
              crowd: crowdEstimator.forLine(target, departAt).score,
              interchangeType: InterchangeType.paid,
              note: 'Change to ${target.name}',
            ),
          );
        }
      }
    }

    for (final link in network.interchanges) {
      _connectInterchange(connect, link, peak, departAt);
      _connectInterchange(connect, link.reversed(), peak, departAt);
    }

    return _Graph(adjacency: adjacency);
  }

  void _connectInterchange(
    void Function(String, _Edge) connect,
    Interchange link,
    bool peak,
    DateTime departAt,
  ) {
    final from = network.station(link.fromStationId);
    final to = network.station(link.toStationId);
    if (from == null || to == null) return;

    for (final fromLine in from.lineIds) {
      for (final toLine in to.lineIds) {
        if (fromLine == toLine) continue;
        final target = network.line(toLine);
        if (target == null) continue;

        final wait = (target.headwaySecs(peak: peak) / 2).round();

        connect(
          _node(from.id, fromLine),
          _Edge(
            to: _node(to.id, toLine),
            seconds: link.walkMinutes * 60 + wait,
            km: link.metres / 1000,
            kind: link.type == InterchangeType.paid
                ? _EdgeKind.transfer
                : _EdgeKind.walk,
            lineId: toLine,
            crowd: crowdEstimator.forLine(target, departAt).score,
            interchangeType: link.type,
            walkSeconds: link.walkMinutes * 60,
            note: link.type == InterchangeType.paid
                ? 'Change to ${target.name}'
                : 'Walk to ${to.name}',
          ),
        );
      }
    }
  }

  List<_Step>? _search(
    _Graph graph,
    PlanRequest request,
    PlannerWeights weights,
  ) {
    final best = <String, double>{originNode: 0};
    final previous = <String, _Step>{};
    final settled = <String>{};

    final queue = PriorityQueue<_QueueEntry>(
      (a, b) => a.cost.compareTo(b.cost),
    );
    queue.add(const _QueueEntry(node: originNode, cost: 0));

    while (queue.isNotEmpty) {
      final entry = queue.removeFirst();
      if (settled.contains(entry.node)) continue;
      settled.add(entry.node);
      if (entry.node == destinationNode) break;

      for (final edge in graph.edgesFrom(entry.node)) {
        if (request.avoidLineIds.contains(edge.lineId)) continue;
        if (weights.paidAreaOnly && edge.kind == _EdgeKind.walk) continue;

        if (entry.node == originNode &&
            edge.kind == _EdgeKind.board &&
            edge.boardStationId != request.originId) {
          continue;
        }

        if (edge.kind == _EdgeKind.alight &&
            edge.alightStationId != request.destinationId) {
          continue;
        }

        var cost = edge.seconds.toDouble();
        if (edge.kind == _EdgeKind.transfer) {
          cost += weights.transferPenaltySeconds;
        }
        if (edge.kind == _EdgeKind.walk) {
          cost += weights.walkPenaltySeconds;
        }
        if (edge.kind == _EdgeKind.ride) {
          cost += weights.crowdPenalty * edge.crowd * (edge.seconds / 600);
        }
        if (edge.kind == _EdgeKind.board || edge.kind == _EdgeKind.ride) {
          final line = network.line(edge.lineId);
          if (line != null && line.isIntercity) {
            cost += weights.farePenaltyPerRinggit *
                fareEngine.singleLineEstimate(line, edge.km) /
                10;
          }
        }

        final tentative = (best[entry.node] ?? double.infinity) + cost;
        if (tentative < (best[edge.to] ?? double.infinity)) {
          best[edge.to] = tentative;
          previous[edge.to] = _Step(from: entry.node, edge: edge);
          queue.add(_QueueEntry(node: edge.to, cost: tentative));
        }
      }
    }

    if (!previous.containsKey(destinationNode)) return null;

    final steps = <_Step>[];
    var cursor = destinationNode;
    var guard = 0;
    while (cursor != originNode) {
      final step = previous[cursor];
      if (step == null) return null;
      steps.add(step);
      cursor = step.from;
      if (++guard > 800) return null;
    }

    return steps.reversed.toList();
  }

  JourneyOption? _buildOption(List<_Step> steps, PlanRequest request) {
    final legs = <JourneyLeg>[];

    String? currentLine;
    String? rideStart;
    var rideVia = <String>[];
    var rideSeconds = 0;
    var rideKm = 0.0;
    var boardWait = 0;

    void flushRide(String endStationId) {
      if (currentLine == null || rideStart == null || rideVia.isEmpty) {
        currentLine = null;
        rideStart = null;
        rideVia = <String>[];
        rideSeconds = 0;
        rideKm = 0;
        return;
      }

      final line = network.line(currentLine!);
      if (line != null) {
        final fromIndex = line.indexOf(rideStart!);
        final toIndex = line.indexOf(endStationId);
        final towards = fromIndex >= 0 && toIndex >= 0
            ? line.terminusTowards(fromIndex, toIndex)
            : line.stationIds.last;

        legs.add(
          JourneyLeg.ride(
            lineId: line.id,
            fromStationId: rideStart!,
            toStationId: endStationId,
            viaStationIds: List<String>.from(rideVia),
            seconds: rideSeconds,
            km: double.parse(rideKm.toStringAsFixed(3)),
            towardsStationId: towards,
            waitSeconds: boardWait,
          ),
        );
      }

      currentLine = null;
      rideStart = null;
      rideVia = <String>[];
      rideSeconds = 0;
      rideKm = 0;
    }

    for (final step in steps) {
      final edge = step.edge;
      switch (edge.kind) {
        case _EdgeKind.board:
          currentLine = edge.lineId;
          rideStart = edge.boardStationId;
          boardWait = edge.seconds;
          rideVia = <String>[];
          rideSeconds = 0;
          rideKm = 0;
          break;

        case _EdgeKind.ride:
          rideVia.add(_stationOf(edge.to));
          rideSeconds += edge.seconds;
          rideKm += edge.km;
          break;

        case _EdgeKind.transfer:
          final stationId = _stationOf(step.from);
          flushRide(stationId);
          legs.add(
            JourneyLeg.transfer(
              stationId: _stationOf(edge.to),
              seconds: edge.seconds,
              type: edge.interchangeType ?? InterchangeType.paid,
              note: edge.note,
            ),
          );
          currentLine = edge.lineId;
          rideStart = _stationOf(edge.to);
          boardWait = edge.seconds;
          rideVia = <String>[];
          rideSeconds = 0;
          rideKm = 0;
          break;

        case _EdgeKind.walk:
          final fromStationId = _stationOf(step.from);
          final toStationId = _stationOf(edge.to);
          flushRide(fromStationId);
          legs.add(
            JourneyLeg.walk(
              fromStationId: fromStationId,
              toStationId: toStationId,
              seconds: edge.walkSeconds,
              km: edge.km,
              note: edge.note,
            ),
          );
          final wait = edge.seconds - edge.walkSeconds;
          if (wait > 0) {
            legs.add(
              JourneyLeg.transfer(
                stationId: toStationId,
                seconds: wait,
                type: InterchangeType.walk,
                note: 'Wait for the next service',
              ),
            );
          }
          currentLine = edge.lineId;
          rideStart = toStationId;
          boardWait = wait;
          rideVia = <String>[];
          rideSeconds = 0;
          rideKm = 0;
          break;

        case _EdgeKind.alight:
          flushRide(edge.alightStationId);
          break;
      }
    }

    final rides = legs.where((leg) => leg.kind == LegKind.ride).toList();
    if (rides.isEmpty) return null;

    final totalSeconds =
        legs.fold<int>(0, (sum, leg) => sum + leg.seconds) + boardWaitOf(legs);

    final enriched = legs.map((leg) {
      if (leg.kind != LegKind.ride) return leg;
      final line = network.line(leg.lineId);
      if (line == null) return leg;
      return leg.withCrowd(crowdEstimator.forLine(line, request.departAt));
    }).toList();

    final crowd = crowdEstimator.forLegs(enriched, request.departAt);
    final fare = fareEngine.compute(
      legs: enriched,
      card: request.card,
      passengerType: request.passengerType,
      passengers: request.passengers,
    );

    return JourneyOption(
      id: '${request.originId}-${request.destinationId}-'
          '${enriched.map((leg) => leg.lineId).join('-')}-$totalSeconds',
      legs: enriched,
      strategies: const {},
      totalSeconds: totalSeconds,
      crowd: crowd,
      fare: fare,
      departAt: request.departAt,
    );
  }

  int boardWaitOf(List<JourneyLeg> legs) {
    for (final leg in legs) {
      if (leg.kind == LegKind.ride) return leg.waitSeconds;
    }
    return 0;
  }

  static String _node(String stationId, String lineId) => '$stationId@$lineId';

  static String _stationOf(String node) {
    final index = node.indexOf('@');
    return index < 0 ? node : node.substring(0, index);
  }
}

enum _EdgeKind { board, ride, transfer, walk, alight }

class _Edge {
  final String to;
  final int seconds;
  final double km;
  final _EdgeKind kind;
  final String lineId;
  final double crowd;
  final String note;
  final String boardStationId;
  final String alightStationId;
  final int walkSeconds;
  final InterchangeType? interchangeType;

  const _Edge({
    required this.to,
    required this.seconds,
    required this.km,
    required this.kind,
    required this.lineId,
    required this.crowd,
    this.note = '',
    this.boardStationId = '',
    this.alightStationId = '',
    this.walkSeconds = 0,
    this.interchangeType,
  });
}

class _Graph {
  final Map<String, List<_Edge>> adjacency;

  const _Graph({required this.adjacency});

  List<_Edge> edgesFrom(String node) => adjacency[node] ?? const [];
}

class _Step {
  final String from;
  final _Edge edge;

  const _Step({required this.from, required this.edge});
}

class _QueueEntry {
  final String node;
  final double cost;

  const _QueueEntry({required this.node, required this.cost});
}
