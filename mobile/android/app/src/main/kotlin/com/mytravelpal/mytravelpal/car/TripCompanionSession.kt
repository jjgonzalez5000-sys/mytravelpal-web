package com.mytravelpal.mytravelpal.car

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

/**
 * A single Android Auto driving session. Kept minimal — Android
 * Auto lifecycle already handles the interesting stuff (attach /
 * detach / focus changes). We just hand back the starting Screen.
 */
class TripCompanionSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        return TripCompanionScreen(carContext)
    }
}
