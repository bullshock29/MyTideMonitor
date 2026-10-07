package com.mtm.my_tide_monitor

import org.json.JSONArray
import org.json.JSONObject

/** One high or low tide. [timeMs] is milliseconds since 1970 (UTC), [feet] is the height. */
data class Extreme(val timeMs: Long, val feet: Double, val isHigh: Boolean)

/**
 * The waves and water temperature near a location, as the app last read them.
 * Either may be missing. [readAtMs] is when they were read, so the widget can
 * say how old they are.
 */
data class Marine(val waveFeet: Double?, val waterCelsius: Double?, val readAtMs: Long)

/** One saved location, with the high and low tides the widget works from. */
data class WidgetLocation(
    val id: String,
    val name: String,
    val extremes: List<Extreme>,
    val marine: Marine? = null,
)

/** The colors for one look (light or dark), as Android ARGB integers. */
data class Palette(
    val background: Int,
    val onSurface: Int,
    val onSurfaceVariant: Int,
    val accent: Int,
    val border: Int,
)

/**
 * Everything the app sends the widgets: the saved locations with their tides,
 * waves and water temperature, the unit and time settings, and the colors. The
 * app writes it as JSON (see lib/services/widget_snapshot.dart on the Dart
 * side); this reads it.
 *
 * It says nothing about how an individual widget looks or which location it
 * shows. That is each widget's own [WidgetConfig].
 */
data class WidgetSnapshot(
    val generatedAtMs: Long,
    val useFeet: Boolean,
    val useFahrenheit: Boolean,
    val use24Hour: Boolean,
    val light: Palette,
    val dark: Palette,
    val locations: List<WidgetLocation>,
) {
    companion object {

        /** Reads the app's JSON. Returns null if it can't be read, so a bad snapshot never crashes the widget. */
        fun parse(json: String): WidgetSnapshot? {
            return try {
                val root = JSONObject(json)
                val palette = root.getJSONObject("palette")

                WidgetSnapshot(
                    generatedAtMs = root.getLong("generatedAt"),
                    useFeet = root.optString("heightUnit", "feet") != "meters",
                    useFahrenheit = root.optString("temperatureUnit", "fahrenheit") != "celsius",
                    use24Hour = root.optBoolean("use24Hour", false),
                    light = parsePalette(palette.getJSONObject("light")),
                    dark = parsePalette(palette.getJSONObject("dark")),
                    locations = parseLocations(root.getJSONArray("locations")),
                )
            } catch (e: Exception) {
                null
            }
        }

        // Colors arrive as unsigned numbers like 4294967295 (0xFFFFFFFF), which
        // is too big for an Int. Reading as a Long and converting gives the
        // same bits Android expects, with the sign wrapped.
        private fun parsePalette(json: JSONObject) = Palette(
            background = json.getLong("background").toInt(),
            onSurface = json.getLong("onSurface").toInt(),
            onSurfaceVariant = json.getLong("onSurfaceVariant").toInt(),
            accent = json.getLong("accent").toInt(),
            border = json.getLong("border").toInt(),
        )

        private fun parseLocations(array: JSONArray): List<WidgetLocation> {
            return (0 until array.length()).map { i ->
                val location = array.getJSONObject(i)
                WidgetLocation(
                    id = location.getString("id"),
                    name = location.getString("name"),
                    extremes = parseExtremes(location.getJSONArray("extremes")),
                    marine = location.optJSONObject("marine")?.let { parseMarine(it) },
                )
            }
        }

        // Either part can be null (the model has waves but no temperature, or the reverse).
        private fun parseMarine(json: JSONObject): Marine? {
            val waves = if (json.isNull("waveFeet")) null else json.optDouble("waveFeet").takeIf { !it.isNaN() }
            val water = if (json.isNull("waterCelsius")) null else json.optDouble("waterCelsius").takeIf { !it.isNaN() }
            if (waves == null && water == null) return null
            if (!json.has("readAt")) return null
            return Marine(waves, water, json.getLong("readAt"))
        }

        private fun parseExtremes(array: JSONArray): List<Extreme> {
            return (0 until array.length())
                .map { i ->
                    // Each one is [time in ms, feet, "H" or "L"].
                    val item = array.getJSONArray(i)
                    Extreme(
                        timeMs = item.getLong(0),
                        feet = item.getDouble(1),
                        isHigh = item.getString(2) == "H",
                    )
                }
                // The math below relies on them being in time order.
                .sortedBy { it.timeMs }
        }
    }
}
