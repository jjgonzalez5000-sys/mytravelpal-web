#!/usr/bin/env bash
#
# take_screenshots.sh — Play Console screenshot capture wrapper.
#
# Semi-automated: the script sets Android Demo Mode (frozen clock,
# full battery, wifi icon, no notifications), then prompts you to
# navigate to each of the 8 screens documented in
# `store_assets/play_console/screenshots.md`. Between prompts you
# hit Enter and it snaps + saves to
# `store_assets/play_console/screenshots/<locale>/<NN>-<slug>.png`.
#
# Requirements:
# - Android emulator OR physical device connected via adb
# - Closed-beta APK installed (AUTO_DEMO build recommended so the
#   demo profile + Yaris + Toledo → Paris trip are pre-seeded)
# - Screen resolution ≥1080 on the long edge (Play Store wants ≥320)
#
# Usage:
#   cd mobile
#   ./tool/take_screenshots.sh es      # Spanish set
#   ./tool/take_screenshots.sh en      # English set
#
# The script only handles CAPTURE + Demo Mode setup. Navigation is
# manual — that's intentional: automating navigation with adb
# input tap is brittle across screen sizes and Flutter rebuilds.
# For fully automated captures (future iteration), wire a Flutter
# `integration_test` with `binding.takeScreenshot()`.

set -euo pipefail

LOCALE="${1:-es}"
OUT_DIR="store_assets/play_console/screenshots/${LOCALE}"

command -v adb >/dev/null 2>&1 || {
  echo "adb not found on PATH"; exit 1;
}

# Check a device is connected + authorized.
DEVICES=$(adb devices | awk 'NR>1 && $2=="device" {print $1}' | wc -l)
if [[ "$DEVICES" -eq 0 ]]; then
  echo "no adb device authorized — plug in your phone or start the emulator"
  exit 1
fi

mkdir -p "$OUT_DIR"

echo
echo "== Play Console screenshot capture — locale=$LOCALE =="
echo "== output: $OUT_DIR =="
echo

# --- Demo Mode: frozen clock + full battery + wifi + no notifications
echo "Enabling Android Demo Mode (frozen status bar)…"
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
echo "  → clock 12:00, battery 100 %, wifi full, notifications hidden"
echo

# --- The 8 screens, in Play Store display order.
# Format: "NN-slug|Prompt text" — the slug becomes the filename.
declare -a SHOTS=(
  "01-plan|Plan screen with the form filled: origin, destination, date, round-trip toggle visible. AUTO_DEMO already pre-fills Toledo → Paris."
  "02-result-hero|Result screen scrolled to the TOP so the hero (map, total cost card, best time to leave) is fully visible."
  "03-result-days|Result screen scrolled DOWN to show the day plan (Día 1/2/3…) with meal stops, hotels, sleep coord."
  "04-fuel-comparison|Result screen scrolled to fuel stops (or the day-map sheet with fuel POI pins visible)."
  "05-trip-inspiration|Trip Inspiration screen with an AI-generated itinerary result. Type '5 días por los Alpes desde Milán' or similar."
  "06-companion|Companion drive screen with the ETA hero + next stop card visible."
  "07-adverse|Adverse events on the map — a fire or heavy weather along the route, alert modal open."
  "08-personalize|Settings → Aspecto (3 color presets + Material You + OLED) OR a hotel result with Booking/Airbnb buttons visible."
)

for entry in "${SHOTS[@]}"; do
  slug="${entry%%|*}"
  prompt="${entry##*|}"
  echo "─────────────────────────────────────────────"
  echo "Shot $slug"
  echo "  → $prompt"
  read -rp "  Press Enter when the screen is ready…"
  path="${OUT_DIR}/${slug}.png"
  adb exec-out screencap -p > "$path"
  # Sanity check — bail early if the screencap came back empty.
  if [[ ! -s "$path" ]]; then
    echo "  !! screencap wrote 0 bytes to $path — check adb and retry"
    exit 1
  fi
  size_kb=$(stat -c%s "$path")
  size_kb=$(( size_kb / 1024 ))
  echo "  ✓ saved ${path} (${size_kb} KB)"
done

# --- Exit demo mode so the phone's real status bar is back.
echo
echo "Exiting Android Demo Mode…"
adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null

echo
echo "Done — $(ls "$OUT_DIR" | wc -l) screenshot(s) in $OUT_DIR"
echo
echo "Next: verify the pngs visually, then upload to Play Console"
echo "(Store settings → Main store listing → Phone screenshots)."
