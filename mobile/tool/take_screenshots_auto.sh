#!/usr/bin/env bash
#
# take_screenshots_auto.sh — full-auto Play Store screenshot capture.
#
# Boots the app with AUTO_DEMO=1 (demo login + Toledo → Paris trip
# + Yaris in garage pre-seeded), drives it through the key screens
# via `integration_test/screenshots_test.dart`, and writes 5-8
# PNGs to `store_assets/play_console/screenshots/<locale>/`.
#
# Requirements:
# - Emulator OR physical device connected via adb
# - `flutter drive` available on PATH
# - `integration_test` dev dep in pubspec (already added)
#
# Usage (from mobile/):
#   ./tool/take_screenshots_auto.sh es
#   ./tool/take_screenshots_auto.sh en
#
# The script also sets Android Demo Mode (frozen clock 12:00, full
# battery, wifi, no notifications) so the status bar is identical
# across shots — Play Store rejects screenshots with battery-red or
# noisy notification icons.

set -euo pipefail

LOCALE="${1:-es}"

command -v adb >/dev/null 2>&1 || { echo "adb not found"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "flutter not found"; exit 1; }

DEVICES=$(adb devices | awk 'NR>1 && $2=="device" {print $1}' | wc -l)
if [[ "$DEVICES" -eq 0 ]]; then
  echo "no adb device connected — start the emulator first"
  exit 1
fi

echo
echo "== Full-auto Play Store screenshot capture — locale=$LOCALE =="
echo

# --- Android Demo Mode: frozen status bar so every shot matches.
echo "→ enabling Android Demo Mode (clock 12:00, battery 100 %, wifi)"
adb shell settings put global sysui_demo_allowed 1 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null

# Optional: set the device locale so the app renders in the target
# language. Skipped for CN/HK — the app's locale-follows-device
# path handles them via `Locale.system`. If you need a specific
# locale forced, uncomment below.
# adb shell settings put system system_locales "$LOCALE"

# --- Environment for the driver so it writes to the right dir.
export SCREENSHOTS_LOCALE="$LOCALE"

# --- API base + key. Prefer values from make mobile-prod defaults
#     so the auto flow hits the same backend the release APK does.
API_BASE_URL="${API_BASE_URL:-https://mytravelpal-api.fly.dev}"
API_KEY="${API_KEY:-7637fb236013308ebf998843d924e15e56dce87457187e22a1a03c9c1e164d7a}"

echo "→ launching flutter drive against $API_BASE_URL"
echo "  (this takes 2-4 min: install + demo login + backend plan + snap)"
echo

# `--profile` gives release-like animation smoothness without the
# code-signing overhead of a real release build. Screenshots come
# out visually identical to production.
flutter drive \
  --profile \
  --no-dds \
  --driver=test_driver/screenshots_test.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=AUTO_DEMO=1 \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=API_KEY="$API_KEY"

# --- Exit demo mode so the phone/emulator status bar is normal.
echo
echo "→ exiting Android Demo Mode"
adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null

OUT_DIR="store_assets/play_console/screenshots/${LOCALE}"
echo
if [[ -d "$OUT_DIR" ]]; then
  count=$(find "$OUT_DIR" -maxdepth 1 -name '*.png' | wc -l)
  echo "Done — $count screenshot(s) in $OUT_DIR"
  ls -1 "$OUT_DIR"
else
  echo "WARN: $OUT_DIR is empty — check the flutter drive output above"
fi
