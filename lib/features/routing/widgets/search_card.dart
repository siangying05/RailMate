import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/station.dart';
import '../../../data/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/favourite_provider.dart';
import '../providers/journey_provider.dart';
import '../screens/station_picker_screen.dart';

class SearchCard extends StatefulWidget {
  final VoidCallback onSearch;

  const SearchCard({super.key, required this.onSearch});

  @override
  State<SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<SearchCard> {
  bool _showAdvanced = false;

  Future<void> _pick(BuildContext context, {required bool isOrigin}) async {
    final journey = context.read<JourneyProvider>();
    final exclude =
        isOrigin ? journey.destination?.id : journey.origin?.id;

    final station = await Navigator.of(context).push<Station>(
      MaterialPageRoute(
        builder: (_) => StationPickerScreen(
          title: isOrigin ? 'Departure station' : 'Destination station',
          excludeStationId: exclude,
        ),
      ),
    );

    if (station == null) return;
    if (isOrigin) {
      journey.setOrigin(station);
    } else {
      journey.setDestination(station);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journey = context.watch<JourneyProvider>();
    final profile = context.watch<AuthProvider>().profile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _StationField(
                        icon: Icons.trip_origin_rounded,
                        iconColour: theme.colorScheme.primary,
                        label: 'From',
                        value: journey.origin?.name,
                        placeholder: 'Select departure station',
                        onTap: () => _pick(context, isOrigin: true),
                      ),
                      const SizedBox(height: 10),
                      _StationField(
                        icon: Icons.place_rounded,
                        iconColour: AppColors.crowdHigh,
                        label: 'To',
                        value: journey.destination?.name,
                        placeholder: 'Select destination station',
                        onTap: () => _pick(context, isOrigin: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _SwapButton(onTap: journey.swap),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: journey.landmark,
              maxLength: Validators.maxLandmarkLength,
              decoration: InputDecoration(
                labelText: 'Landmark near your destination',
                hintText: 'e.g. Pavilion, Universiti Malaya',
                prefixIcon: const Icon(Icons.near_me_rounded),
                counterText: '',
                errorText: Validators.landmark(journey.landmark),
                helperMaxLines: 2,
                helperText:
                    'RailMate uses this to recommend the closest station exit',
              ),
              onChanged: context.read<JourneyProvider>().setLandmark,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    icon: Icons.calendar_today_rounded,
                    label: TimeUtils.relativeDay(journey.departureDate),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: journey.departureDate,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 30)),
                      );
                      if (picked != null && context.mounted) {
                        context
                            .read<JourneyProvider>()
                            .setDepartureDate(picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillButton(
                    icon: Icons.schedule_rounded,
                    label:
                        TimeUtils.formatMinutes(journey.departureMinutes),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: journey.departureTime,
                      );
                      if (picked != null && context.mounted) {
                        context
                            .read<JourneyProvider>()
                            .setDepartureTime(picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _PillButton(
                  icon: Icons.bolt_rounded,
                  label: 'Now',
                  onTap: context.read<JourneyProvider>().useNow,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preference in RoutePreference.values)
                  ChoiceChip(
                    label: Text(preference.label),
                    selected: journey.preference == preference,
                    onSelected: (_) => context
                        .read<JourneyProvider>()
                        .setPreference(preference),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
              icon: Icon(
                _showAdvanced
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
              ),
              label: Text(
                _showAdvanced ? 'Hide ticket options' : 'Ticket options',
              ),
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 6),
              Text(
                'Fare card',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final card in FareCard.values)
                    ChoiceChip(
                      label: Text(card.label),
                      selected: journey.card == card,
                      onSelected: (_) =>
                          context.read<JourneyProvider>().setCard(card),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Stepper(
                      label: 'Passengers',
                      value: journey.passengers,
                      min: 1,
                      max: 6,
                      onChanged: context.read<JourneyProvider>().setPassengers,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stepper(
                      label: 'Max transfers',
                      value: journey.maxTransfers,
                      min: 0,
                      max: 5,
                      onChanged:
                          context.read<JourneyProvider>().setMaxTransfers,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Concession applied from your profile: '
                '${profile.passengerType.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (journey.formError != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      journey.formError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onSearch,
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('Find routes'),
                  ),
                ),
                if (journey.origin != null && journey.destination != null) ...[
                  const SizedBox(width: 10),
                  _SaveRouteButton(
                    origin: journey.origin!,
                    destination: journey.destination!,
                    landmark: journey.landmark,
                    departureMinutes: journey.departureMinutes,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveRouteButton extends StatelessWidget {
  final Station origin;
  final Station destination;
  final String landmark;
  final int departureMinutes;

  const _SaveRouteButton({
    required this.origin,
    required this.destination,
    required this.landmark,
    required this.departureMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favourites = context.watch<FavouriteProvider>();
    final saved = favourites.isSaved(origin.id, destination.id);

    return Tooltip(
      message: saved ? 'Remove from saved routes' : 'Save this route',
      child: IconButton.filledTonal(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final message = await context.read<FavouriteProvider>().toggle(
                origin: origin,
                destination: destination,
                landmark: landmark,
                preferredDepartureMinutes: departureMinutes,
              );
          messenger.showSnackBar(SnackBar(content: Text(message)));
        },
        icon: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: saved ? theme.colorScheme.primary : null,
        ),
      ),
    );
  }
}

class _StationField extends StatelessWidget {
  final IconData icon;
  final Color iconColour;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _StationField({
    required this.icon,
    required this.iconColour,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColour),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hasValue
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SwapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 96,
          child: Icon(
            Icons.swap_vert_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
              ),
              Text(
                '$value',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
