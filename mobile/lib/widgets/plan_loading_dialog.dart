import 'dart:async';
import 'dart:math' as math;

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
  // Base step cadence — matches roughly how long each phase takes
  // on a fast trip. Longer trips extend past this and switch into
  // the long-tail loop to reassure the user we're still working.
  static const _rotateInterval = Duration(seconds: 2, milliseconds: 500);
  // Long-tail messages fire slower — once every 3.5 s so the copy
  // has time to be read on the tail of a big request.
  static const _longTailInterval = Duration(seconds: 3, milliseconds: 500);
  // Where the progress bar plateaus while we wait on the tail.
  // Real completion is server-side, so pretending 100% would be
  // dishonest and jarring when the sheet snaps closed at 60%.
  static const double _progressPlateau = 0.9;
  // Expected worst-case fast-path duration (in seconds) for the
  // progress bar to interpolate against. Real backends can and do
  // exceed this — that's what the plateau is for.
  static const int _fastPathSeconds = 12;

  Timer? _rotateTimer;
  Timer? _elapsedTimer;
  int _index = 0;
  int _longTailIndex = 0;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _rotateTimer = Timer.periodic(_rotateInterval, (_) {
      if (!mounted) return;
      setState(() => _index++);
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        // Once base steps are exhausted, tick the long-tail index
        // on its own slower cadence so the caption keeps changing.
        if (_elapsedSeconds > 0 &&
            _elapsedSeconds %
                    (_longTailInterval.inSeconds) == 0) {
          _longTailIndex++;
        }
      });
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  List<(IconData, String)> _longTailCaptions(AppLocalizations l) => [
        (Icons.public, l.planLoadingLongCrossingCountries),
        (Icons.local_gas_station, l.planLoadingLongScanningFuel),
        (Icons.explore_outlined, l.planLoadingLongBigTrip),
        (Icons.check_circle_outline, l.planLoadingLongAlmostDone),
      ];

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
    // Two-phase caption strategy:
    // 1. While we're inside `steps.length × rotateInterval`, cycle
    //    through the step captions in order.
    // 2. Once the base cadence is exhausted (long tail), cycle
    //    through the reassurance messages so the user knows the
    //    app is still working on heavy trips.
    final baseIndex = _index < steps.length ? _index : steps.length;
    final inLongTail = baseIndex >= steps.length;
    final IconData icon;
    final String caption;
    if (!inLongTail) {
      (icon, caption) = steps[baseIndex];
    } else {
      final tail = _longTailCaptions(l);
      (icon, caption) = tail[_longTailIndex % tail.length];
    }
    // Progress bar: interpolate 0 → plateau over `_fastPathSeconds`;
    // pin at plateau afterwards so we don't lie about completion.
    final progress = math.min(
      _progressPlateau,
      _elapsedSeconds / _fastPathSeconds * _progressPlateau,
    );

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
                  // Stable key that swaps whenever the caption
                  // changes so AnimatedSwitcher cross-fades.
                  key: ValueKey<String>(
                    inLongTail
                        ? 'tail-$_longTailIndex'
                        : 'step-$baseIndex',
                  ),
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
              const SizedBox(height: Tokens.space16),
              // Progress bar — determinate up to `_progressPlateau`,
              // then flat. Elapsed counter sits underneath so the
              // driver has a concrete "time is passing" signal.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      scheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
              const SizedBox(height: Tokens.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Helper text takes the flex space so it wraps
                  // instead of pushing the elapsed counter off the
                  // dialog. Elapsed counter stays fixed-width on
                  // the right thanks to tabular figures.
                  Expanded(
                    child: Text(
                      l.planLoadingHelper,
                      style: t.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: Tokens.space8),
                  Text(
                    l.planLoadingElapsed(_elapsedSeconds),
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
