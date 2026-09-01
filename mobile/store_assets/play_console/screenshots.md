# Play Store screenshots — capture checklist

Google Play Console requires **min 2, max 8 screenshots per language** at 16:9 or 9:16 ratio, min 320 px on the shortest edge, max 3840 px on the longest edge. Best to submit at **1080×2400** (standard modern Android portrait) or **1080×1920** (older devices) — Play Store will letterbox/scale for other sizes.

For MyTravelPal we ship **8 shots per language** in ES/EN order (Play Store fills the rest from the default language).

## Device / build for capture

- Use the closed-beta APK already installed on the Xiaomi test device
- Screen: 1080×2400 native (Xiaomi Mi 10 or similar); output straight from `adb exec-out screencap -p > shot.png`
- Battery + status bar mocked via **Demo Mode** so every shot has the same clock (usually `12:00` full battery, wifi bar):
  ```bash
  adb shell settings put global sysui_demo_allowed 1
  adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200
  adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
  adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
  adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
  # exit demo mode after captures:
  adb shell am broadcast -a com.android.systemui.demo -e command exit
  ```

## Content — 8 shots, in this order

Order matters — Play Store shows the first 3 as the primary card, so lead with the strongest.

| # | Screen | What to show | Overlay text (optional headline) |
|---|--------|--------------|----------------------------------|
| 1 | **Plan screen** with completed form (Madrid → Amsterdam, 3 days from now) | Full form with origin/dest/date/round-trip + "Salir ya" FAB visible | "Planifica cualquier road trip por Europa" / "Plan any European road trip" |
| 2 | **Result — hero** (top of ResultScreen with total distance, time, cost card, route hero, "Best time to leave" recommendation) | Route summary + total-cost card | "Mejor hora para salir, coste total real" / "Best time to leave, real total cost" |
| 3 | **Result — day plan** with 3 days (Día 1/2/3), each with meal stops + hotel picks + sleep coord | Multi-day breakdown showing dwell days | "Etapas diarias, hoteles cerca cada noche" / "Daily stages, hotels each night" |
| 4 | **Fuel comparison** (map view + cheapest 3 stations along route) | HERE + gov feeds combined | "Gasolinera más barata de la ruta" / "Cheapest station along YOUR route" |
| 5 | **Trip Inspiration prompt + result** (screen where user typed "5 días por los Alpes desde Milán" and AI generated it) | LLM-generated itinerary with waypoints | "Descríbelo, la IA lo planifica" / "Describe it, AI plans it" |
| 6 | **Companion drive** with trip progress hero (ETA, km remaining, next stop) + speed tile + a rec card | Active driving view | "Modo compañero: te avisa mientras conduces" / "Companion mode: alerts while you drive" |
| 7 | **Adverse events map** — a real fire or heavy weather along a route with the alert modal open | Critical event UI | "Alertas críticas de incendios y clima" / "Critical fire & weather alerts" |
| 8 | **Settings — Aspecto** (3 color presets + Material You + OLED + tema) OR **hotel result with Booking + Airbnb deep-link buttons** | Personalization / integrations | "Personaliza tu app" / "Personalise your app" OR "Reserva en Booking o Airbnb con un tap" / "Book on Booking or Airbnb in one tap" |

## Capture workflow

```bash
# Enter demo mode + prepare
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false

# For each screen: navigate manually, then
mkdir -p store_assets/play_console/screenshots/es
adb exec-out screencap -p > store_assets/play_console/screenshots/es/01-plan.png
# ... repeat 02..08

# Repeat with app in English locale for /en set. Change device language:
adb shell settings put system system_locales en-US
# then re-take.

# Exit demo mode when done
adb shell am broadcast -a com.android.systemui.demo -e command exit
```

## Overlay text (optional, boosts CTR on Play Store)

If we want polished screenshots with headline overlays instead of raw captures, mockup workflow:

1. Use https://previewed.app or https://screenshots.pro (free tier)
2. Upload the raw PNGs + optionally a device frame + optional headline text
3. Export at 1080×1920 or 1080×2400
4. Save to `store_assets/play_console/screenshots/<locale>/`

Recommend WITH overlay for shots 1, 2, 5 (the "hooks") and WITHOUT for 3, 4, 6, 7, 8 (function proof).

## Tablet screenshots (optional, boosts install rate on tablets)

Play Console has a separate "10-inch tablet" and "7-inch tablet" slot. Only fill if we want tablet-optimised discovery. For our audience (drivers on phones) — SKIP for beta, revisit at launch.

## Deliverables checklist

- [ ] 8 × ES shots at 1080×2400 in `screenshots/es/`
- [ ] 8 × EN shots at 1080×2400 in `screenshots/en/`
- [ ] FR/DE/IT/PT/CA optional — Play Store fallback to EN is fine for beta
- [ ] Feature graphic PNG (already done: `graphics/feature_graphic.png` 1024×500)
- [ ] Play Store icon 512×512 PNG (already done: `../../assets/icon/play_store_icon_512.png`)

## Time to capture

- Prep demo mode + navigate: ~5 min
- 8 captures + verify: ~15 min per language
- 2 languages (ES + EN): ~40 min total

## When to do this

**Right before submitting the closed testing track** — otherwise UI copy changes make captures stale. Capture after the last APK build + before hitting "Save & Review" on Play Console.
