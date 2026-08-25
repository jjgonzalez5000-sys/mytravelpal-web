package com.mytravelpal.mytravelpal

import com.mytravelpal.mytravelpal.car.CarNotificationBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the Kotlin ↔ Dart channel that fires trip alerts
        // with a `CarAppExtender` so Android Auto picks them up. On
        // devices without AA the channel simply posts a normal
        // NotificationCompat — no-op car extension.
        CarNotificationBridge.register(applicationContext, flutterEngine)
    }
}
