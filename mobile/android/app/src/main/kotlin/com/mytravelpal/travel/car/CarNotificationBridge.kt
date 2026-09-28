package com.mytravelpal.travel.car

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.car.app.notification.CarAppExtender
import androidx.core.app.NotificationCompat
import com.mytravelpal.travel.R
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge Flutter → native NotificationCompat + CarAppExtender.
 *
 * `flutter_local_notifications` doesn't expose the AA extender, so
 * without this bridge our trip alerts never surface on the head
 * unit. This class registers a MethodChannel that Dart can call to
 * post a notification that:
 * - Displays as a heads-up on the phone (like any local notif).
 * - Is ALSO extended for Android Auto via `CarAppExtender`, so AA
 *   turns it into a car notification card when the phone is plugged
 *   in.
 *
 * Registered from `MainActivity.configureFlutterEngine`.
 */
object CarNotificationBridge {

    const val CHANNEL_NAME = "mytravelpal/car_notifications"
    private const val NOTIF_CHANNEL_ID = "trip_alerts_car"

    fun register(context: Context, flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        ensureChannel(context)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "postAlert" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        postAlert(context, id, title, body)
                        result.success(null)
                    }
                    "cancelAlert" -> {
                        val id = call.argument<Int>("id") ?: 0
                        NotificationManager::class.java
                        val mgr = context.getSystemService(
                            Context.NOTIFICATION_SERVICE,
                        ) as NotificationManager
                        mgr.cancel(id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(
            Context.NOTIFICATION_SERVICE,
        ) as NotificationManager
        if (mgr.getNotificationChannel(NOTIF_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            NOTIF_CHANNEL_ID,
            context.getString(R.string.aa_notif_channel_alerts_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(
                R.string.aa_notif_channel_alerts_desc,
            )
            // No sound on car notifs — driving-safety review flags
            // any notif that pulls the driver's attention aggressively.
            setSound(null, null)
        }
        mgr.createNotificationChannel(channel)
    }

    private fun postAlert(
        context: Context, id: Int, title: String, body: String,
    ) {
        val builder = NotificationCompat.Builder(context, NOTIF_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            // The extender is what makes AA pick this up. Without it,
            // AA discards the notification even though it fires on
            // the phone normally.
            .extend(
                CarAppExtender.Builder()
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .build(),
            )
        val mgr = androidx.core.app.NotificationManagerCompat.from(context)
        try {
            mgr.notify(id, builder.build())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted on 13+. Silent no-op —
            // the phone-side flutter_local_notifications path
            // already handles the permission prompt.
        }
    }
}
