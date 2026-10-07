import 'dart:async';

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Compact progress card shown between the map/hero and the day plan
/// while the `/plan/enrich` request is in flight. Replaces per-section
/// skeletons + the wrong "activa hoteles..." empty-state that used to
/// flash for a request that IS going to bring hotels a few seconds
/// later.
///
/// Above the chip row we now also render a tailored rotating pulse
/// line ("Ahora mismo..." / "Right now...") that cycles through the
/// concrete search operations we're actually running for this trip:
/// hotels, restaurants, fuel arbitrage, toll skips, weather, adverse
/// event corridor, plus profile-specific extras (playgrounds when
/// travelling with kids, pet areas, camper facilities, and the user's
/// vehicle tank size). The messages are ALL real work happening
/// during enrichment — the rotation is just so the user perceives
/// the intelligence instead of a generic spinner.
///
/// Rendering rules:
/// - Only shows chips for categories the user actually requested
///   (hotel prefs on / restaurant prefs on / etc). If a category isn't
///   requested, it doesn't add noise.
/// - Each chip transitions from spinner → check when its data lands.
/// - The whole card auto-fades and slides out when `pending` flips
///   false (all categories done).
class EnrichmentProgress extends StatefulWidget {
  const EnrichmentProgress({
    super.key,
    required this.pending,
    required this.hotelsRequested,
    required this.restaurantsRequested,
    required this.adverseRequested,
    required this.hasHotels,
    required this.hasRestaurants,
    required this.hasFuel,
    required this.hasWeather,
    required this.hasAdverse,
    this.profileHasKids = false,
    this.profileHasPets = false,
    this.profileIsCamper = false,
    this.vehicleLabel,
    this.vehicleTankL,
    this.vehicleIsEv = false,
  });

  /// True while the enrich future is still in flight. When false the
  /// card fades out over 300 ms then removes itself from the tree.
  final bool pending;

  final bool hotelsRequested;
  final bool restaurantsRequested;
  final bool adverseRequested;

  final bool hasHotels;
  final bool hasRestaurants;
  final bool hasFuel;
  final bool hasWeather;
  final bool hasAdverse;

  /// Profile flags — drive the tailored pulse messages. Passing them
  /// as opt-in booleans keeps the widget free of a hard dependency on
  /// TripProfile (some call-sites don't have one).
  final bool profileHasKids;
  final bool profileHasPets;
  final bool profileIsCamper;

  /// Display label for the vehicle (e.g. "Toyota Yaris 4 HEV"). If
  /// null, the vehicle pulse line is dropped.
  final String? vehicleLabel;

  /// Tank size in litres (or battery in kWh for EVs).
  final double? vehicleTankL;

  /// True when the vehicle is electric — shows "kWh de batería" instead of "L".
  final bool vehicleIsEv;

  @override
  State<EnrichmentProgress> createState() => _EnrichmentProgressState();
}

class _EnrichmentProgressState extends State<EnrichmentProgress> {
  Timer? _rotator;
  int _pulseIndex = 0;

