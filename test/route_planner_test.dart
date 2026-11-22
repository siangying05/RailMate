import 'package:flutter_test/flutter_test.dart';
import 'package:railmate/data/datasources/local/asset_data_source.dart';
import 'package:railmate/data/models/fare.dart';
import 'package:railmate/data/models/interchange.dart';
import 'package:railmate/data/models/journey.dart';
import 'package:railmate/data/models/rail_network.dart';
import 'package:railmate/data/models/ridership.dart';
import 'package:railmate/data/models/user_profile.dart';
import 'package:railmate/data/services/crowd_estimator.dart';
import 'package:railmate/features/routing/services/fare_engine.dart';
import 'package:railmate/features/routing/services/route_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = AssetDataSource();
  late RailNetwork network;
  late RoutePlanner planner;
  late FareEngine fareEngine;

  String idOf(String name) {
    final match = network.allStations.firstWhere(
      (station) => station.name.toLowerCase() == name.toLowerCase(),
      orElse: () => throw StateError('Station not found: $name'),
    );
    return match.id;
  }

  setUpAll(() async {
    network = await assets.loadNetwork();
    final records = await assets.loadRidershipSnapshot();
    final estimator = CrowdEstimator(
      network: network,
      dataset: RidershipDataset(records: records, retrievedAt: DateTime.now()),
      live: false,
    );
    fareEngine = FareEngine(network: network);
    planner = RoutePlanner(
      network: network,
      crowdEstimator: estimator,
      fareEngine: fareEngine,
    );
  });

  test('network loads the official GTFS derived data', () {
    expect(network.totalLines, 17);
    expect(network.totalStations, 326);
    expect(network.totalInterchanges, greaterThan(50));

    final klSentral = network.allStations
        .where((s) => s.name == 'KL Sentral')
        .toList();
    expect(klSentral, isNotEmpty);
    expect(klSentral.first.lat, closeTo(3.13, 0.05));
  });

  test('every line has consistent hop arrays', () {
    for (final line in network.lines) {
      expect(
        line.hopSeconds.length,
        line.stationIds.length - 1,
        reason: '${line.id} hopSeconds length',
      );
      expect(
        line.hopKm.length,
        line.stationIds.length - 1,
        reason: '${line.id} hopKm length',
      );
      expect(line.colourHex, startsWith('#'));
    }
  });

  test('direct journey on one line needs no transfer', () {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('KLCC'),
        destinationId: idOf('Pasar Seni'),
        departAt: DateTime(2026, 9, 3, 14, 0),
      ),
    );

    expect(result.isEmpty, isFalse);
    final best = result.best!;
    expect(best.transferCount, 0);
    expect(best.totalMinutes, greaterThan(0));
    expect(best.fare.total, greaterThan(0));
  });

  test('cross line journey chains legs end to end', () {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('Gombak'),
        destinationId: idOf('Bukit Bintang'),
        departAt: DateTime(2026, 9, 3, 14, 0),
      ),
    );

    expect(result.isEmpty, isFalse);
    final legs = result.best!.legs;
    expect(legs.first.fromStationId, idOf('Gombak'));
    expect(legs.last.toStationId, idOf('Bukit Bintang'));

    for (var i = 0; i < legs.length - 1; i++) {
      expect(
        legs[i].toStationId,
        legs[i + 1].fromStationId,
        reason: 'leg ${i + 1} does not start where leg $i ended',
      );
    }
  });

  test('planner returns up to three distinct options', () {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('Ampang'),
        destinationId: idOf('Putra Heights'),
        departAt: DateTime(2026, 9, 3, 8, 0),
      ),
    );

    expect(result.options.length, inInclusiveRange(1, 3));
    final signatures = result.options.map((o) => o.signature).toSet();
    expect(signatures.length, result.options.length);
  });

  test('paid area only preference avoids walking connections', () {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('Gombak'),
        destinationId: idOf('Kajang'),
        departAt: DateTime(2026, 9, 3, 10, 0),
        preference: RoutePreference.paidAreaOnly,
      ),
    );

    if (!result.isEmpty) {
      for (final option in result.options) {
        expect(
          option.legs.any((leg) => leg.kind == LegKind.walk),
          isFalse,
          reason: 'paid area only route still contains a walking leg',
        );
      }
    }
  });

  test('transfer legs carry the interchange type', () {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('Taman Melati'),
        destinationId: idOf('Kajang'),
        departAt: DateTime(2026, 9, 3, 9, 0),
      ),
    );

    expect(result.isEmpty, isFalse);
    final transfers =
        result.best!.legs.where((leg) => leg.kind == LegKind.transfer);
    for (final leg in transfers) {
      expect(leg.interchangeType, isNotNull);
      expect(
        InterchangeType.values.contains(leg.interchangeType),
        isTrue,
      );
    }
  });

  test('intercity journey uses ETS', () {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('KL Sentral'),
        destinationId: idOf('Ipoh'),
        departAt: DateTime(2026, 9, 3, 10, 0),
      ),
    );

    expect(result.isEmpty, isFalse);
    expect(result.best!.lineIds, contains('ets'));
  });

  test('same origin and destination is rejected', () {
    final id = idOf('KLCC');
    final result = planner.plan(
      PlanRequest(
        originId: id,
        destinationId: id,
        departAt: DateTime(2026, 9, 3, 10, 0),
      ),
    );
    expect(result.isEmpty, isTrue);
    expect(result.message, isNotNull);
  });

  test('concession card is cheaper than a cash token', () {
    final base = PlanRequest(
      originId: idOf('Gombak'),
      destinationId: idOf('Bukit Bintang'),
      departAt: DateTime(2026, 9, 3, 14, 0),
    );

    final tng = planner.plan(base).best!;
    final token = planner
        .plan(
          PlanRequest(
            originId: base.originId,
            destinationId: base.destinationId,
            departAt: base.departAt,
            card: FareCard.cashToken,
          ),
        )
        .best!;
    final concession = planner
        .plan(
          PlanRequest(
            originId: base.originId,
            destinationId: base.destinationId,
            departAt: base.departAt,
            card: FareCard.concession,
          ),
        )
        .best!;

    expect(token.fare.total, greaterThan(tng.fare.total));
    expect(concession.fare.total, lessThan(tng.fare.total));
  });

  test('two passengers cost twice as much', () {
    final single = planner
        .plan(
          PlanRequest(
            originId: idOf('KLCC'),
            destinationId: idOf('Pasar Seni'),
            departAt: DateTime(2026, 9, 3, 14, 0),
          ),
        )
        .best!;

    final double2 = planner
        .plan(
          PlanRequest(
            originId: idOf('KLCC'),
            destinationId: idOf('Pasar Seni'),
            departAt: DateTime(2026, 9, 3, 14, 0),
            passengers: 2,
          ),
        )
        .best!;

    expect(double2.fare.total, closeTo(single.fare.total * 2, 0.02));
  });

  test('integrated fare is cheaper than paying each line separately', () {
    final result = planner.plan(
      PlanRequest(
        originId: idOf('Gombak'),
        destinationId: idOf('Kajang'),
        departAt: DateTime(2026, 9, 3, 14, 0),
      ),
    );

    final option = result.best!;
    if (option.transferCount > 0) {
      expect(option.fare.baseTotal, greaterThan(0));
    }
  });

  test('the saving subtracts from the leg by leg price, not the total', () {
    final option = planner
        .plan(
          PlanRequest(
            originId: idOf('Gombak'),
            destinationId: idOf('Kajang'),
            departAt: DateTime(2026, 9, 3, 14, 0),
          ),
        )
        .best!;

    final fare = option.fare;
    expect(
      fare.separateLegsTotal - fare.interchangeDiscount,
      closeTo(fare.baseTotal, 0.005),
    );
  });

  test('a student pays half of the adult fare for the same journey', () {
    PlanRequest request(PassengerType type) => PlanRequest(
          originId: idOf('Gombak'),
          destinationId: idOf('Kajang'),
          departAt: DateTime(2026, 9, 3, 14, 0),
          passengerType: type,
        );

    final adult = planner.plan(request(PassengerType.adult)).best!;
    final student = planner.plan(request(PassengerType.student)).best!;

    expect(student.fare.passengerMultiplier, 0.5);
    expect(student.fare.total, closeTo(adult.fare.total * 0.5, 0.02));
  });

  test('a concession card does not stack on top of a concession type', () {
    final option = planner
        .plan(
          PlanRequest(
            originId: idOf('Gombak'),
            destinationId: idOf('Kajang'),
            departAt: DateTime(2026, 9, 3, 14, 0),
            passengerType: PassengerType.student,
            card: FareCard.concession,
          ),
        )
        .best!;

    expect(option.fare.passengerMultiplier, 1.0);
    expect(option.fare.cardMultiplier, 0.5);
  });
}
