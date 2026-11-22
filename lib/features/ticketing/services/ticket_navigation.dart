import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../data/models/journey.dart';
import '../../../data/models/ticket.dart';
import '../../guidance/providers/guidance_provider.dart';
import '../../guidance/screens/live_navigation_screen.dart';
import '../../guidance/services/guidance_builder.dart';
import '../../routing/providers/journey_provider.dart';

/// Gets a rider from a [Ticket] into [LiveNavigationScreen] - the live,
/// in-transit map and leg-by-leg progress view - whether they just finished
/// paying (fresh from [TicketScreen]) or are coming back to an active
/// ticket later (from [MyTripsScreen], possibly after the app was killed
/// mid-journey).
///
/// [GuidanceProvider.attach] only ever lives in memory, so there is no
/// persisted [JourneyOption] to restore - this re-runs the same search that
/// produced the ticket and re-attaches guidance to whichever option comes
/// back, rather than trying to replay the exact original one. If the
/// already-selected journey in [JourneyProvider] already matches this
/// ticket's origin and destination (the common case: tapping straight
/// through from checkout), it's reused as-is instead of searching again.
Future<void> openNavigationForTicket(BuildContext context, Ticket ticket) async {
  final data = context.read<RailDataProvider>();
  final journey = context.read<JourneyProvider>();
  final guidanceProvider = context.read<GuidanceProvider>();

  final alreadySelected = journey.selected;
  final matchesTicket = alreadySelected != null &&
      alreadySelected.originId == ticket.originId &&
      alreadySelected.destinationId == ticket.destinationId &&
      guidanceProvider.guidance != null;

  JourneyOption? option = matchesTicket ? alreadySelected : null;

  if (!matchesTicket) {
    final origin = data.network.station(ticket.originId);
    final destination = data.network.station(ticket.destinationId);
    if (origin == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't rebuild this route - one of the stations is missing "
            'from the current network data.',
          ),
        ),
      );
      return;
    }

    journey.applyPair(origin, destination);
    journey.setPassengerType(ticket.passengerType);
    journey.setCard(ticket.fareCard);
    journey.setPassengers(ticket.passengers);

    final ok = await journey.search(
      planner: data.planner,
      crowdEstimator: data.crowdEstimator,
      userId: ticket.userId,
    );

    if (!context.mounted) return;

    if (!ok || journey.selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journey.message ?? "Couldn't recompute this route right now.",
          ),
        ),
      );
      return;
    }

    guidanceProvider.attach(
      journey.selected!,
      GuidanceBuilder(
        network: data.network,
        platforms: data.platformDirectory,
        crowdEstimator: data.crowdEstimator,
      ),
    );
    option = journey.selected;
  }

  if (!context.mounted || option == null) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LiveNavigationScreen(option: option!, ticket: ticket),
    ),
  );
}
