package com.mytravelpal.travel.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.mytravelpal.travel.MainActivity
import com.mytravelpal.travel.R
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

/**
 * Home-screen widget showing a countdown to the next upcoming saved
 * trip. State is written by
 * `services/widget_bridge.dart#WidgetBridge.refresh` into the standard
 * Flutter SharedPreferences file (`FlutterSharedPreferences`), with
 * keys prefixed by "flutter." as the plugin serialises them.
 *
 * Refresh model: Android limits AppWidget updates to once every 30
 * min. We accept that — the countdown ticks in minutes on the phone
 * itself already, and re-rendering more often would drain battery.
 * The widget also refreshes any time SharedPreferences changes and
 * a `updateAppWidget` broadcast fires, which we schedule from the
 * Flutter side after each `refresh()` call.
 *
 * Tapping the widget opens the main activity so the driver can jump
 * into planning / dashboard.
 */
class NextTripWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE,
        )
        val hasTrip = prefs.getBoolean("flutter.widgetHasTrip", false)
        val savedCount = prefs.getLong("flutter.widgetSavedTripsCount", 0L)
            .toInt()

        val views = RemoteViews(context.packageName, R.layout.next_trip_widget)

        // Tap-through: opens the app. Deep-link routing is handled by
        // the existing DeepLinkHandler once main activity is up.
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.next_trip_root, pending)

        if (!hasTrip) {
            views.setTextViewText(
                R.id.next_trip_title,
                context.getString(R.string.widget_no_trip_title),
            )
            views.setTextViewText(
                R.id.next_trip_subtitle,
                if (savedCount > 0) context.getString(
                    R.string.widget_no_upcoming, savedCount,
                ) else context.getString(R.string.widget_no_saved),
            )
            views.setTextViewText(R.id.next_trip_countdown, "")
            return views
        }

        val originLabel = prefs.getString(
            "flutter.widgetOriginLabel", "?",
        )
        val destinationLabel = prefs.getString(
            "flutter.widgetDestinationLabel", "?",
        )
        val departureMs = prefs.getLong("flutter.widgetDepartureMs", 0L)
        val departure = ZonedDateTime.ofInstant(
            Instant.ofEpochMilli(departureMs), ZoneId.systemDefault(),
        )
        val countdown = formatCountdown(departureMs)

        views.setTextViewText(
            R.id.next_trip_title,
            "$originLabel → $destinationLabel",
        )
        views.setTextViewText(
            R.id.next_trip_subtitle,
            departure.format(
                DateTimeFormatter.ofPattern("EEE d MMM · HH:mm"),
            ),
        )
        views.setTextViewText(R.id.next_trip_countdown, countdown)
        return views
    }

    private fun formatCountdown(departureMs: Long): String {
        val now = System.currentTimeMillis()
        if (departureMs <= now) return ""
        val d = Duration.ofMillis(departureMs - now)
        val days = d.toDays()
        val hours = d.minusDays(days).toHours()
        val minutes = d.minusDays(days).minusHours(hours).toMinutes()
        return when {
            days > 0 -> "${days}d ${hours}h"
            hours > 0 -> "${hours}h ${minutes}m"
            else -> "${minutes}m"
        }
    }

    companion object {
        /**
         * Trigger a widget refresh from the Flutter side any time
         * the "next trip" changes. The widget is guaranteed to
         * re-render even if Android's own update timer hasn't fired.
         */
        fun requestRefresh(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val cn = ComponentName(context, NextTripWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(cn)
            if (ids.isEmpty()) return
            val intent = Intent(context, NextTripWidgetProvider::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }
}
