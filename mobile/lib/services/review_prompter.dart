import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ask Google Play to surface its native rating sheet at the RIGHT
/// moment — not on first launch, not on every open.
///
/// Trigger rules (all must pass):
/// 1. User completed at least [minCompletedPlans] plans. Someone
///    still exploring hasn't formed an opinion worth reviewing.
/// 2. At least [minDaysSinceInstall] days since first launch. Prevents
///    review-bombing after a rough first-day bug.
/// 3. Not asked in the last [minDaysSincePrompt] days. Play throttles
///    us anyway; keeping our own counter avoids wasting the quota.
///
/// Google may still swallow the request even when all our
/// preconditions pass — that's fine, the API is silent when
/// throttled by the OS and doesn't disturb the driver.
class ReviewPrompter {
  ReviewPrompter._();
  static final instance = ReviewPrompter._();

  static const int minCompletedPlans = 2;
  static const int minDaysSinceInstall = 3;
  static const int minDaysSincePrompt = 60;

  static const _kFirstLaunch = 'reviewPrompter.firstLaunchIso';
  static const _kCompletedPlans = 'reviewPrompter.completedPlans';
  static const _kLastPromptIso = 'reviewPrompter.lastPromptIso';

  final InAppReview _inAppReview = InAppReview.instance;

  /// Call once at cold-start so we have a `firstLaunch` stamp before
  /// the first plan completes.
  Future<void> markLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kFirstLaunch) == null) {
      await prefs.setString(_kFirstLaunch, DateTime.now().toIso8601String());
    }
  }

  /// Call whenever a plan is generated + shown to the user. The
  /// `ResultScreen.build` is the natural place — that's where the
  /// user has just experienced the app's value.
  Future<void> onPlanCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final done = (prefs.getInt(_kCompletedPlans) ?? 0) + 1;
    await prefs.setInt(_kCompletedPlans, done);
    await _maybeAsk(prefs);
  }

  Future<void> _maybeAsk(SharedPreferences prefs) async {
    final done = prefs.getInt(_kCompletedPlans) ?? 0;
    if (done < minCompletedPlans) return;
    final firstLaunchIso = prefs.getString(_kFirstLaunch);
    if (firstLaunchIso != null) {
      final first = DateTime.tryParse(firstLaunchIso);
      if (first != null &&
          DateTime.now().difference(first).inDays < minDaysSinceInstall) {
        return;
      }
    }
    final lastIso = prefs.getString(_kLastPromptIso);
    if (lastIso != null) {
      final last = DateTime.tryParse(lastIso);
      if (last != null &&
          DateTime.now().difference(last).inDays < minDaysSincePrompt) {
        return;
      }
    }
    if (!await _inAppReview.isAvailable()) return;
    await _inAppReview.requestReview();
    // Stamp even when the OS silently throttles us — a review sheet
    // that didn't appear still counts as "we tried this cycle".
    await prefs.setString(_kLastPromptIso, DateTime.now().toIso8601String());
  }
}
