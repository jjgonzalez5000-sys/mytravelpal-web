import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../providers.dart';

/// Simplified Companion screen for passengers joining a group session.
///
/// Polls GET /v1/companion/session/{join_code} every 5 s and renders:
/// - Next stop name + ETA countdown
/// - Radar proximity alert (haptic + banner when radar_ahead_km < 0.5)
/// - Destination ETA
///
/// No GPS, no driving controls — read-only view of the driver's state.
class PassengerCompanionScreen extends ConsumerStatefulWidget {
  const PassengerCompanionScreen({super.key, required this.joinCode});
  final String joinCode;

  @override
  ConsumerState<PassengerCompanionScreen> createState() =>
      _PassengerCompanionScreenState();
}

class _PassengerCompanionScreenState
    extends ConsumerState<PassengerCompanionScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _radarAlertThresholdKm = 0.5;

  Timer? _pollTimer;
  Map<String, dynamic>? _state;
  bool _radarAlerted = false; // debounce: alert only when newly below threshold

  @override
  void initState() {
    super.initState();
    _pollTimer =
        Timer.periodic(_pollInterval, (_) => _poll());
    _poll(); // immediate first fetch
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final api = ref.read(apiClientWithPremiumProvider);
    final data = await api.getCompanionSession(widget.joinCode);
    if (data != null && mounted) {
      setState(() => _state = data);
      _checkRadar(data);
    }
  }

  void _checkRadar(Map<String, dynamic> data) {
    final radarKm =
        (data['radar_ahead_km'] as num?)?.toDouble();
    if (radarKm != null && radarKm < _radarAlertThresholdKm) {
      if (!_radarAlerted) {
        _radarAlerted = true;
        HapticFeedback.heavyImpact();
        // Second pulse after 500 ms for salience.
        Future<void>.delayed(const Duration(milliseconds: 500),
            HapticFeedback.heavyImpact);
      }
    } else {
      _radarAlerted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final data = _state;

    final nextStop = data?['next_stop_name'] as String?;
    final etaMin = (data?['eta_minutes'] as num?)?.toInt();
    final destName = data?['destination_name'] as String?;
    final destEtaMin = (data?['destination_eta_minutes'] as num?)?.toInt();
    final speedKmh =
        (data?['speed_kmh'] as num?)?.toDouble() ?? 0.0;
    final radarKm = (data?['radar_ahead_km'] as num?)?.toDouble();
    final radarClose =
        radarKm != null && radarKm < _radarAlertThresholdKm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Companion — Pasajero'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Tokens.space12),
            child: Chip(
              avatar: const Icon(Icons.wifi, size: 16),
              label: Text('Codigo: ${widget.joinCode}'),
              labelStyle: t.labelSmall,
            ),
          ),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Tokens.space20),
              children: [
                // Radar alert banner — prominent when camera close.
                if (radarClose)
                  _RadarBanner(radarKm: radarKm!),

                // Speed tile — minimal info for passengers.
                _StatTile(
                  icon: Icons.speed,
                  label: 'Velocidad conductor',
                  value: '${speedKmh.clamp(0, 300).toStringAsFixed(0)} km/h',
                  color: scheme.primary,
                ),
                const SizedBox(height: Tokens.space12),

                // Next stop card.
                if (nextStop != null)
                  _EtaCard(
                    icon: Icons.restaurant,
                    label: 'Proxima parada',
                    place: nextStop,
                    etaMinutes: etaMin,
                    color: scheme.secondary,
                  ),
                if (nextStop != null) const SizedBox(height: Tokens.space12),

                // Destination ETA card.
                if (destName != null)
                  _EtaCard(
                    icon: Icons.flag,
                    label: 'Destino',
                    place: destName,
                    etaMinutes: destEtaMin,
                    color: scheme.tertiary,
                  ),

                // Radar warning (non-critical range shown as info row).
                if (radarKm != null && !radarClose) ...[
                  const SizedBox(height: Tokens.space12),
                  _RadarInfoRow(radarKm: radarKm),
                ],

                const SizedBox(height: Tokens.space32),
                Text(
                  'Actualizando cada 5 s',
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: Tokens.space16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: t.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                Text(value,
                    style: t.headlineSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({
    required this.icon,
    required this.label,
    required this.place,
    required this.etaMinutes,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String place;
  final int? etaMinutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final eta = etaMinutes;
    final etaText = eta == null
        ? '--'
        : eta < 60
            ? '$eta min'
            : '${eta ~/ 60} h ${eta % 60} min';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: Tokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(place,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ETA',
                    style: t.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                Text(etaText,
                    style: t.titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarBanner extends StatelessWidget {
  const _RadarBanner({required this.radarKm});
  final double radarKm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.space12),
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.camera_alt, color: scheme.onError, size: 28),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Radar a ${(radarKm * 1000).toStringAsFixed(0)} m',
                  style: t.titleMedium?.copyWith(
                    color: scheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Reduce la velocidad',
                  style: t.bodySmall?.copyWith(color: scheme.onError),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarInfoRow extends StatelessWidget {
  const _RadarInfoRow({required this.radarKm});
  final double radarKm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final distText = radarKm < 1.0
        ? '${(radarKm * 1000).round()} m'
        : '${radarKm.toStringAsFixed(1)} km';
    return Row(
      children: [
        Icon(Icons.camera_alt_outlined,
            color: scheme.onSurfaceVariant, size: 20),
        const SizedBox(width: Tokens.space8),
        Text('Radar en $distText',
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
