import 'package:flutter/services.dart' show rootBundle;

import '../storage/app_prefs.dart';

/// Resolves the changelog to show after an app update.
///
/// Rules:
///  * Fresh install (no `lastSeenBuild` stored) → return null. The
///    onboarding flow carries the pitch on day 1; adding a "what's
///    new" pop on top of that would double-tax the driver.
///  * `lastSeenBuild < currentBuild` → concat every intermediate
///    changelog file that exists (so a user skipping several
///    versions still sees the sum of what changed).
///  * `lastSeenBuild >= currentBuild` → return null (nothing new).
///
/// Assets: `assets/changelogs/<build>_<lang>.md`. Falls back to `_en`
/// when the locale-specific file is missing so a locale we haven't
/// translated yet still sees SOMETHING instead of a silent skip.
class WhatsNewService {
  WhatsNewService({required AppPrefs prefs}) : _prefs = prefs;

  final AppPrefs _prefs;

  /// Current build number, injected via `--dart-define=APP_VERSION`
  /// at build time. Format is `1.2.3+42`; we parse the trailing `+N`.
  static int _currentBuildFromDartDefine() {
    const raw = String.fromEnvironment('APP_VERSION', defaultValue: '');
    final plus = raw.lastIndexOf('+');
    if (plus < 0 || plus == raw.length - 1) return 0;
    return int.tryParse(raw.substring(plus + 1)) ?? 0;
  }

  /// Returns the markdown-lite body to show, or null when the sheet
  /// shouldn't render at all. `languageCode` is the ISO 639-1 code
  /// of the active locale ('en', 'es', ...).
  Future<String?> resolveChangelogFor(String languageCode) async {
    final current = _currentBuildFromDartDefine();
    if (current == 0) return null;
    final storedLast = _prefs.lastSeenBuild;
    // Three cases on first launch after an update:
    //  1. Truly fresh install (no lastSeenBuild AND onboarding NOT
    //     shown) — the marketing flow already pitches everything;
    //     don't stack a What's-new sheet on top.
    //  2. Existing user whose install predates the What's-new feature
    //     itself (no lastSeenBuild BUT onboarding was shown). Treat
    //     `last` as `current - 1` so they see the current release's
    //     notes ONCE. Without this, the feature would silently activate
    //     the version AFTER the one that ships it.
    //  3. Normal case (lastSeenBuild present) — show the concatenation
    //     of every version's notes since they last saw one.
    final int effectiveLast;
    if (storedLast == null) {
      if (!_prefs.onboardingShown) {
        await _prefs.setLastSeenBuild(current);
        return null;
      }
      effectiveLast = current - 1;
    } else {
      effectiveLast = storedLast;
    }
    if (current <= effectiveLast) return null;

    final buffer = StringBuffer();
    for (var b = effectiveLast + 1; b <= current; b++) {
      final txt = await _loadOne(b, languageCode);
      if (txt == null || txt.trim().isEmpty) continue;
      // Convention: a `<!-- silent -->` comment (case-insensitive)
      // anywhere in the first 200 chars means "bump the pointer,
      // don't disrupt the driver with a sheet". Useful for pure
      // bug-fix patches where the changelog exists for git history
      // but has nothing worth interrupting the user for.
      final head = txt.length > 200 ? txt.substring(0, 200) : txt;
      if (head.toLowerCase().contains('<!-- silent -->')) continue;
      if (buffer.isNotEmpty) buffer.write('\n\n---\n\n');
      buffer.write(txt.trim());
    }
    if (buffer.isEmpty) {
      // No changelog files bundled between last-seen and current —
      // silently bump the pointer so we don't re-check every launch.
      await _prefs.setLastSeenBuild(current);
      return null;
    }
    return buffer.toString();
  }

  /// Called after the user dismisses the sheet. Bumps the pointer so
  /// the next launch won't re-show the same body.
  Future<void> acknowledge() async {
    final current = _currentBuildFromDartDefine();
    if (current > 0) await _prefs.setLastSeenBuild(current);
  }

  Future<String?> _loadOne(int build, String languageCode) async {
    final locales = [languageCode, 'en'];
    for (final lang in locales) {
      final asset = 'assets/changelogs/${build}_$lang.md';
      try {
        return await rootBundle.loadString(asset);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
