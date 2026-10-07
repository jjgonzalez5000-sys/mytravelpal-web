import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../storage/app_prefs.dart';
import '../storage/trip_storage.dart';

/// Compact card shown at the top of Settings that shows how well
/// the AI knows the user (0–100 %). Tapping expands a breakdown
/// of each contributing factor and what would improve it.
class AiLearningBar extends ConsumerStatefulWidget {
  const AiLearningBar({super.key});

  @override
  ConsumerState<AiLearningBar> createState() => _AiLearningBarState();
}

class _AiLearningBarState extends ConsumerState<AiLearningBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final prefs = ref.watch(appPrefsProvider);
    final storage = ref.read(tripStorageProvider);

    return FutureBuilder<int>(
      future: storage.list().then((trips) => trips.length),
      builder: (context, snapshot) {
        final tripCount = snapshot.data ?? 0;
        final factors = _computeFactors(prefs, tripCount, l);
        final score = factors.fold<int>(0, (sum, f) => sum + f.points);
        final color = _scoreColor(score, scheme);
        final label = _scoreLabel(score, l);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(
            Tokens.space16, Tokens.space8, Tokens.space16, Tokens.space4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology_outlined,
                          color: color, size: 20),
                      const SizedBox(width: Tokens.space8),
                      Expanded(
                        child: Text(
                          l.aiLearningTitle,
                          style: t.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      // Score badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(Tokens.radiusPill),
                        ),
                        child: Text(
                          '$score%',
                          style: t.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: Tokens.space8),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: scheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 6,
                      backgroundColor:
                          scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: Tokens.space4),
                  Text(
                    label,
                    style: t.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  // Expanded breakdown
                  if (_expanded) ...[
                    const SizedBox(height: Tokens.space12),
                    const Divider(height: 1),
                    const SizedBox(height: Tokens.space12),
                    for (final (i, factor) in factors.indexed)
                      _FactorRow(factor: factor, scheme: scheme, t: t)
                          .animate(delay: (i * 40).ms)
                          .fadeIn(duration: 200.ms),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_Factor> _computeFactors(
      AppPrefs prefs, int tripCount, AppLocalizations l) {
    final profile = prefs.tripProfile;
    final hotel = prefs.hotelPrefs;
    final rest = prefs.restaurantPrefs;
    final contacts = prefs.emergencyContacts;

    return [
      _Factor(
        icon: Icons.directions_car_outlined,
        label: l.aiFactorVehicleModel,
        hint: l.aiFactorVehicleModelHint,
        points: profile?.vehicleModelId != null ? 20 : 0,
        max: 20,
      ),
      _Factor(
        icon: Icons.map_outlined,
        label: l.aiFactorTrips(tripCount),
        hint: l.aiFactorTripsHint,
        points: tripCount >= 10 ? 30 : tripCount >= 5 ? 20 : tripCount >= 1 ? 10 : 0,
        max: 30,
      ),
      _Factor(
        icon: Icons.hotel_outlined,
        label: l.aiFactorHotelPrefs,
        hint: l.aiFactorHotelPrefsHint,
        points: hotel.enabled &&
                hotel.priceBands.isNotEmpty &&
                (hotel.minStars > 0 || hotel.requireParking || hotel.requireWifi)
            ? 15
            : hotel.enabled ? 8 : 0,
        max: 15,
      ),
      _Factor(
        icon: Icons.restaurant_outlined,
        label: l.aiFactorRestPrefs,
        hint: l.aiFactorRestPrefsHint,
        points: rest.enabled && rest.cuisines.isNotEmpty ? 15
            : rest.enabled ? 8 : 0,
        max: 15,
      ),
      _Factor(
        icon: Icons.badge_outlined,
        label: l.aiFactorNick,
        hint: l.aiFactorNickHint,
        points: (prefs.hallNick?.isNotEmpty == true &&
                prefs.hallCountry?.isNotEmpty == true)
            ? 5
            : 0,
        max: 5,
      ),
      _Factor(
        icon: Icons.contact_emergency_outlined,
        label: l.aiFactorEmergency,
        hint: l.aiFactorEmergencyHint,
        points: contacts.isNotEmpty ? 5 : 0,
        max: 5,
      ),
      _Factor(
        icon: Icons.child_care_outlined,
        label: l.aiFactorProfile,
        hint: l.aiFactorProfileHint,
        points: profile != null &&
                (profile.hasKids || profile.hasPets ||
                    profile.wakeHour != 8 || profile.bedtimeHour != 22)
            ? 10
            : 0,
        max: 10,
      ),
    ];
  }

  Color _scoreColor(int score, ColorScheme scheme) {
    if (score >= 75) return const Color(0xFF4ADE80); // green
    if (score >= 45) return const Color(0xFFFBBF24); // amber
    return const Color(0xFFF87171); // red
  }

  String _scoreLabel(int score, AppLocalizations l) {
    if (score >= 75) return l.aiScoreExcellent;
    if (score >= 45) return l.aiScoreGood;
    return l.aiScoreBasic;
  }
}

class _Factor {
  const _Factor({
    required this.icon,
    required this.label,
    required this.hint,
    required this.points,
    required this.max,
  });
  final IconData icon;
  final String label;
  final String hint;
  final int points;
  final int max;
}

class _FactorRow extends StatelessWidget {
  const _FactorRow(
      {required this.factor, required this.scheme, required this.t});
  final _Factor factor;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    final done = factor.points == factor.max;
    final partial = factor.points > 0 && !done;
    final color = done
        ? const Color(0xFF4ADE80)
        : partial
            ? const Color(0xFFFBBF24)
            : scheme.onSurfaceVariant.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Icons.check_circle : Icons.circle_outlined,
              size: 16, color: color),
          const SizedBox(width: Tokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(factor.icon, size: 14,
                        color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(factor.label,
                          style: t.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: done ? null : scheme.onSurfaceVariant)),
                    ),
                    Text('+${factor.points}/${factor.max}',
                        style: t.labelSmall?.copyWith(color: color)),
                  ],
                ),
                if (!done)
                  Text(factor.hint,
                      style: t.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant
                              .withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
