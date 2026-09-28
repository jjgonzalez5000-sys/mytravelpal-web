package com.mytravelpal.travel.car

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarLocation
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

        val listBuilder = ItemList.Builder()

        // Row 1: next stop with map marker in the primary tint.
        addNextStopRow(listBuilder)
        // Row 2: cheaper fuel hint with the secondary marker tint.
        addCheaperFuelRow(listBuilder)
        // Row 3: destination ETA (not clickable — informational only).
        addEtaRow(listBuilder)
        // Row 4: entry to the full fuel-station list — clickable, pushes.
        addFuelListEntry(listBuilder)
        // Row 5: entry to the full restaurants list — clickable, pushes.
        addRestaurantsListEntry(listBuilder)

        val itemList = listBuilder.build()
        if (itemList.items.isEmpty()) return startingTemplate()

        val builder = PlaceListMapTemplate.Builder()
            .setTitle(carContext.getString(R.string.aa_app_title))
            .setHeaderAction(Action.APP_ICON)
            .setItemList(itemList)

        // Anchor the map on "me" when we know the GPS position; fall
        // back to the destination so at least the map isn't blank.
        anchorPlace()?.let(builder::setAnchor)
        return builder.build()
    }

    // ---- Row builders ---------------------------------------------------

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
        list.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_eta_title))
                .addText(
                    carContext.getString(
                        R.string.aa_eta_body, formatHhmm(etaMs), remaining,
                    ),
                )
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

    // ---- Helpers --------------------------------------------------------

    private fun idleTemplate(): Template =
        MessageTemplate.Builder(carContext.getString(R.string.aa_idle_message))
            .setTitle(carContext.getString(R.string.aa_app_title))
            .setIcon(appIcon())
            .build()

    private fun startingTemplate(): Template =
        MessageTemplate.Builder(carContext.getString(R.string.aa_starting_message))
            .setTitle(carContext.getString(R.string.aa_app_title))
            .setIcon(appIcon())
            .build()

    private fun anchorPlace(): Place? {
        val meLat = prefs.getFloat(KEY_ME_LAT, Float.NaN)
        val meLon = prefs.getFloat(KEY_ME_LON, Float.NaN)
        if (!meLat.isNaN() && !meLon.isNaN()) {
            return Place.Builder(
                CarLocation.create(meLat.toDouble(), meLon.toDouble()),
            ).build()
        }
        val destLat = prefs.getFloat(KEY_DEST_LAT, Float.NaN)
        val destLon = prefs.getFloat(KEY_DEST_LON, Float.NaN)
        if (!destLat.isNaN() && !destLon.isNaN()) {
            return Place.Builder(
                CarLocation.create(destLat.toDouble(), destLon.toDouble()),
            ).build()
        }
        return null
    }

    private fun placeWithMarker(
        latKey: String, lonKey: String, color: CarColor, glyph: String,
    ): Place? {
        val lat = prefs.getFloat(latKey, Float.NaN)
        val lon = prefs.getFloat(lonKey, Float.NaN)
        if (lat.isNaN() || lon.isNaN()) return null
        val marker = PlaceMarker.Builder()
            .setColor(color)
            .setLabel(glyph)
            .build()
        return Place.Builder(CarLocation.create(lat.toDouble(), lon.toDouble()))
            .setMarker(marker)
            .build()
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
        const val KEY_ME_LAT = "flutter.meLat"
        const val KEY_ME_LON = "flutter.meLon"
        const val KEY_DEST_LAT = "flutter.destLat"
        const val KEY_DEST_LON = "flutter.destLon"
        const val KEY_FUEL_LIST_JSON = "flutter.fuelListJson"
        const val KEY_RESTAURANTS_LIST_JSON = "flutter.restaurantsListJson"

        const val REFRESH_INTERVAL_MS = 5_000L

        fun formatHhmm(millis: Long): String {
            val fmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
                .withZone(java.time.ZoneId.systemDefault())
            return fmt.format(java.time.Instant.ofEpochMilli(millis))
        }
    }
}
