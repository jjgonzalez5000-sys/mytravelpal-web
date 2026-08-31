# mytravelpal-web

Public static landing + legal docs for [MyTravelPal](https://mytravelpal.io).

Deployed via Cloudflare Pages on push to `main`.

- `index.html` — landing
- `beta.html` — closed-beta signup instructions
- `support.html` — support / GDPR requests
- `privacy.html` — GDPR privacy policy (source: `MyTravelPal/docs/privacy.md`)
- `terms.html` — terms of service (source: `MyTravelPal/docs/terms.md`)
- `.well-known/security.txt` — responsible disclosure contact
- `robots.txt`, `sitemap.xml`

## Deploy

1. Cloudflare Pages → connect this repo → framework "None" → build cmd empty
2. Add `mytravelpal.io` and `www.mytravelpal.io` under Custom Domains
3. HTTPS auto after DNS propagates
