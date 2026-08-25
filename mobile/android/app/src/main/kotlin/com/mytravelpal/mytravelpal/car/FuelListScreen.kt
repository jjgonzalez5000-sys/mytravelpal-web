package com.mytravelpal.mytravelpal.car

import android.content.Context
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarLocation
import androidx.car.app.model.ItemList
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Metadata
import androidx.car.app.model.Place
import androidx.car.app.model.PlaceListMapTemplate
import androidx.car.app.model.PlaceMarker
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import com.mytravelpal.mytravelpal.R
import org.json.JSONArray

/**
 * Sub-screen: the fuel stations the plan surfaced, sorted the way
 * the phone response ordered them (cheapest / most-relevant first).
 *
 * Reads its list from the JSON payload written by
 * `car_bridge.dart#_kFuelListJson`. If parsing fails or the list is
 * empty we fall through to a friendly MessageTemplate so a bad
 * payload never crashes the AA session.
 */
class FuelListScreen(carContext: CarContext) : Screen(carContext) {

    private val prefs = carContext.getSharedPreferences(
        TripCompanionScreen.BRIDGE_PREFS, Context.MODE_PRIVATE,
    )

    override fun onGetTemplate(): Template {
        val raw = prefs.getString(TripCompanionScreen.KEY_FUEL_LIST_JSON, null)
        val stations = parseStations(raw)
        if (stations.isEmpty()) return emptyTemplate()

        val list = ItemList.Builder()
        for (s in stations) {
            val subtitle = buildString {
                if (s.pricePerL != null) {
                    append(carContext.getString(
                        R.string.aa_fuel_row_price, s.pricePerL,
                    ))
                } else {
                    append(carContext.getString(R.string.aa_fuel_row_no_price))
                }
                append(" · ")
                append(carContext.getString(R.string.aa_km_from_origin, s.km))
            }
            val row = Row.Builder()
                .setTitle(s.name)
                .addText(subtitle)
            if (s.lat != null && s.lon != null) {
                row.setMetadata(
                    Metadata.Builder().setPlace(
                        Place.Builder(CarLocation.create(s.lat, s.lon))
                            .setMarker(
                                PlaceMarker.Builder()
                                    .setColor(CarColor.SECONDARY)
                                    .setLabel("⛽")
                                    .build(),
                            )
                            .build(),
                    ).build(),
                )
            }
            list.addItem(row.build())
        }

        return PlaceListMapTemplate.Builder()
            .setTitle(carContext.getString(R.string.aa_fuel_list_title))
            .setHeaderAction(Action.BACK)
            .setItemList(list.build())
            .build()
    }

    private fun emptyTemplate(): Template =
        MessageTemplate.Builder(
            carContext.getString(R.string.aa_list_empty),
        )
            .setTitle(carContext.getString(R.string.aa_fuel_list_title))
            .setHeaderAction(Action.BACK)
            .build()

    private data class Station(
        val name: String,
        val pricePerL: Double?,
        val km: Int,
        val lat: Double?,
        val lon: Double?,
    )

    private fun parseStations(raw: String?): List<Station> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                Station(
                    name = obj.optString("name", "?"),
                    pricePerL = if (obj.isNull("priceEurPerL")) null
                                else obj.optDouble("priceEurPerL"),
                    km = obj.optInt("kmFromOrigin", 0),
                    lat = if (obj.isNull("lat")) null
                          else obj.optDouble("lat"),
                    lon = if (obj.isNull("lon")) null
                          else obj.optDouble("lon"),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
