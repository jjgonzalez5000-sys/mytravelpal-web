package com.mytravelpal.travel.car

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
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
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val soundPref = prefs.getString("flutter.notificationSound", "default") ?: "default"
        ensureChannel(context, soundPref)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "postAlert" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val waypointLat = call.argument<Double>("waypointLat")
                        val waypointLon = call.argument<Double>("waypointLon")
                        val destLat = call.argument<Double>("destLat")
                        val destLon = call.argument<Double>("destLon")
                        val actionLabel = call.argument<String>("actionLabel")
                        postAlert(context, id, title, body,
                            waypointLat, waypointLon, destLat, destLon, actionLabel)
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

    /**
     * Recreate the notification channel with the current sound preference.
     * Called on every postAlert so a sound change takes effect immediately
     * (Android requires deleting + recreating the channel to change sound).
     *
     * Sound values (stored in FlutterSharedPreferences as flutter.notificationSound):
     *   "silent" → no sound
     *   "default" (or absent) → system default notification sound
     *   Any other string → treated as a content URI for a custom ringtone
     */
    private fun ensureChannel(context: Context, soundPref: String = "default") {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Determine desired sound URI
        val soundUri: Uri? = when (soundPref) {
            "silent" -> null
            else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        }

        // If channel already exists with the same sound, skip recreation.
        val existing = mgr.getNotificationChannel(NOTIF_CHANNEL_ID)
        if (existing != null) {
            val existingSound = existing.sound
            if ((soundUri == null && existingSound == null) ||
                (soundUri != null && soundUri == existingSound)) return
            // Sound changed — delete and recreate.
            mgr.deleteNotificationChannel(NOTIF_CHANNEL_ID)
        }

        val channel = NotificationChannel(
            NOTIF_CHANNEL_ID,
            context.getString(R.string.aa_notif_channel_alerts_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.aa_notif_channel_alerts_desc)
            setSound(soundUri, android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            enableVibration(soundPref != "silent")
        }
        mgr.createNotificationChannel(channel)
    }

    private fun postAlert(
        context: Context, id: Int, title: String, body: String,
        waypointLat: Double? = null, waypointLon: Double? = null,
        destLat: Double? = null, destLon: Double? = null,
        actionLabel: String? = null,
    ) {
        // Re-check channel sound on each alert (user may have changed pref).
        val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val soundPref = sharedPrefs.getString("flutter.notificationSound", "default") ?: "default"
        ensureChannel(context, soundPref)

        val builder = NotificationCompat.Builder(context, NOTIF_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)

        val carExtender = CarAppExtender.Builder()
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)

        // If waypoint coords provided, add a "Desviar" action button
        // that opens Google Maps with the waypoint en route to destination.
        if (waypointLat != null && waypointLon != null) {
            val mapsIntent = buildMapsIntent(
                waypointLat, waypointLon, destLat, destLon,
            )
            val label = actionLabel ?: "Desviar"
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getActivity(context, id, mapsIntent, flags)

            // Phone: action button
            builder.addAction(
                NotificationCompat.Action.Builder(
                    R.mipmap.ic_launcher, label, pi,
                ).build(),
            )
            // AA head unit: CarAppExtender.addAction takes raw icon/text/intent
            carExtender.addAction(R.mipmap.ic_launcher, label, pi)
        }

        builder.extend(carExtender.build())

        val mgr = androidx.core.app.NotificationManagerCompat.from(context)
        try {
            mgr.notify(id, builder.build())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted on 13+.
        }
    }

    /**
     * Build a Google Maps navigation Intent.
     * - With destination: adds waypoint en route (Maps recalculates keeping final dest).
     * - Without destination: navigates directly to the waypoint.
     */
    private fun buildMapsIntent(
        waypointLat: Double, waypointLon: Double,
        destLat: Double?, destLon: Double?,
    ): Intent {
        val url = if (destLat != null && destLon != null) {
            // Waypoint + destination: driver passes through POI then continues.
            "https://www.google.com/maps/dir/?api=1" +
                "&destination=$destLat,$destLon" +
                "&waypoints=$waypointLat,$waypointLon" +
                "&travelmode=driving"
        } else {
            // No destination known — navigate directly to waypoint.
            "google.navigation:q=$waypointLat,$waypointLon"
        }
        return Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            setPackage("com.google.android.apps.maps")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }
}
