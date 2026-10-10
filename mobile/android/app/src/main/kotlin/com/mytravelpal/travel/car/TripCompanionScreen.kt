package com.mytravelpal.travel.car

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarLocation
import androidx.car.app.model.Distance
import androidx.car.app.model.DistanceSpan
import androidx.car.app.model.ItemList
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Metadata
import androidx.car.app.model.Place
import androidx.car.app.model.PlaceListMapTemplate
import androidx.car.app.model.PlaceMarker
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import com.mytravelpal.travel.R

/**
 * Main Android Auto screen — the live trip overview.
 *
 * Uses `PlaceListMapTemplate`, the canonical AA template for POI
 * Companion apps: a Google-drawn map on one side and a scrollable
 * list of places on the other. Each `Row` we add carries a `Place`
 * with a `CarLocation`, which AA turns into a marker on the map;
 * that's how we plot "next stop" / "cheaper fuel" / destination
 * without drawing the polyline ourselves (Navigation category only).
 *
 * State comes from `SharedPreferences` written by
 * [services/car_bridge.dart]. See [BRIDGE_PREFS] docs at the bottom.
 *
 * Refresh cadence: AA hosts invalidate templates at their own
 * discretion. We self-invalidate every 5 s so the countdown /
 * "in N min" numbers stay live even when the underlying prefs
 * haven't changed (time passes and the label text does too).
 */
class TripCompanionScreen(carContext: CarContext) : Screen(carContext) {

    private val prefs = carContext.getSharedPreferences(
        BRIDGE_PREFS, Context.MODE_PRIVATE,
    )
    private val handler = Handler(Looper.getMainLooper())
    private val refreshTicker = object : Runnable {
        override fun run() {
            invalidate()
            handler.postDelayed(this, REFRESH_INTERVAL_MS)
        }
    }

    init {
        lifecycle.addObserver(
            androidx.lifecycle.LifecycleEventObserver { _, event ->
                when (event) {
                    androidx.lifecycle.Lifecycle.Event.ON_START ->
                        handler.post(refreshTicker)
                    androidx.lifecycle.Lifecycle.Event.ON_STOP ->
                        handler.removeCallbacks(refreshTicker)
                    else -> {}
                }
            },
        )
    }

    override fun onGetTemplate(): Template {
        val active = prefs.getBoolean(KEY_ACTIVE_TRIP, false)
        if (!active) return idleTemplate()

        // PlaceListMapTemplate requires ALL rows in an ItemList to be
        // either ALL browsable or ALL non-browsable — mixing the two
        // throws an IllegalArgumentException (AA crash tester 2026-09).
        //
        // Strategy: check whether there are navigable sub-lists (fuel /
        // restaurants). If yes → use ONLY browsable rows; if no → use
        // ONLY informational rows. This keeps the list type consistent.
        val hasFuelList = !prefs.getString(KEY_FUEL_LIST_JSON, null).isNullOrBlank()
                && prefs.getString(KEY_FUEL_LIST_JSON, null) != "[]"
        val hasRestList = !prefs.getString(KEY_RESTAURANTS_LIST_JSON, null).isNullOrBlank()
                && prefs.getString(KEY_RESTAURANTS_LIST_JSON, null) != "[]"
        val hasBrowsable = hasFuelList || hasRestList

        val listBuilder = ItemList.Builder()

        if (hasBrowsable) {
            // Browsable mode: each major section is a tappable row that
            // pushes into a detail screen.  Informational data (ETA,
            // next-stop name) is embedded as addText() in each row.
            addNextStopRowBrowsable(listBuilder)
            addCheaperFuelRowBrowsable(listBuilder, hasFuelList)
            addEtaRowBrowsable(listBuilder)
            if (hasRestList) addRestaurantsListEntry(listBuilder)
        } else {
            // Informational-only mode: no sub-lists exist yet, keep all
            // rows non-browsable so AA doesn't complain.
            addNextStopRow(listBuilder)
            addCheaperFuelRow(listBuilder)
            addEtaRow(listBuilder)
            addSpeedProgressRow(listBuilder)
        }

        val itemList = listBuilder.build()
        // No actionable data yet — PlaceListMapTemplate requires at least
        // one row with a DistanceSpan or Place. Use MessageTemplate instead.
        if (itemList.items.isEmpty()) return companionActiveTemplate()

        val builder = PlaceListMapTemplate.Builder()
            .setTitle(carContext.getString(R.string.aa_app_title))
            .setHeaderAction(Action.APP_ICON)
            .setItemList(itemList)

        // Anchor the map on "me" when we know the GPS position; fall
        // back to the destination so at least the map isn't blank.
        anchorPlace()?.let(builder::setAnchor)
        return builder.build()
    }