  static const Duration _pulsePeriod = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _rotator = Timer.periodic(_pulsePeriod, (_) {
      if (!mounted) return;
      setState(() => _pulseIndex += 1);
    });
  }

  @override
  void dispose() {
    _rotator?.cancel();
    super.dispose();
  }

  List<_PulseMessage> _pulses(AppLocalizations l) {
    final out = <_PulseMessage>[
      if (widget.hotelsRequested)
        _PulseMessage(Icons.hotel_outlined, l.enrichPulseHotels),
      if (widget.restaurantsRequested)
        _PulseMessage(Icons.restaurant_outlined, l.enrichPulseRestaurants),
      _PulseMessage(Icons.local_gas_station_outlined, l.enrichPulseFuel),
      _PulseMessage(Icons.toll_outlined, l.enrichPulseTolls),
      _PulseMessage(Icons.access_time, l.enrichPulseWindows),
      _PulseMessage(Icons.wb_cloudy_outlined, l.enrichPulseWeather),
      if (widget.adverseRequested)
        _PulseMessage(Icons.warning_amber_outlined, l.enrichPulseAdverse),
      if (widget.profileHasKids)
        _PulseMessage(Icons.child_care_outlined, l.enrichPulseKids),
      if (widget.profileHasPets)
        _PulseMessage(Icons.pets_outlined, l.enrichPulsePets),
      if (widget.profileIsCamper)
        _PulseMessage(Icons.rv_hookup, l.enrichPulseCamper),
    ];
    final vehicle = widget.vehicleLabel;
    final tank = widget.vehicleTankL;
    if (vehicle != null && vehicle.isNotEmpty && tank != null) {
      final tankStr = tank.round().toString();
      final label = widget.vehicleIsEv
          ? l.enrichPulseVehicleEv(vehicle, tankStr)
          : l.enrichPulseVehicle(vehicle, tankStr);
      out.add(_PulseMessage(Icons.directions_car_outlined, label));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Build the chip list dynamically — only for requested categories.
    // Fuel + weather are always requested (they always appear in the
    // response when the backend has data; there's no per-user opt-out
    // in the plan form yet). Adverse is gated by an explicit flag.
    final chips = <_EnrichChipData>[
      if (widget.hotelsRequested)
        _EnrichChipData(
          icon: Icons.hotel_outlined,
          label: l.enrichmentChipHotels,
          done: widget.hasHotels,
        ),
      if (widget.restaurantsRequested)
        _EnrichChipData(
          icon: Icons.restaurant_outlined,
          label: l.enrichmentChipRestaurants,
          done: widget.hasRestaurants,
        ),
      _EnrichChipData(
        icon: Icons.local_gas_station_outlined,
        label: l.enrichmentChipFuel,
        done: widget.hasFuel,
      ),
      _EnrichChipData(
        icon: Icons.wb_cloudy_outlined,
        label: l.enrichmentChipWeather,
        done: widget.hasWeather,
      ),
      if (widget.adverseRequested)
        _EnrichChipData(
          icon: Icons.warning_amber_outlined,
          label: l.enrichmentChipAdverse,
          done: widget.hasAdverse,
        ),
    ];

    final pulses = _pulses(l);
    final current = pulses.isEmpty
        ? null
        : pulses[_pulseIndex % pulses.length];

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: widget.pending ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: widget.pending
            ? Card(
                elevation: 0,
                color: scheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusLg),
                  side: BorderSide(color: scheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.space16,
                    Tokens.space12,
                    Tokens.space16,
                    Tokens.space12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: Tokens.space12),
                          Expanded(
                            child: Text(
                              l.enrichmentLoadingTitle,
                              style: t.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Tokens.space8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: scheme.primary,
                        ),
                      ),
                      if (current != null) ...[
                        const SizedBox(height: Tokens.space12),
                        _PulseLine(
                          header: l.enrichPulseHeader,
                          message: current,
                        ),
                      ],
                      const SizedBox(height: Tokens.space12),
                      Wrap(
                        spacing: Tokens.space8,
                        runSpacing: Tokens.space8,
                        children: [
                          for (final c in chips) _EnrichChip(data: c),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _PulseMessage {
  const _PulseMessage(this.icon, this.text);
  final IconData icon;
  final String text;
}

/// The rotating "Ahora mismo..." row. Uses AnimatedSwitcher with a
/// short cross-fade so the change reads as a soft pulse rather than
/// a jump. Kept intentionally compact (single line, ellipsis) so
/// long translations don't shove the chips down.
class _PulseLine extends StatelessWidget {
  const _PulseLine({required this.header, required this.message});
  final String header;
  final _PulseMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          header,
          style: t.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Row(
              key: ValueKey(message.text),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(message.icon, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EnrichChipData {
  const _EnrichChipData({
    required this.icon,
    required this.label,
    required this.done,
  });
  final IconData icon;
  final String label;
  final bool done;
}

class _EnrichChip extends StatelessWidget {
  const _EnrichChip({required this.data});
  final _EnrichChipData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = data.done;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(
          color: done ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : data.icon,
            size: 14,
            color: done ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: done ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
