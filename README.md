# mytravelpal-web

Public static landing + legal docs for [Optitrips](https://www.mytravelpal.io).

Deployed via Cloudflare Pages on push to `main` of the PUBLIC repo
`jjgonzalez5000-sys/mytravelpal-web`.

Source of truth: this directory (`web/`) inside the private app
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
/partners                      partners.html       (for travel brands and affiliate reviewers)
/affiliate-disclosure          affiliate-disclosure.html
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
/en/partners                   en/partners.html
/en/affiliate-disclosure       en/affiliate-disclosure.html
/en/blog/                      en/blog/index.html
/en/blog/spain-toll-guide-2026 en/blog/spain-toll-guide-2026.html
/en/blog/france-scenic-routes  en/blog/france-scenic-routes.html
/en/blog/alps-summer-road-trip en/blog/alps-summer-road-trip.html

favicon.svg                    inline compass-M favicon
style.css                      shared stylesheet (both languages)
sitemap.xml                    all URLs, ES + EN, with hreflang tags
robots.txt                     points to the www sitemap
_headers                       Cloudflare Pages headers (security.txt as text/plain, assetlinks.json as JSON)
_redirects                     /get (Play opt-in, the only place holding that URL) and retired /join
_routes.json                   only /join/* and /c/* invoke Functions
.well-known/security.txt       responsible disclosure contact (RFC 9116)
.well-known/assetlinks.json    Android App Links (package + both signing fingerprints, public values)
functions/                     Pages Functions: /join/<SLUG> and /c/<CODE> (logic in functions/_lib/pages.js)
img/og-default.png             default Open Graph image (1200x630)
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

## Dynamic pages (Pages Functions)

`/join/<SLUG>` and `/c/<CODE>` are rendered by Functions that fetch the public,
anonymised endpoints `GET /v1/public/share/<slug>` and
`GET /v1/public/companion/<code>` of the Fly API (no app API key, no secrets).
Set the `API_BASE` environment variable in Cloudflare Pages to change the API
origin (default `https://mytravelpal-api.fly.dev`). Set the secret
`WEB_PROXY_SECRET` in Cloudflare Pages (same value as the Fly secret
`MYTRAVELPAL_WEB_PROXY_SECRET`, never commit it): the Functions then forward
the visitor IP (`CF-Connecting-IP`) so the API rate-limits per visitor instead
of per Cloudflare egress address. Without it every visitor shares one bucket.
Tests live outside `web/`
(`tools/web-tests/`, run `node --test tools/web-tests/pages.test.mjs`) so they
are not deployed; `python3 tools/check_site.py` crawls the site for broken links.

Blog articles live in `blog/<slug>.html` and `en/blog/<slug>.html` (same
English slug in both languages). A new article also needs a card in both
`blog/index.html` files and two `<url>` entries in `sitemap.xml`; the footer of
every page links `/partners` and `/affiliate-disclosure`.

## Web Analytics (Cloudflare, cookie-free)

Every static page ends with the Cloudflare Web Analytics beacon, and the
dynamic `/join` and `/c` pages emit it from `functions/_lib/pages.js`
(`BEACON_TOKEN`; their CSP allows `static.cloudflareinsights.com` in
`script-src` and `cloudflareinsights.com` plus `'self'` in `connect-src`).
`/get` is a redirect and serves no HTML. The token is public (not a secret),
but until the owner copies it every page carries the placeholder
`CF_BEACON_TOKEN`. `python3 tools/check_site.py` fails if a page lacks the
beacon or its token differs from `pages.js`, and warns while the placeholder
is still there; `tools/web-tests/pages.test.mjs` checks the same.

Owner step, choose ONE of the two (only one snippet can run per page):

1. Manual snippet (what the pages contain today). Cloudflare dashboard >
   Analytics & Logs > Web Analytics > Add a site > hostname
   `www.mytravelpal.io` > Done > Manage site: choose the manual JS snippet
   option and copy the `token` value from the snippet. Then, from the monorepo
   root, replace the placeholder everywhere and check:
   ```
   grep -rl CF_BEACON_TOKEN web | xargs sed -i 's/CF_BEACON_TOKEN/<token>/g'
   python3 tools/check_site.py && node --test tools/web-tests/pages.test.mjs
   ```
2. Automatic setup. For a hostname proxied through Cloudflare (our Workers
   custom domain is), adding the site in Web Analytics enables automatic
   injection by default and needs no token in the code. In that case remove
   the two beacon lines from every page and the script tag in `pages.js`
   (and the checks above), otherwise pages would carry two snippets.
   Automatic injection is skipped for responses sent with
   `Cache-Control: public, no-transform`.

Docs: https://developers.cloudflare.com/web-analytics/get-started/ and
https://developers.cloudflare.com/web-analytics/faq/ (CSP). The privacy
pages (section 10) describe what it collects.

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
