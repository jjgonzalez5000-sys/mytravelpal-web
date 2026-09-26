# mytravelpal-web

Public static landing + legal docs for [MyTravelPal](https://www.mytravelpal.io).

Deployed via Cloudflare Pages on push to `main`.

## Structure

The site is bilingual (Spanish default, English mirror under `/en/`).
Cloudflare Pages serves clean URLs (no `.html` in internal links); on
disk each page still lives as an `.html` file next to its EN counterpart.

```
/                              index.html          (ES home)
/about                         about.html
/beta                          beta.html
/support                       support.html
/privacy                       privacy.html
/terms                         terms.html
/blog/                         blog/index.html
/blog/spain-toll-guide-2026    blog/spain-toll-guide-2026.html
/blog/france-scenic-routes     blog/france-scenic-routes.html
/blog/alps-summer-road-trip    blog/alps-summer-road-trip.html

/en/                           en/index.html       (EN home)
/en/about                      en/about.html
/en/beta                       en/beta.html
/en/support                    en/support.html
/en/privacy                    en/privacy.html
/en/terms                      en/terms.html
/en/blog/                      en/blog/index.html
/en/blog/spain-toll-guide-2026 en/blog/spain-toll-guide-2026.html
/en/blog/france-scenic-routes  en/blog/france-scenic-routes.html
/en/blog/alps-summer-road-trip en/blog/alps-summer-road-trip.html

favicon.svg                    inline compass-M favicon
style.css                      shared stylesheet (both languages)
sitemap.xml                    all URLs, ES + EN, with hreflang tags
robots.txt
.well-known/security.txt       responsible disclosure contact
```

Each ES page carries a small `ES | EN` toggle in the nav; every English
page carries the mirror. The Spanish home page has a tiny inline script
that redirects first-time visitors whose browser locale is not Spanish
to `/en/`. The switcher writes `localStorage.mtp-lang` so the choice
sticks.

Every page also emits three `<link rel="alternate" hreflang>` tags
(`es`, `en`, `x-default`) so Google can serve the right variant.

## Deploy

1. Cloudflare Pages -> connect this repo -> framework "None" -> build cmd empty.
2. Add `mytravelpal.io` and `www.mytravelpal.io` under Custom Domains.
3. HTTPS auto after DNS propagates.
4. In the project settings, keep "clean URLs" ON — internal links across
   the site use `/about` rather than `/about.html`.

## Screenshots

The homepage renders three phone mockups (Plan / Result / Companion)
plus a hero-map banner entirely from CSS + inline SVG, so nothing 404s
while real screenshots are captured. When you want to swap them for
real captures, replace the `.phone-mockup` block for each phone with an
`<img>` pointing to the real file — or update the SVG inside if you
prefer to keep the mockup look. `img/README.md` documents recommended
capture sizes.
