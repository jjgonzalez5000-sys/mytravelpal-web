# Image assets — MyTravelPal web

The homepage (`index.html`) references these image files. Layout has
already reserved space for them via `width`/`height` attributes, so the
page will not shift when you drop the real files in.

Capture the screenshots from a phone (Pixel 6+ or similar,
1080×2400 px) and export the hero as a rendered map image sized
1024×500 px.

## Files needed

| File                             | Recommended size (px)     | Content                                                    |
|----------------------------------|---------------------------|------------------------------------------------------------|
| `hero-map.png`                   | 1024 × 500                | Hero: a planned European road-trip on the app map, with visible route + overnight-stop pins. |
| `screenshot-plan.png`            | 1080 × 2400 (phone shot)  | Plan screen: origin + destination + travelers + departure. |
| `screenshot-result.png`          | 1080 × 2400 (phone shot)  | Result screen: daily itinerary with tolls, hotels, fuel.   |
| `screenshot-companion.png`       | 1080 × 2400 (phone shot)  | Companion mode driving overlay.                            |

## How to capture

1. Build the mobile app on your phone (`flutter install`) and open a
   representative trip (e.g. Madrid → Rome, 3 days).
2. Use the Android built-in screenshot (Power + Volume Down).
3. Crop / export the files with the names above and drop them into
   this `img/` folder.
4. Commit + push — Cloudflare will re-deploy automatically.

## Tips

- Prefer light-mode UI: matches the coral / warm-white website palette
  (`--coral: #F44F72`, `--bg: #FDFCFA`).
- Redact any personal data (email in the top bar, real GPS home
  address) before publishing.
- Keep each file under ~350 KB to keep page load snappy; PNGOUT or
  `oxipng -o 4` do a good job.

## Placeholder behaviour

Until the real files exist, the `<img>` tags render as empty rectangles
of the reserved size (the background is set to `var(--bg-2)` so they
look intentional rather than broken). Do not delete the `<img>` tags
before adding the files — you would lose the reserved space and the
layout would shift.
