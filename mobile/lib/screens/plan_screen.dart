import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../providers.dart';
import '../widgets/hotel_preferences.dart';
import '../widgets/location_search_field.dart';
import '../widgets/restaurant_preferences.dart';
import 'history_screen.dart';
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
    final dateFmt = DateFormat('EEE, d MMM y — HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan a road trip'),
        actions: [
          IconButton(
            tooltip: 'Saved trips',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Origin', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LocationSearchField(
              label: 'From',
              geocode: api.geocode,
              onSelected: (r) => setState(() => _origin = r),
              initial: _origin,
            ),
            const SizedBox(height: 24),
            Text('Destination', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LocationSearchField(
              label: 'To',
              geocode: api.geocode,
              onSelected: (r) => setState(() => _destination = r),
              initial: _destination,
            ),
            const SizedBox(height: 24),
            Text('Desired departure',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDeparture,
              icon: const Icon(Icons.event),
              label: Text(dateFmt.format(_departure)),
            ),
            const SizedBox(height: 24),
            HotelPreferencesSection(
              value: _hotelPrefs,
              onChanged: (v) => setState(() => _hotelPrefs = v),
            ),
            const SizedBox(height: 8),
            RestaurantPreferencesSection(
              value: _restaurantPrefs,
              onChanged: (v) => setState(() => _restaurantPrefs = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alert me about adverse events'),
              subtitle: const Text(
                'Fires, strikes, adverse weather, roadworks, accidents, '
                'floods, snow, protests within 25 km of the route.',
              ),
              value: _alertsEnabled,
              onChanged: (v) => setState(() => _alertsEnabled = v),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route),
              label: Text(_loading ? 'Planning…' : 'Plan trip'),
            ),
            const SizedBox(height: 16),
            Text(
              'Countries crossed are inferred automatically from the '
              'origin and destination you pick.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
