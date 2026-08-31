---
layout: default
title: Privacy Policy
---

# MyTravelPal — Privacy Policy

**Last updated: 2026-08-28**

MyTravelPal ("we", "us", "the App") is an Android application that helps you
plan European road trips. This policy explains what personal data we
collect, why we collect it, and your rights under the EU General Data
Protection Regulation (GDPR).

**Contact for privacy matters:** contact@mytravelpal.example (replace with
your real address before publishing).

---

## 1. Data we collect

### Data you provide directly
- **Account**: email address and display name from your sign-in provider
  (Google, Apple or Facebook). We do not store your password — sign-in
  providers handle authentication.
- **Trip profile**: number of travellers, whether you travel with kids or
  pets, vehicle type and consumption, meal preferences, sleep and travel
  pace preferences.
- **Trip requests**: origin, destination and desired departure time for
  each plan you compute.
- **Saved trips**: a copy of any trip you explicitly save (origin /
  destination / departure / recommendation).
- **Recent searches**: the last places you searched for (helps
  autocomplete).

### Data we collect automatically
- **Crash reports and error diagnostics** via Sentry (self-hosted-region
  Frankfurt). Includes stack traces, request paths, and non-identifying
  device info. No message content or personal fields are attached.
- **Approximate location** when you tap "Use my location" — used only to
  compute a route and never stored server-side.

### Data we do NOT collect
- No ad tracking identifiers.
- No behavioural analytics.
- No microphone, camera, contacts or photos.

---

## 2. Why we collect it

- **To compute trip plans**: origin / destination / profile feed the
  routing, POI and cost algorithms.
- **To sync across your devices**: profile and saved trips are stored so
  reinstalling the app or logging in from another device restores them.
- **To improve reliability**: crash reports help us fix bugs in the field.

We never sell or share your data with advertisers.

---

## 3. Third-party services

MyTravelPal relies on the following processors:

| Service | Purpose | Data shared |
|---------|---------|-------------|
| Fly.io (backend hosting, EU region CDG) | Serve the API | All request data |
| Fly Postgres | Persist profile + saved trips | Profile + trips |
| Sentry (EU region) | Crash reports | Stack traces, request paths, device info |
| Geoapify (EU) | Points of interest (hotels, restaurants, fuel) | Route corridor coordinates |
| Open-Meteo | Weather forecast | Sampled coordinates + time |
| OpenStreetMap OSRM | Routing | Origin / destination coordinates |
| Booking.com Affiliate | Hotel deep links | Nothing beyond the search URL |
| TheFork | Restaurant deep links | Nothing beyond the search URL |
| Google Sign-In / Apple / Facebook | Authentication | Your email + name from your chosen provider |

We do not send your personal data to any other party. All services listed
above hold the data solely to provide the service to us on our
instructions.

---

## 4. How long we keep it

- **Profile + saved trips**: retained until you delete them or delete
  your account.
- **Recent searches**: kept until you clear app data or the local cap
  (8 entries) rolls them over.
- **Crash reports**: 90 days rolling in Sentry.
- **Backend logs**: 7 days rolling on Fly.io.
- **Backups**: encrypted database snapshots retained for 14 days.

Deleting your account (see below) erases everything within 24 hours.

---

## 5. Your rights (GDPR)

You can, at any time:

- **Access your data**: Settings → "Descargar mis datos" downloads a
  JSON with everything we hold about you.
- **Delete your account**: Settings → "Borrar mi cuenta" permanently
  erases your profile and saved trips.
- **Correct your data**: Edit your profile at any time from the app.
- **Object to processing**: Sign out and uninstall the app.
- **File a complaint**: contact your national data-protection authority.

For requests we cannot fulfil from within the app, email
contact@mytravelpal.example — we respond within 30 days.

---

## 6. Children

MyTravelPal is not directed at children under 13. We do not knowingly
collect data from children. If you believe we have inadvertently collected
data from a child, contact us to have it removed.

---

## 7. International transfers

The backend runs in the EU (Fly.io Paris region). Third-party services
(Sentry, Geoapify, Open-Meteo) also run in the EU. Booking.com and
TheFork are US/EU companies; we send them only URL parameters when you
tap their links.

---

## 8. Changes to this policy

We may update this policy as the app evolves. Material changes will be
announced in-app before they take effect. The "Last updated" date at the
top reflects the current version.

---

*MyTravelPal is operated by [Your legal entity here]. Replace this line
with your registered business details before publishing.*
