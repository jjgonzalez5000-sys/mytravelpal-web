package com.mytravelpal.mytravelpal

import android.content.Intent
import android.os.Bundle
import com.mytravelpal.mytravelpal.car.CarNotificationBridge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    // Channel used to hand shared text (Google Maps URLs shared via the
    // Android share sheet) from Kotlin down to Dart. See
    // `lib/services/deep_link_handler.dart` for the Flutter side.
    private val shareChannelName = "mytravelpal/share"

    // Buffer for a cold-start share: onCreate runs before the Flutter
    // engine is wired, so we stash the URL and hand it over when Dart
    // asks via `getInitialSharedText`. Cleared after the first read so
    // we don't re-open the same trip on the next process launch.
    private var pendingSharedText: String? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingSharedText = extractSharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Because the activity is `launchMode="singleTop"`, a share
        // dispatched while the app is already running lands here
        // instead of onCreate. Push it straight into Dart if the
        // channel is up; otherwise buffer for the next
        // `getInitialSharedText` call.
        val text = extractSharedText(intent) ?: return
        val channel = shareChannel
        if (channel != null) {
            channel.invokeMethod("onSharedText", text)
        } else {
            pendingSharedText = text
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the Kotlin ↔ Dart channel that fires trip alerts
        // with a `CarAppExtender` so Android Auto picks them up. On
        // devices without AA the channel simply posts a normal
        // NotificationCompat — no-op car extension.
        CarNotificationBridge.register(applicationContext, flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannelName,
        )
        shareChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    val text = pendingSharedText
                    pendingSharedText = null
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        if (intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
    }
}
