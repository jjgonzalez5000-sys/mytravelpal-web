import '../api/models.dart';

enum Tier { free, essential, premium }

Tier tierFromString(String? tier) => switch (tier) {
      'premium' => Tier.premium,
      'essential' => Tier.essential,
      _ => Tier.free,
    };

/// What a plan unlocks. Anything that earns through a booking or affiliate
/// click (hotels, restaurants, parking, activities, alerts, route variants,
/// hotel arbitrage) is free for everyone and deliberately absent here: only
/// features with a marginal cost (LLM, HERE routing) or pro value are gated.
class TierCaps {
  const TierCaps({
    required this.tollFree,
    required this.tollSkip,
    required this.aiSuggest,
    required this.radar,
    required this.unlimitedSaves,
    required this.unlimitedInspire,
  });

  /// Toll-free alternative and hourly toll analysis.
  final bool tollFree;

  /// Routing around toll booths (`avoidTolls` and via-only waypoints).
  final bool tollSkip;

  /// AI stop suggestions and trip narrative.
  final bool aiSuggest;
  final bool radar;
  final bool unlimitedSaves;
  final bool unlimitedInspire;

  static const unrestricted = TierCaps(
    tollFree: true,
    tollSkip: true,
    aiSuggest: true,
    radar: true,
    unlimitedSaves: true,
    unlimitedInspire: true,
  );
}

TierCaps capsFor(Tier tier) => switch (tier) {
      Tier.free => const TierCaps(
          tollFree: false,
          tollSkip: false,
          aiSuggest: false,
          radar: false,
          unlimitedSaves: false,
          unlimitedInspire: false,
        ),
      Tier.essential => const TierCaps(
          tollFree: true,
          tollSkip: true,
          aiSuggest: false,
          radar: true,
          unlimitedSaves: true,
          unlimitedInspire: true,
        ),
      Tier.premium => TierCaps.unrestricted,
    };

/// The request a plan can really carry: gated options the plan does not
/// include are dropped, everything else (hotels, restaurants, parking,
/// activities, alerts, route variants) is left untouched. Pure and
/// idempotent; the stored wishes in [r] are not mutated, so an upgrade
/// brings them back.
TripPlanRequest sanitizeForTier(TripPlanRequest r, TierCaps caps) {
  final dropToll =
      !caps.tollFree && (r.includeTollAlternative || r.includeHourlyTollAnalysis);
  final dropSkip = !caps.tollSkip &&
      (r.avoidTolls || r.waypoints.any((w) => w.viaOnly));
  if (!dropToll && !dropSkip) return r;
  return r.copyWith(
    includeTollAlternative: dropToll ? false : null,
    includeHourlyTollAnalysis: dropToll ? false : null,
    avoidTolls: dropSkip ? false : null,
    waypoints:
        dropSkip ? r.waypoints.where((w) => !w.viaOnly).toList() : null,
  );
}

/// Whether the toll-free options (toll-free alternative + hourly toll
/// analysis) are really on for a plan: the driver asked for them AND their
/// plan includes them. The request must never carry them for a plan that
/// does not, whatever the stored default says.
bool effectiveTollFree({required bool wanted, required bool paid}) =>
    wanted && paid;

/// Whether the AI stop suggestions are really on for a plan: the driver
/// asked for them AND their plan is Premium (each search spends the daily
/// AI quota).
bool effectiveAiSuggest({required bool wanted, required bool premium}) =>
    wanted && premium;
