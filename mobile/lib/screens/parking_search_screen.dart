import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../widgets/location_search_field.dart';

/// Standalone parking search. Entry point for "I'm going to an
/// event and need to park my car" — pick destination, get a
/// distance-sorted list of parkings within the search radius, tap
/// one to open Google Maps for navigation.
///
/// Also reused inside the plan flow: `PlanScreen` navigates here
/// with `initialQuery` pre-filled from a waypoint the driver
/// marked as "necesito parking aquí".
class ParkingSearchScreen extends ConsumerStatefulWidget {
  const ParkingSearchScreen({super.key, this.initialQuery});

  final GeocodeResult? initialQuery;

  @override
  ConsumerState<ParkingSearchScreen> createState() =>
      _ParkingSearchScreenState();
}

class _ParkingSearchScreenState
    extends ConsumerState<ParkingSearchScreen> {
  GeocodeResult? _query;
  double _radiusKm = 2.0;
  bool _loading = false;
  String? _error;
  List<Parking> _results = const [];
  ParkingFilters _filters = const ParkingFilters();

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    // Auto-check kid_friendly / dogs filters when the profile
    // says the driver travels with kids / pets. User can uncheck
    // if they want the wider result set.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = ref.read(tripProfileProvider);
      setState(() {
        _filters = ParkingFilters(
          kidFriendly: profile?.hasKids ?? false,
          dogs: profile?.hasPets ?? false,
        );
      });
      if (_query != null) _search();
    });
  }

  Future<void> _search() async {
    final q = _query;
    if (q == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final results = await api.searchParking(
        lat: q.coordinate.lat,
        lon: q.coordinate.lon,
        radiusKm: _radiusKm,
        limit: 20,
        filters: _filters,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(context).planErrorNetwork,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _amenityChip({
    required IconData icon,
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          avatar: Icon(icon, size: 16),
          label: Text(label),
          selected: selected,
          onSelected: onChanged,
        ),
      );

  Future<void> _openInMaps(Parking p) async {
    // Geo pin at the exact coord with the parking name as label —
    // never a name search (parking names collide across cities).
    final label = Uri.encodeComponent(p.name.trim());
    final uri = Uri.parse(
      'geo:${p.coordinate.lat},${p.coordinate.lon}'
      '?q=${p.coordinate.lat},${p.coordinate.lon}($label)',
    );
    try {
      final ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${p.coordinate.lat},${p.coordinate.lon}',
        'center': '${p.coordinate.lat},${p.coordinate.lon}',
        'zoom': '17',
      }),
      mode: LaunchMode.platformDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.parkingSearchTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocationSearchField(
                label: l.parkingSearchLabel,
                geocode: ref.read(apiClientWithPremiumProvider).geocode,
                initial: _query,
                onSelected: (r) {
                  if (r == null) return;
                  setState(() => _query = r);
                  _search();
                },
              ),
              const SizedBox(height: Tokens.space8),
              // Amenity chips. Kid + dogs auto-checked from profile.
              // Filter is "true-only" — unknowns pass through, so
              // a chip only DROPS parkings tagged explicitly as
              // not having that amenity. Rebuilds re-run search
              // on every toggle.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _amenityChip(
                      icon: Icons.child_friendly,
                      label: l.parkingFilterKids,
                      selected: _filters.kidFriendly,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(kidFriendly: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.pets,
                      label: l.parkingFilterDogs,
                      selected: _filters.dogs,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(dogs: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.wc,
                      label: l.parkingFilterToilets,
                      selected: _filters.toilets,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(toilets: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.restaurant,
                      label: l.parkingFilterFood,
                      selected: _filters.food,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(food: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.shower,
                      label: l.parkingFilterShowers,
                      selected: _filters.showers,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(showers: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.electric_car,
                      label: l.parkingFilterEv,
                      selected: _filters.ev,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(ev: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.local_gas_station,
                      label: l.parkingFilterFuel,
                      selected: _filters.fuel,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(fuel: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.rv_hookup,
                      label: l.parkingFilterRv,
                      selected: _filters.rv,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(rv: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.local_shipping,
                      label: l.parkingFilterTruck,
                      selected: _filters.truck,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(truck: v));
                        _search();
                      },
                    ),
                    _amenityChip(
                      icon: Icons.accessible,
                      label: l.parkingFilterWheelchair,
                      selected: _filters.wheelchair,
                      onChanged: (v) {
                        setState(() =>
                            _filters = _filters.copyWith(wheelchair: v));
                        _search();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space8),
              Row(
                children: [
                  Text(l.parkingRadiusLabel, style: t.labelMedium),
                  Expanded(
                    child: Slider(
                      value: _radiusKm,
                      min: 0.5,
                      max: 10.0,
                      divisions: 19,
                      label: '${_radiusKm.toStringAsFixed(1)} km',
                      onChanged: (v) => setState(() => _radiusKm = v),
                      onChangeEnd: (_) => _search(),
                    ),
                  ),
                  Text(
                    '${_radiusKm.toStringAsFixed(1)} km',
                    style: t.labelMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: t.bodyMedium?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  _query == null
                                      ? l.parkingSearchHint
                                      : l.parkingNoResults,
                                  style: t.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: _results.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) => _ParkingTile(
                                  parking: _results[i],
                                  onTap: () => _openInMaps(_results[i]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingTile extends StatelessWidget {
  const _ParkingTile({required this.parking, required this.onTap});
  final Parking parking;
  final VoidCallback onTap;

  IconData _kindIcon() => switch (parking.kind) {
        'garage' => Icons.local_parking,
        'park_and_ride' => Icons.directions_bus,
        _ => Icons.local_parking_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final chips = <Widget>[];
    if (parking.priceEurPerHour != null) {
      chips.add(_Chip(
        icon: Icons.euro,
        label: '${parking.priceEurPerHour!.toStringAsFixed(2)}/h',
      ));
    } else {
      chips.add(_Chip(icon: Icons.help_outline, label: l.parkingPriceUnknown));
    }
    if (parking.covered == true) {
      chips.add(_Chip(icon: Icons.house_outlined, label: l.parkingCovered));
    }
    if (parking.maxStayHours != null) {
      chips.add(_Chip(
        icon: Icons.timer_outlined,
        label: '${parking.maxStayHours!.toStringAsFixed(0)} h',
      ));
    }
    if (parking.capacity != null) {
      chips.add(_Chip(
        icon: Icons.local_parking,
        label: '${parking.capacity} plazas',
      ));
    }
    // Amenity chips — show only True amenities to avoid cluttering
    // with negatives / unknowns.
    if (parking.kidFriendly == true) {
      chips.add(_Chip(icon: Icons.child_friendly, label: l.parkingFilterKids));
    }
    if (parking.dogsAllowed == true) {
      chips.add(_Chip(icon: Icons.pets, label: l.parkingFilterDogs));
    }
    if (parking.toilets == true) {
      chips.add(_Chip(icon: Icons.wc, label: l.parkingFilterToilets));
    }
    if (parking.foodNearby == true) {
      chips.add(_Chip(icon: Icons.restaurant, label: l.parkingFilterFood));
    }
    if (parking.evCharging == true) {
      chips.add(_Chip(icon: Icons.electric_car, label: l.parkingFilterEv));
    }
    if (parking.fuelStation == true) {
      chips.add(_Chip(icon: Icons.local_gas_station, label: l.parkingFilterFuel));
    }
    if (parking.showers == true) {
      chips.add(_Chip(icon: Icons.shower, label: l.parkingFilterShowers));
    }
    if (parking.wheelchairAccess == true) {
      chips.add(_Chip(icon: Icons.accessible, label: l.parkingFilterWheelchair));
    }
    if (parking.rvFriendly == true) {
      chips.add(_Chip(icon: Icons.rv_hookup, label: l.parkingFilterRv));
    }
    if (parking.truckFriendly == true) {
      chips.add(_Chip(icon: Icons.local_shipping, label: l.parkingFilterTruck));
    }
    return ListTile(
      leading: Icon(_kindIcon(), color: scheme.primary),
      title: Text(parking.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Text(
              '${(parking.distanceFromQueryKm * 1000).round()} m',
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Tokens.space8),
            Expanded(
              child: Wrap(
                spacing: 6, runSpacing: 4,
                children: chips,
              ),
            ),
          ],
        ),
      ),
      trailing: const Icon(Icons.navigation),
      onTap: onTap,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