    // ---- Row builders (non-browsable) -----------------------------------

    private fun addNextStopRow(list: ItemList.Builder) {
        val name = prefs.getString(KEY_NEXT_STOP_NAME, null) ?: return
        val etaMs = prefs.getLong(KEY_NEXT_STOP_ETA_MS, 0L)
        if (etaMs <= 0) return
        val minsAway = ((etaMs - System.currentTimeMillis()) / 60_000L)
            .coerceAtLeast(0L)
        val row = Row.Builder()
            .setTitle(carContext.getString(R.string.aa_next_stop_title))
            .addText(
                carContext.getString(
                    R.string.aa_next_stop_body,
                    name, formatHhmm(etaMs), minsAway,
                ),
            )
        placeWithMarker(
            KEY_NEXT_STOP_LAT, KEY_NEXT_STOP_LON, CarColor.PRIMARY, "🍽",
        )?.let { row.setMetadata(Metadata.Builder().setPlace(it).build()) }
        list.addItem(row.build())
    }

    private fun addCheaperFuelRow(list: ItemList.Builder) {
        val brand = prefs.getString(KEY_CHEAPER_FUEL_BRAND, null) ?: return
        val km = prefs.getLong(KEY_CHEAPER_FUEL_KM, 0L).toInt()
        val cts = prefs.getLong(KEY_CHEAPER_FUEL_CENTS, 0L).toInt()
        if (km <= 0) return
        val row = Row.Builder()
            .setTitle(carContext.getString(R.string.aa_cheaper_fuel_title))
            .addText(
                carContext.getString(
                    R.string.aa_cheaper_fuel_body, brand, km, cts,
                ),
            )
        placeWithMarker(
            KEY_CHEAPER_FUEL_LAT, KEY_CHEAPER_FUEL_LON,
            CarColor.SECONDARY, "⛽",
        )?.let { row.setMetadata(Metadata.Builder().setPlace(it).build()) }
        list.addItem(row.build())
    }

