import 'package:flutter/material.dart';
import '../api/models.dart';
import '../design/tokens.dart';

/// Shareable trip summary card. Render offscreen via RepaintBoundary,
/// then capture as PNG for sharing to Instagram / WhatsApp / X.
///
/// Sized to 1080x1350 (Instagram 4:5 portrait) at 3x pixel ratio
/// so it looks sharp on any screen.
class TripShareCard extends StatelessWidget {
  const TripShareCard({
    super.key,
    required this.originName,
    required this.destinationName,
    required this.response,
    required this.desiredDepartureAt,
  });

  final String originName;
  final String destinationName;
  final TripPlanResponse response;
  final DateTime desiredDepartureAt;

  static const _cardW = 1080.0;
  static const _cardH = 1350.0;
  static const _pixelRatio = 3.0;

  @override
  Widget build(BuildContext context) {
    final route = response.route;
    final days = response.days.length;
    final opt = response.optimizations;
    final fuelEur = opt?.fuelCost.totalCostEur ?? 0.0;
    final hours = (route.freeFlowMinutes / 60).floor();
    final mins = (route.freeFlowMinutes % 60).round();

    return SizedBox(
      width: _cardW / _pixelRatio,
      height: _cardH / _pixelRatio,
      child: Material(
        color: const Color(0xFF0E1117),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: logo + branding
              Row(children: [
                const Text('🧭', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                const Text('MyTravelPal',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${desiredDepartureAt.day}/${desiredDepartureAt.month}/${desiredDepartureAt.year}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ]),
              const SizedBox(height: 32),
              // Route title
              Text(originName,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 4),
              const Icon(Icons.arrow_downward, color: Colors.white30, size: 20),
              const SizedBox(height: 4),
              Text(destinationName,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 32),
              // Stats row
              Row(children: [
                _stat('${route.distanceKm.toStringAsFixed(0)} km', 'Distancia'),
                _stat('${hours}h ${mins}m', 'Duracion'),
                _stat('${fuelEur.toStringAsFixed(0)} €', 'Combustible'),
                if (days > 1) _stat('$days dias', 'Jornadas'),
              ]),
              // Day breakdown if multiday
              if (days > 1) ...[
                const SizedBox(height: 28),
                const Text('Etapas', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                ...response.days.take(4).map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Dia ${d.dayIndex}:  ${(d.toKm - d.fromKm).toStringAsFixed(0)} km'
                    + (d.toName != null ? ' · ${d.toName}' : ''),
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                )),
              ],
              const Spacer(),
              // Footer
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              const Row(children: [
                Icon(Icons.language, color: Colors.white38, size: 14),
                SizedBox(width: 4),
                Text('mytravelpal.io', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    ),
  );
}
