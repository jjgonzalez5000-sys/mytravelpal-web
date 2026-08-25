import 'dart:async';

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Full-screen loading modal shown while `/plan` is in flight.
///
/// The plan endpoint fans out to 6+ external providers (routing,
/// traffic, POI search, gov fuel feeds, adverse-events, weather) and
/// typically takes 5-15 s. Users complained the app looked stuck —
/// this rotates through a short list of "what we're doing right now"
/// captions so it's clear the app is working and NOT frozen.
///
/// Usage:
///   showDialog(context, barrierDismissible: false,
///     builder: (_) => const PlanLoadingDialog());
///   ... await api.planTrip(...) ...
///   Navigator.pop(context); // close the dialog
///
/// The dialog can't be dismissed by tapping outside — the plan
/// wouldn't cancel anyway, so a "you can leave whenever" affordance
/// would just leave users stuck on a broken screen.
/// Which pieces of work `/plan` will do for THIS request. Only steps
/// present in the set get shown in the rotating caption — otherwise
/// we'd claim to be "searching hotels" on a trip where the user
/// didn't request any, which trained testers to distrust the copy.
enum PlanStep { routing, traffic, fuel, hotels, restaurants, alerts, tolls }

class PlanLoadingDialog extends StatefulWidget {
  const PlanLoadingDialog({super.key, this.steps = PlanStep.values});

  /// Ordered list of steps to cycle through. Defaults to every step —
  /// callers with request context should pass a filtered subset.
  final List<PlanStep> steps;

  @override
  State<PlanLoadingDialog> createState() => _PlanLoadingDialogState();
}

class _PlanLoadingDialogState extends State<PlanLoadingDialog> {
  static const _rotateInterval = Duration(seconds: 2, milliseconds: 500);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_rotateInterval, (_) {
      if (!mounted) return;
      // Cycle deterministically — no randomness so the same trip
      // shows the same order twice in a row (less disorienting).
      setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<(IconData, String)> _steps(AppLocalizations l) {
    // Build the caption list in the order the backend actually runs
    // the pieces (route first, then time windows, then side data)
    // and drop anything the current request didn't ask for. Always
    // finish with "almost there" so long tails don't loop back to
    // the first message.
    final captions = <(IconData, String)>[];
    for (final step in widget.steps) {
      switch (step) {
        case PlanStep.routing:
          captions.add((Icons.route, l.planLoadingStepRouting));
        case PlanStep.traffic:
          captions.add((Icons.traffic, l.planLoadingStepTraffic));
        case PlanStep.fuel:
          captions.add(
            (Icons.local_gas_station, l.planLoadingStepFuel),
          );
        case PlanStep.hotels:
          captions.add((Icons.hotel_outlined, l.planLoadingStepHotels));
        case PlanStep.restaurants:
          captions.add(
            (Icons.restaurant_outlined, l.planLoadingStepRestaurants),
          );
        case PlanStep.alerts:
          captions.add(
            (Icons.warning_amber_outlined, l.planLoadingStepAlerts),
          );
        case PlanStep.tolls:
          captions.add((Icons.toll_outlined, l.planLoadingStepTolls));
      }
    }
    captions.add((Icons.check_circle_outline, l.planLoadingStepAlmost));
    return captions;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final steps = _steps(l);
    // Ride the index past the last step by showing "almost there" —
    // if the request takes longer than steps × interval, we don't
    // want to loop back to the first message.
    final effectiveIndex =
        _index < steps.length - 1 ? _index : steps.length - 1;
    final (icon, caption) = steps[effectiveIndex];

    return PopScope(
      // Block back button while the plan is running — cancelling
      // wouldn't stop the server-side work anyway.
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Tokens.space24, vertical: Tokens.space32,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: Tokens.space12),
                  Expanded(
                    child: Text(
                      l.planLoadingTitle,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space20),
              // Step row — the icon + caption swap together with an
              // AnimatedSwitcher so the transition reads as one thing
              // rather than two glitchy re-mounts.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey<int>(effectiveIndex),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: scheme.primary, size: 22),
                    const SizedBox(width: Tokens.space12),
                    Expanded(
                      child: Text(
                        caption,
                        style: t.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space20),
              Text(
                l.planLoadingHelper,
                style: t.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
