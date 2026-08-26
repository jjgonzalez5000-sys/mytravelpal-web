# Privacy Policy — MyTravelPal

**Last updated:** 2026-08-25
**Effective date:** date the app is first published to Google Play
**Data controller:** [Name/company + registered address — replace before publishing]
**Contact:** privacy@mytravelpal.app

MyTravelPal ("the app", "we", "us") is a road-trip planning app that
computes routes, fuel prices, adverse-event alerts and a live trip
dashboard for European drivers. This policy explains what data the app
processes, why, on what legal basis, and what rights you have.

## 1. What data we process

### 1.1 Data you provide

- **Origin and destination** you type or pick on the map (text and
  coordinates). Used only to compute your plan; not stored server-side.
- **Trip preferences**: departure time, vehicle type, meal times,
  overnight preference, price bands, cuisines. Stored on your device
  only (Android SharedPreferences). Sent to the backend at plan time
  and discarded there after the response is computed.
- **Saved trips**: the plans you tap "Save" on. Stored on your device
  only. Not backed up to any server.

### 1.2 Data the app collects automatically

- **Live GPS position** when you tap "Start trip" and the trip
  dashboard is open. Used only to render your position on the map,
  compute progress, and fire local alerts. **Position is never sent
  to our servers**. It never leaves your device.
- **Crash reports and performance metrics** via Firebase Crashlytics
  (once enabled). No user identifier; only device model, OS version,
  app version, and stack trace of the crash.
- **Locale, timezone** — inferred from the device to localise
  strings and format dates.

### 1.3 Data we do NOT collect

- We do NOT collect your name, email, phone, address, contacts,
  photos, microphone, camera, biometrics, device advertising ID,
  installed apps list, or browsing history.
- We do NOT track you across other apps or websites.
- We do NOT sell any data to any third party.

## 2. Why we process each piece of data

| Data | Purpose | Legal basis (GDPR) |
|---|---|---|
| Origin/destination coords | Computing your plan | Legitimate interest (delivering the service you asked for) |
| Trip preferences | Personalising the plan | Legitimate interest |
| Live GPS position | Live trip dashboard | Consent (you tap "Start trip") |
| Crash reports | Fixing bugs | Legitimate interest |
| Saved trips | Your own history | Contract (you asked us to save them) |

## 3. Third parties we share data with

None. Your GPS position never leaves the device. Trip planning requests
to our backend contain only the origin/destination coordinates + trip
preferences you set — no identifier of any kind. We do not use any
third-party ad networks, analytics SDKs, or attribution vendors.

External data providers we CALL FROM OUR BACKEND (with only the trip's
bounding box, never your identity):

- OpenStreetMap Nominatim (geocoding) — data returned to us, not sent
  to them beyond the search box you typed and the corridor bounding
  box.
- OSRM (routing) — same as above.
- Government fuel-price feeds (Spain Ministerio, France Roulez-Éco,
  Italy MITE) — one-off dataset downloads by our server, no per-user
  identifiers.
- NASA FIRMS (wildfire hotspots) — corridor bounding box only.
- Open-Meteo (weather) — corridor bounding box only.

Full attribution list: see the "Licenses & data sources" screen in
Settings.

## 4. Where data is stored

- **On-device data** (preferences, saved trips) lives in Android
  SharedPreferences on the phone itself. Uninstalling the app deletes
  it.
- **Backend data**: the MyTravelPal API runs on Fly.io in the CDG
  (Paris) region. Requests are stateless — nothing about a request
  survives after the response is served. No user accounts, no
  request logs stored beyond 24 h of operational rotation.

## 5. Your rights (EU GDPR)

You have the right to:

- Access, correct, delete or export your on-device data. All of it is
  in the app — Settings → History → Delete.
- Withdraw location consent at any time. Android → Settings → Apps →
  MyTravelPal → Permissions → Location → deny.
- Object to processing. Because we don't collect any identifying
  data, we can't process further "erasure" beyond deleting the app.
- Lodge a complaint with your national data protection authority
  (Spain: AEPD, France: CNIL, etc.).

## 6. Children

MyTravelPal is a driving-companion app not intended for children under
13. We do not knowingly collect data from anyone under 13.

## 7. Security

Data in transit uses HTTPS (TLS 1.2+). On-device data uses Android's
platform-standard SharedPreferences, encrypted at rest via the
device's file-based encryption when the device is locked.

## 8. Changes

If we update this policy in a material way we'll change the "Last
updated" date and, when relevant, show an in-app notice on the next
launch.

## 9. Contact

Data controller: [Name / company / address — replace before publishing]
Email: privacy@mytravelpal.app

For urgent privacy concerns, email **privacy@mytravelpal.app** with
"Privacy request" in the subject line. We respond within 30 days.
