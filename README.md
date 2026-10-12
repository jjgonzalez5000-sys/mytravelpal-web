# mytravelpal-web

Public static landing + legal docs for [MyTravelPal](https://www.mytravelpal.io).

Deployed via Cloudflare Pages on push to `main` of the PUBLIC repo
`jjgonzalez5000-sys/mytravelpal-web`.

Source of truth: this directory (`web/`) inside the private MyTravelPal
monorepo. Edit here, then publish with `make web-publish` from the
monorepo root (`git subtree push`), which pushes only `web/` and its
history to the public repo. Never commit to the public repo directly, or
the next publish will need a pull first. Nothing outside `web/` is ever
published.

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
/account-deletion              account-deletion.html
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
/en/account-deletion           en/account-deletion.html
/en/blog/                      en/blog/index.html
/en/blog/spain-toll-guide-2026 en/blog/spain-toll-guide-2026.html
/en/blog/france-scenic-routes  en/blog/france-scenic-routes.html
/en/blog/alps-summer-road-trip en/blog/alps-summer-road-trip.html

favicon.svg                    inline compass-M favicon
style.css                      shared stylesheet (both languages)
sitemap.xml                    all URLs, ES + EN, with hreflang tags
robots.txt                     points to the www sitemap
_headers                       Cloudflare Pages headers (security.txt as text/plain)
.well-known/security.txt       responsible disclosure contact (RFC 9116)
```

Each ES page carries a small `ES | EN` toggle in the nav; every English
page carries the mirror. The Spanish home page has a tiny inline script
that redirects first-time visitors whose browser locale is not Spanish
to `/en/`. The switcher writes `localStorage.mtp-lang` so the choice
sticks.

Every page also emits a `<link rel="canonical">` (absolute, `https://www.mytravelpal.io`,
clean URL) and three `<link rel="alternate" hreflang>` tags (`es`, `en`,
`x-default`) so Google can serve the right variant. The canonical host is
`www`; the apex 301-redirects to it (Cloudflare redirect rule).

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
