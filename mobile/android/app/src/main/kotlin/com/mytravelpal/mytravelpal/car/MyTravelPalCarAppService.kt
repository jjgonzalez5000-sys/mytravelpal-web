package com.mytravelpal.mytravelpal.car

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.SessionInfo
import androidx.car.app.validation.HostValidator

/**
 * Android Auto entry point.
 *
 * When the driver plugs the phone into a car with Android Auto and
 * MyTravelPal is installed, Android Auto discovers this service via
 * the `androidx.car.app.CarAppService` intent filter in the manifest
 * and asks it for a `Session`. Every session's [onCreateScreen] returns
 * the first screen shown on the head unit.
 *
 * We deliberately keep this class thin — one session, one starting
 * screen. Screen state comes from `SharedPreferences` written by the
 * Flutter `TripDashboardScreen` via `services/car_bridge.dart`, so
 * this native side stays a rendering layer with no business logic.
 *
 * Category: POI Companion (see manifest intent-filter). MyTravelPal
 * does NOT provide turn-by-turn nav on the head unit — Google Maps
 * or Waze does that. See `project_android_auto` memory.
 */
class MyTravelPalCarAppService : CarAppService() {

    override fun createHostValidator(): HostValidator {
        // Ship a permissive host validator for now — Android Auto,
        // Automotive OS emulator, and our DHU testing rig all need
        // to connect during development. Tighten to
        // `HostValidator.Builder(applicationContext).addAllowedHosts(R.array.hosts_allowlist).build()`
        // before the public rollout when we know which hosts we're
        // whitelisting.
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(sessionInfo: SessionInfo): Session {
        return TripCompanionSession()
    }
}
