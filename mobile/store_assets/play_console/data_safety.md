# Play Console Data Safety form — pre-filled answers

Google Play Console requires an accurate Data Safety declaration. Wrong answers = takedown risk. Below is what MyTravelPal actually does today, mapped to Google's exact taxonomy at `https://support.google.com/googleplay/android-developer/answer/10787469`.

Cross-check against `docs/privacy.md` (source of truth) before submitting. Any drift between the two = fix privacy.md AND the Play form.

## 1. Data collection & sharing summary

- **Does your app collect or share any of the required user data types?** → **Yes**
- **Is all of the user data collected by your app encrypted in transit?** → **Yes** (HTTPS only, backend has HSTS enforced)
- **Do you provide a way for users to request that their data be deleted?** → **Yes**
  - In-app: Settings → "Borrar mi cuenta" (immediate)
  - Web: `mytravelpal.io/support` → email to `privacy@mytravelpal.io`

## 2. Personal info

| Type | Collected? | Shared? | Optional/Required | Purpose |
|---|---|---|---|---|
| Name | Yes | No | Required | Account (from Google Sign-In display name) |
| Email address | Yes | No | Required | Account (Google Sign-In) |
| User IDs | Yes | No | Required | Account (Google `sub` claim) |
| Address | No | — | — | — |
| Phone number | Yes (emergency contacts only) | No | Optional | App functionality — SOS crash detection |
| Race and ethnicity | No | — | — | — |
| Political or religious beliefs | No | — | — | — |
| Sexual orientation | No | — | — | — |
| Other info | No | — | — | — |

## 3. Financial info

None. Booking payments happen entirely on Booking.com's site.

## 4. Health & fitness

None.

## 5. Messages

None (no email, SMS or in-app messaging collected).

## 6. Photos and videos

None.

## 7. Audio files

None (push-to-talk voice commands stream to backend but transcripts are NOT stored — declare as "processed ephemerally" = **NOT COLLECTED** per Google's definition).

## 8. Files and docs

None.

## 9. Calendar

None.

## 10. Contacts

| Type | Collected? | Shared? | Optional/Required | Purpose |
|---|---|---|---|---|
| Contacts | Yes | No | Optional | App functionality — emergency contact picker |

**Note:** Only the contacts the user EXPLICITLY selects via the picker are stored (name + phone). We do NOT read the full address book.

## 11. App activity

| Type | Collected? | Shared? | Optional/Required | Purpose |
|---|---|---|---|---|
| App interactions | Yes | No | Required | Analytics — crash & performance |
| In-app search history | Yes (recent geocode searches) | No | Required | App functionality — autocomplete |
| Installed apps | No | — | — | — |
| Other user-generated content | Yes (saved trips, favourite places) | No | Optional | App functionality |
| Other actions | No | — | — | — |

## 12. Web browsing

None.

## 13. App info and performance

| Type | Collected? | Shared? | Optional/Required | Purpose |
|---|---|---|---|---|
| Crash logs | Yes | Yes (Sentry EU) | Required | Analytics — Sentry crash reports |
| Diagnostics | Yes | Yes (Sentry EU) | Required | Analytics — performance monitoring |
| Other app performance data | No | — | — | — |

## 14. Device or other IDs

| Type | Collected? | Shared? | Optional/Required | Purpose |
|---|---|---|---|---|
| Device or other IDs | Yes (Android ID / Play install ID) | Yes (Sentry) | Required | Analytics — crash deduplication |

## 15. Location

| Type | Collected? | Shared? | Optional/Required | Purpose |
|---|---|---|---|---|
| Approximate location | Yes | No | Optional | App functionality — "Use my location" for planning |
| Precise location | Yes | No | Optional | App functionality — Companion drive tracking, crash detection |

**Data handling:** location is used **ephemerally** for the trip / companion session. NOT persisted server-side.

## 16. Security practices

- **Is your data encrypted in transit?** Yes — HTTPS + HSTS + Fly.io TLS termination
- **Do you follow the Families Policy?** No (not a kids app)
- **Has your app been independently reviewed against a global security standard?** No
- **Do you provide a way for users to request that their data be deleted?** Yes (see section 1)

## 17. Data types the app COLLECTS (for the "Data collected" summary)

- Name
- Email address
- User IDs
- Phone number (emergency contacts)
- Contacts (picker)
- App interactions
- In-app search history
- Other user-generated content (saved trips)
- Crash logs
- Diagnostics
- Device or other IDs
- Approximate location
- Precise location

## 18. Data types the app SHARES (with third parties)

Only crash / performance data with Sentry (EU region). Nothing else is shared with third parties. Deep-links to Booking / Airbnb / Google Maps carry only URL parameters (search query + affiliate tag), NOT user data.

- Crash logs → **Sentry (EU)**
- Diagnostics → **Sentry (EU)**
- Device or other IDs → **Sentry (EU)**

Nothing shared to advertisers or data brokers.

## 19. Play Console — required per-data-type "Data handling" answers

For every "Yes" above, Google asks a mini-form. Standard answers:

- **Is this data collected, shared, or both?** → Collected only (unless it's the 3 Sentry ones, which are both)
- **Is this data processed ephemerally?** → Yes for location (session-only), No for the rest (persisted)
- **Is data collection required for this app, or can users choose whether it's collected?** → Optional for location, contacts, saved trips; Required for account + crash logs
- **Why is this user data collected/shared?** → pick per table above (App functionality / Analytics)

## 20. Privacy policy URL

`https://mytravelpal.io/privacy`

## 21. Contact email for privacy queries

`privacy@mytravelpal.io`

---

**Review checklist before submitting:**

- [ ] Cross-check every "Collected" row against `docs/privacy.md`
- [ ] Confirm Sentry region setting is EU (Frankfurt)
- [ ] Confirm no third-party analytics SDKs sneaked in via a new dependency
- [ ] Confirm the Booking / Airbnb / Google Maps deep-links do NOT pass user identifiers
- [ ] Confirm `mytravelpal.io/privacy` is live and reachable (Cloudflare Pages)
