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
 * Sub-screen: the restaurants the plan surfaced.
 * See [FuelListScreen] for the parse-and-render pattern — this is
 * the twin implementation for the restaurants JSON payload.
 */
class RestaurantsListScreen(carContext: CarContext) : Screen(carContext) {

    private val prefs = carContext.getSharedPreferences(
        TripCompanionScreen.BRIDGE_PREFS, Context.MODE_PRIVATE,
    )

    override fun onGetTemplate(): Template {
        val raw = prefs.getString(
            TripCompanionScreen.KEY_RESTAURANTS_LIST_JSON, null,
        )
        val restaurants = parse(raw)
        if (restaurants.isEmpty()) return emptyTemplate()

        val list = ItemList.Builder()
        for (r in restaurants) {
            val subtitle = carContext.getString(
                R.string.aa_restaurant_row_body,
                r.priceBand, r.pricePerMeal, r.detourMinutes,
            )
            val row = Row.Builder()
                .setTitle(r.name)
                .addText(subtitle)
                .setMetadata(
                    Metadata.Builder().setPlace(
                        Place.Builder(CarLocation.create(r.lat, r.lon))
                            .setMarker(
                                PlaceMarker.Builder()
                                    .setColor(CarColor.PRIMARY)
                                    .setLabel("🍽")
                                    .build(),
                            )
                            .build(),
                    ).build(),
                )
                .build()
            list.addItem(row)
        }

        return PlaceListMapTemplate.Builder()
            .setTitle(carContext.getString(R.string.aa_restaurants_list_title))
            .setHeaderAction(Action.BACK)
            .setItemList(list.build())
            .build()
    }

    private fun emptyTemplate(): Template =
        MessageTemplate.Builder(carContext.getString(R.string.aa_list_empty))
            .setTitle(carContext.getString(R.string.aa_restaurants_list_title))
            .setHeaderAction(Action.BACK)
            .build()

    private data class Item(
        val name: String,
        val pricePerMeal: Double,
        val priceBand: String,
        val detourMinutes: Int,
        val lat: Double,
        val lon: Double,
    )

    private fun parse(raw: String?): List<Item> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.getJSONObject(i)
                if (o.isNull("lat") || o.isNull("lon")) return@mapNotNull null
                Item(
                    name = o.optString("name", "?"),
                    pricePerMeal = o.optDouble("priceEurPerMeal", 0.0),
                    priceBand = o.optString("priceBand", "?"),
                    detourMinutes = o.optInt("detourMinutes", 0),
                    lat = o.optDouble("lat"),
                    lon = o.optDouble("lon"),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