    private fun addEtaRow(list: ItemList.Builder) {
        val etaMs = prefs.getLong(KEY_DEST_ETA_MS, 0L)
        if (etaMs <= 0) return
        val remaining = prefs.getLong(KEY_REMAINING_KM, 0L).toInt()
        // PlaceListMapTemplate requires a DistanceSpan on non-browsable rows
        // that don't carry a Place marker — attach it to the text.
        val bodyText = carContext.getString(
            R.string.aa_eta_body, formatHhmm(etaMs), remaining,
        )
        val spannable = SpannableString(bodyText)
        val distSpan = DistanceSpan.create(
            Distance.create(remaining.toDouble(), Distance.UNIT_KILOMETERS),
        )
        spannable.setSpan(distSpan, 0, 1, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
        list.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_eta_title))
                .addText(spannable)
                .build(),
        )
    }

    private fun addFuelListEntry(list: ItemList.Builder) {
        val payload = prefs.getString(KEY_FUEL_LIST_JSON, null)
        if (payload.isNullOrBlank() || payload == "[]") return
        list.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_fuel_list_row))
                .setBrowsable(true)
                .setOnClickListener {
                    screenManager.push(FuelListScreen(carContext))
                }
                .build(),
        )
    }

    private fun addRestaurantsListEntry(list: ItemList.Builder) {
        val payload = prefs.getString(KEY_RESTAURANTS_LIST_JSON, null)
        if (payload.isNullOrBlank() || payload == "[]") return
        list.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_restaurants_list_row))
                .setBrowsable(true)
                .setOnClickListener {
                    screenManager.push(RestaurantsListScreen(carContext))
                }
                .build(),
        )
    }

    // ---- Row builders (browsable — used when sub-lists exist) ----------

    private fun addNextStopRowBrowsable(list: ItemList.Builder) {
        val name = prefs.getString(KEY_NEXT_STOP_NAME, null) ?: return
        val etaMs = prefs.getLong(KEY_NEXT_STOP_ETA_MS, 0L)
        if (etaMs <= 0) return
        val minsAway = ((etaMs - System.currentTimeMillis()) / 60_000L)
            .coerceAtLeast(0L)
        val row = Row.Builder()
            .setTitle(carContext.getString(R.string.aa_next_stop_title))
            .addText(
                carContext.getString(
                    R.string.aa_next_stop_body,
                    name, formatHhmm(etaMs), minsAway,
                ),
            )
            .setBrowsable(true)
            .setOnClickListener { /* informational tap — no sub-screen */ }
        placeWithMarker(
            KEY_NEXT_STOP_LAT, KEY_NEXT_STOP_LON, CarColor.PRIMARY, "🍽",
        )?.let { row.setMetadata(Metadata.Builder().setPlace(it).build()) }
        list.addItem(row.build())
    }

    private fun addCheaperFuelRowBrowsable(list: ItemList.Builder, hasFuelList: Boolean) {
        val brand = prefs.getString(KEY_CHEAPER_FUEL_BRAND, null) ?: return
        val km = prefs.getLong(KEY_CHEAPER_FUEL_KM, 0L).toInt()
        val cts = prefs.getLong(KEY_CHEAPER_FUEL_CENTS, 0L).toInt()
        if (km <= 0) return
        val row = Row.Builder()
            .setTitle(carContext.getString(R.string.aa_cheaper_fuel_title))
            .addText(
                carContext.getString(
                    R.string.aa_cheaper_fuel_body, brand, km, cts,
                ),
            )
            .setBrowsable(hasFuelList)
        if (hasFuelList) {
            row.setOnClickListener { screenManager.push(FuelListScreen(carContext)) }
        }
        placeWithMarker(
            KEY_CHEAPER_FUEL_LAT, KEY_CHEAPER_FUEL_LON,
            CarColor.SECONDARY, "⛽",
        )?.let { row.setMetadata(Metadata.Builder().setPlace(it).build()) }
        list.addItem(row.build())
    }

    private fun addSpeedProgressRow(list: ItemList.Builder) {
        val speedKmh = prefs.getLong(KEY_SPEED_KMH, -1L).toInt()
        val progressKm = prefs.getLong(KEY_PROGRESS_KM, 0L).toInt()
        val totalKm = prefs.getLong(KEY_TOTAL_KM, 0L).toInt()
        if (speedKmh < 0 && totalKm == 0) return
        val speedStr = if (speedKmh >= 0) "${speedKmh} km/h" else "—"
        val row = Row.Builder().setTitle(carContext.getString(R.string.aa_speed_title))
        if (totalKm > 0) {
            // The host replaces the spanned character with the formatted
            // distance, so the span must cover ONLY a placeholder: spanning
            // the whole body turned the row into just "1670 km", which read
            // as the speed.
            val body = "$speedStr  ·  §"
            val spannable = SpannableString(body)
            spannable.setSpan(
                DistanceSpan.create(
                    Distance.create(
                        (totalKm - progressKm).coerceAtLeast(0).toDouble(),
                        Distance.UNIT_KILOMETERS,
                    ),
                ),
                body.length - 1, body.length, Spanned.SPAN_INCLUSIVE_INCLUSIVE,
            )
            row.addText(spannable)
        } else {
            // Free navigation: no route distance to show; a Place on the
            // row satisfies PlaceListMapTemplate instead of a DistanceSpan.
            row.addText(speedStr)
            placeWithMarker(KEY_ME_LAT, KEY_ME_LON, CarColor.PRIMARY, "•")
                ?.let { row.setMetadata(Metadata.Builder().setPlace(it).build()) }
        }
        list.addItem(row.build())
    }

    private fun addEtaRowBrowsable(list: ItemList.Builder) {
        val etaMs = prefs.getLong(KEY_DEST_ETA_MS, 0L)
        if (etaMs <= 0) return
        val remaining = prefs.getLong(KEY_REMAINING_KM, 0L).toInt()
        list.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_eta_title))
                .addText(
                    carContext.getString(
                        R.string.aa_eta_body, formatHhmm(etaMs), remaining,
                    ),
                )
                .setBrowsable(true)
                .setOnClickListener { /* informational tap */ }
                .build(),
        )
        // Browsable rows don't need DistanceSpan — the tap target is enough.
    }

    // ---- Helpers --------------------------------------------------------

    private fun idleTemplate(): Template =
        MessageTemplate.Builder(carContext.getString(R.string.aa_idle_message))
            .setTitle(carContext.getString(R.string.aa_app_title))
            .setIcon(appIcon())
            .build()

    /** Companion is active but no trip data yet (GPS acquiring or no plan). */
    private fun companionActiveTemplate(): Template =
        MessageTemplate.Builder(carContext.getString(R.string.aa_companion_monitoring))
            .setTitle(carContext.getString(R.string.aa_companion_active))
            .setIcon(appIcon())
            .build()

    private fun startingTemplate(): Template =
        MessageTemplate.Builder(carContext.getString(R.string.aa_starting_message))
            .setTitle(carContext.getString(R.string.aa_app_title))
            .setIcon(appIcon())
            .build()

    private fun anchorPlace(): Place? {
        val meLat = prefDouble(KEY_ME_LAT)
        val meLon = prefDouble(KEY_ME_LON)
        if (!meLat.isNaN() && !meLon.isNaN()) {
            return Place.Builder(CarLocation.create(meLat, meLon)).build()
        }
        val destLat = prefDouble(KEY_DEST_LAT)
        val destLon = prefDouble(KEY_DEST_LON)
        if (!destLat.isNaN() && !destLon.isNaN()) {
            return Place.Builder(CarLocation.create(destLat, destLon)).build()
        }
        return null
    }

    private fun placeWithMarker(
        latKey: String, lonKey: String, color: CarColor, glyph: String,
    ): Place? {
        val lat = prefDouble(latKey)
        val lon = prefDouble(lonKey)
        if (lat.isNaN() || lon.isNaN()) return null
        val marker = PlaceMarker.Builder()
            .setColor(color)
            .setLabel(glyph)
            .build()
        return Place.Builder(CarLocation.create(lat, lon))
            .setMarker(marker)
            .build()
    }

    /**
     * Read a double stored by Flutter's shared_preferences_android 2.x.
     * The plugin encodes doubles as putString(key, DOUBLE_PREFIX + value)
     * rather than putFloat, so getFloat() always returns NaN.
     */
    private fun prefDouble(key: String): Double {
        val raw = prefs.getString(key, null) ?: return Double.NaN
        return if (raw.startsWith(FLUTTER_DOUBLE_PREFIX)) {
            raw.removePrefix(FLUTTER_DOUBLE_PREFIX).toDoubleOrNull() ?: Double.NaN
        } else {
            // Fallback: try direct float (old plugin versions).
            raw.toDoubleOrNull() ?: Double.NaN
        }
    }

    private fun appIcon(): CarIcon = CarIcon.Builder(
        IconCompat.createWithResource(carContext, R.mipmap.ic_launcher),
    ).build()

    companion object {
        // File the Flutter `shared_preferences` plugin writes to on
        // Android + the "flutter." prefix it applies to every key.
        // Keeping these hardcoded lets both processes read the same
        // bytes without needing a Method Channel round-trip.
        const val BRIDGE_PREFS = "FlutterSharedPreferences"
        const val KEY_ACTIVE_TRIP = "flutter.activeTrip"
        const val KEY_NEXT_STOP_NAME = "flutter.nextStopName"
        const val KEY_NEXT_STOP_ETA_MS = "flutter.nextStopEtaMs"
        const val KEY_NEXT_STOP_LAT = "flutter.nextStopLat"
        const val KEY_NEXT_STOP_LON = "flutter.nextStopLon"
        const val KEY_CHEAPER_FUEL_BRAND = "flutter.cheaperFuelBrand"
        const val KEY_CHEAPER_FUEL_KM = "flutter.cheaperFuelKm"
        const val KEY_CHEAPER_FUEL_CENTS = "flutter.cheaperFuelCents"
        const val KEY_CHEAPER_FUEL_LAT = "flutter.cheaperFuelLat"
        const val KEY_CHEAPER_FUEL_LON = "flutter.cheaperFuelLon"
        const val KEY_DEST_ETA_MS = "flutter.destinationEtaMs"
        const val KEY_REMAINING_KM = "flutter.remainingKm"
        const val KEY_TOTAL_KM = "flutter.totalKm"
        const val KEY_SPEED_KMH = "flutter.speedKmh"
        const val KEY_PROGRESS_KM = "flutter.progressKm"
        const val KEY_NOTIF_SOUND = "flutter.notificationSound"
        const val KEY_ME_LAT = "flutter.meLat"
        const val KEY_ME_LON = "flutter.meLon"
        const val KEY_DEST_LAT = "flutter.destLat"
        const val KEY_DEST_LON = "flutter.destLon"
        const val KEY_FUEL_LIST_JSON = "flutter.fuelListJson"
        const val KEY_RESTAURANTS_LIST_JSON = "flutter.restaurantsListJson"

        const val REFRESH_INTERVAL_MS = 5_000L

        // shared_preferences_android 2.x encodes doubles as
        // putString(key, DOUBLE_PREFIX + value.toString()).
        // Reading with getFloat() always returns NaN — use getString() instead.
        const val FLUTTER_DOUBLE_PREFIX =
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

        fun formatHhmm(millis: Long): String {
            val fmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
                .withZone(java.time.ZoneId.systemDefault())
            return fmt.format(java.time.Instant.ofEpochMilli(millis))
        }
    }
}
