import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../l10n/app_localizations.dart';

const _kPlanTutorialSeen = 'tutorial.plan.seen.v1';
const _kResultTutorialSeen = 'tutorial.result.seen.v1';

Future<bool> _shouldShow(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(key) ?? false);
}

/// Persists the plan + result coach marks as already-seen. Used by
/// the AUTO_DEMO bootstrap so a dogfood build doesn't stop at the
/// tutorial overlays on every fresh install.
Future<void> markTutorialsSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPlanTutorialSeen, true);
  await prefs.setBool(_kResultTutorialSeen, true);
}

Future<void> _markSeen(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, true);
}

/// Clear both the plan and result tutorial "seen" flags so that
/// the coach-marks re-appear the next time the user opens the
/// relevant screen. Called from the "Replay tutorial" entry in
/// Settings.
Future<void> resetTutorials() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kPlanTutorialSeen);
  await prefs.remove(_kResultTutorialSeen);
}

void showPlanTutorial(
  BuildContext context, {
  required GlobalKey originKey,
  required GlobalKey destinationKey,
  required GlobalKey preferencesKey,
}) async {
  if (!await _shouldShow(_kPlanTutorialSeen)) return;
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);

  final targets = <TargetFocus>[
    TargetFocus(
      identify: 'origin',
      keyTarget: originKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _CoachContent(
            title: l.tutorialOriginTitle,
            body: l.tutorialOriginBody,
            onNext: controller.next,
          ),
        ),
      ],
    ),
    TargetFocus(
      identify: 'destination',
      keyTarget: destinationKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _CoachContent(
            title: l.tutorialDestinationTitle,
            body: l.tutorialDestinationBody,
            onNext: controller.next,
          ),
        ),
      ],
    ),
    TargetFocus(
      identify: 'preferences',
      keyTarget: preferencesKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _CoachContent(
            title: l.tutorialPrefsTitle,
            body: l.tutorialPrefsBody,
            onNext: controller.next,
            isLast: true,
          ),
        ),
      ],
    ),
  ];

  TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    opacityShadow: 0.7,
    hideSkip: false,
    textSkip: l.tutorialSkip,
    textStyleSkip: const TextStyle(
      color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500,
    ),
    onFinish: () => _markSeen(_kPlanTutorialSeen),
    onSkip: () {
      _markSeen(_kPlanTutorialSeen);
      return true;
    },
  ).show(context: context);
}

void showResultTutorial(
  BuildContext context, {
  required GlobalKey timeWindowKey,
  required GlobalKey tollKey,
}) async {
  if (!await _shouldShow(_kResultTutorialSeen)) return;
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);

  final targets = <TargetFocus>[
    TargetFocus(
      identify: 'timeWindow',
      keyTarget: timeWindowKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _CoachContent(
            title: l.tutorialTimeWindowTitle,
            body: l.tutorialTimeWindowBody,
            onNext: controller.next,
          ),
        ),
      ],
    ),
    TargetFocus(
      identify: 'tolls',
      keyTarget: tollKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _CoachContent(
            title: l.tutorialTollTitle,
            body: l.tutorialTollBody,
            onNext: controller.next,
            isLast: true,
          ),
        ),
      ],
    ),
  ];

  TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    opacityShadow: 0.7,
    hideSkip: false,
    textSkip: l.tutorialSkip,
    textStyleSkip: const TextStyle(
      color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500,
    ),
    onFinish: () => _markSeen(_kResultTutorialSeen),
    onSkip: () {
      _markSeen(_kResultTutorialSeen);
      return true;
    },
  ).show(context: context);
}

class _CoachContent extends StatelessWidget {
  const _CoachContent({
    required this.title,
    required this.body,
    required this.onNext,
    this.isLast = false,
  });
  final String title;
  final String body;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onNext,
              child: Text(
                isLast ? '  OK  ' : '  >  ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
