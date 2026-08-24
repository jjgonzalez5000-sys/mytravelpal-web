import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../design/components.dart';
import '../design/theme_toggle.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../providers.dart';
import '../widgets/hotel_preferences.dart';
import '../widgets/location_search_field.dart';
import '../widgets/restaurant_preferences.dart';
import 'history_screen.dart';
import 'mark_event_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  GeocodeResult? _origin;
  GeocodeResult? _destination;
  DateTime _departure = _defaultDeparture();
  HotelPreferences _hotelPrefs = HotelPreferences.disabled;
  RestaurantPreferences _restaurantPrefs = RestaurantPreferences.disabled;
  bool _alertsEnabled = false;
  bool _tollAlternativeEnabled = false;
  bool _hourlyTollEnabled = false;
  bool _avoidMotorways = false;
  bool _preferScenic = false;
  bool _loading = false;
  String? _error;

  static DateTime _defaultDeparture() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 8);
  }

  Future<void> _pickDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );
    if (time == null) return;
    setState(() {
      _departure =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) {
      setState(() => _error = 'Pick an origin and a destination.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final request = TripPlanRequest(
        origin: origin.coordinate,
        destination: destination.coordinate,
        desiredDepartureAt: _departure,
        hotelMaxDetourMinutes:
            _hotelPrefs.enabled ? _hotelPrefs.maxDetourMinutes : null,
        hotelPriceBand: _hotelPrefs.enabled ? _hotelPrefs.priceBand : null,
        restaurantMaxDetourMinutes: _restaurantPrefs.enabled
            ? _restaurantPrefs.maxDetourMinutes
            : null,
        restaurantPriceBand:
            _restaurantPrefs.enabled ? _restaurantPrefs.priceBand : null,
        includeAdverseEvents: _alertsEnabled,
        includeTollAlternative: _tollAlternativeEnabled,
        includeHourlyTollAnalysis: _hourlyTollEnabled,
        avoidMotorways: _avoidMotorways,
        preferScenic: _preferScenic,
        tripProfile: ref.read(tripProfileProvider),
      );
      final response = await api.planTrip(request);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            request: request,
            origin: origin,
            destination: destination,
            response: response,
            desiredDepartureAt: _departure,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = 'API error ${e.statusCode}');
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('EEE, d MMM · HH:mm');

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              expandedHeight: 40,
              titleSpacing: Tokens.space20,
              title: Row(
                children: [
                  Icon(Icons.explore_outlined, color: scheme.primary),
                  const SizedBox(width: Tokens.space8),
                  Text('MyTravelPal', style: t.titleLarge),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Report an event',
                  icon: const Icon(Icons.add_alert_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MarkEventScreen(),
                    ),
                  ),
                ),
                const ThemeToggleButton(),
                IconButton(
                  tooltip: 'Saved trips',
                  icon: const Icon(Icons.bookmark_outline),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.space8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space20, Tokens.space8, Tokens.space20, Tokens.space32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hero
                  Text('THE PLANNER',
                      style: t.labelSmall?.copyWith(
                        color: scheme.tertiary, letterSpacing: 1.4,
                      )),
                  const SizedBox(height: Tokens.space8),
                  Text('Where are we going\ntoday?', style: t.displayMedium)
                      .animate()
                      .fadeIn(duration: Tokens.motionBase)
                      .moveY(begin: 8, end: 0, curve: Tokens.curveOut),
                  const SizedBox(height: Tokens.space8),
                  Text(
                    'Pick two points and a time. We handle the rest.',
                    style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Tokens.space16),
                  _ProfileChip(
                    profile: ref.watch(tripProfileProvider),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: Tokens.space24),

                  // Route card
                  SoftCard(
                    padding: const EdgeInsets.all(Tokens.space16),
                    child: Column(
                      children: [
                        LocationSearchField(
                          label: 'From',
                          geocode: api.geocode,
                          onSelected: (r) => setState(() => _origin = r),
                          initial: _origin,
                        ),
                        const SizedBox(height: Tokens.space12),
                        LocationSearchField(
                          label: 'To',
                          geocode: api.geocode,
                          onSelected: (r) => setState(() => _destination = r),
                          initial: _destination,
                        ),
                        const SizedBox(height: Tokens.space12),
                        _DepartureButton(
                          label: dateFmt.format(_departure),
                          onPressed: _pickDeparture,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 60.ms, duration: Tokens.motionBase),

                  const SizedBox(height: Tokens.space24),

                  // Preferences group
                  const SectionHeader(
                    title: 'Along the route',
                    eyebrow: 'Optional',
                  ),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space16,
                      vertical: Tokens.space8,
                    ),
                    child: Column(
                      children: [
                        HotelPreferencesSection(
                          value: _hotelPrefs,
                          onChanged: (v) => setState(() => _hotelPrefs = v),
                        ),
                        const Divider(height: Tokens.space16),
                        RestaurantPreferencesSection(
                          value: _restaurantPrefs,
                          onChanged: (v) => setState(() => _restaurantPrefs = v),
                        ),
                        const Divider(height: Tokens.space16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Alert me about adverse events',
                            style: t.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Fires, strikes, weather, roadworks, and more '
                              'within 25 km of the route.',
                              style: t.bodySmall,
                            ),
                          ),
                          value: _alertsEnabled,
                          onChanged: (v) => setState(() => _alertsEnabled = v),
                        ),
                        const Divider(height: Tokens.space16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Show toll-free alternative',
                            style: t.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Compare a route that skips tolls — money '
                              'saved vs. minutes added.',
                              style: t.bodySmall,
                            ),
                          ),
                          value: _tollAlternativeEnabled,
                          onChanged: (v) => setState(() {
                            _tollAlternativeEnabled = v;
                            if (!v) _hourlyTollEnabled = false;
                          }),
                        ),
                        if (_tollAlternativeEnabled) ...[
                          const Divider(height: Tokens.space16),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Hourly toll analysis',
                                    style: t.titleMedium,
                                  ),
                                ),
                                SoftBadge(
                                  label: 'Premium',
                                  color: scheme.tertiary,
                                  background: scheme.tertiaryContainer,
                                  borderColor:
                                      scheme.tertiary.withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'When during the day skipping tolls actually '
                                'beats keeping them (traffic-aware).',
                                style: t.bodySmall,
                              ),
                            ),
                            value: _hourlyTollEnabled,
                            onChanged: (v) =>
                                setState(() => _hourlyTollEnabled = v),
                          ),
                        ],
                        const Divider(height: Tokens.space16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Avoid motorways', style: t.titleMedium),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Slower and longer, but no tolls and quieter.',
                              style: t.bodySmall,
                            ),
                          ),
                          value: _avoidMotorways,
                          onChanged: (v) => setState(() => _avoidMotorways = v),
                        ),
                        const Divider(height: Tokens.space16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Prefer scenic', style: t.titleMedium),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Bias to more interesting roads. A little slower.',
                              style: t.bodySmall,
                            ),
                          ),
                          value: _preferScenic,
                          onChanged: (v) => setState(() => _preferScenic = v),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 120.ms, duration: Tokens.motionBase),

                  const SizedBox(height: Tokens.space24),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Tokens.space12),
                      child: SoftCard(
                        background: scheme.errorContainer,
                        borderColor: scheme.error.withValues(alpha: 0.4),
                        padding: const EdgeInsets.all(Tokens.space16),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: scheme.onErrorContainer),
                            const SizedBox(width: Tokens.space12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: t.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  PrimaryCta(
                    label: _loading ? 'Planning your trip…' : 'Plan trip',
                    icon: _loading ? null : Icons.arrow_forward,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: Tokens.space12),
                  Center(
                    child: Text(
                      'Countries are detected automatically from your route.',
                      style: t.bodySmall,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.profile, required this.onTap});

  final TripProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final hasProfile = profile != null;
    final children = <Widget>[
      Icon(
        hasProfile ? Icons.person_outline : Icons.person_add_alt_1,
        size: 18, color: scheme.onSurfaceVariant,
      ),
      const SizedBox(width: Tokens.space8),
      Expanded(
        child: hasProfile
            ? _profileSummary(profile!, t, scheme)
            : Text(
                'Set up your trip profile',
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
      ),
      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
    ];
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16, vertical: Tokens.space12,
      ),
      child: Row(children: children),
    );
  }

  Widget _profileSummary(TripProfile p, TextTheme t, ColorScheme scheme) {
    final bits = <String>[
      p.vehicle.type.label,
      p.vehicle.fuelType.label,
      if (p.travellers > 1) '${p.travellers} travellers',
      if (p.hasKids) 'kids',
      if (p.hasPets) 'pets',
    ];
    return Text(
      bits.join(' · '),
      style: t.bodyMedium?.copyWith(color: scheme.onSurface),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DepartureButton extends StatelessWidget {
  const _DepartureButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Desired departure'),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: scheme.onSurfaceVariant, size: 18),
            const SizedBox(width: Tokens.space12),
            Expanded(child: Text(label, style: t.bodyLarge)),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
