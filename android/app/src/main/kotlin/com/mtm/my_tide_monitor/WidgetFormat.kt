package com.mtm.my_tide_monitor

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/** The words the widget shows. Android passes in the translated ones; these are the English defaults. */
data class Labels(
    val high: String = "High",
    val low: String = "Low",
    val rising: String = "Rising",
    val falling: String = "Falling",
    val needsRefresh: String = "Open My Tide Monitor to refresh",
    val nextHigh: String = "Next high",
    val nextLow: String = "Next low",
    val waves: String = "Waves",
    val water: String = "Water",
    val calm: String = "Calm",
    val small: String = "Small",
    val moderate: String = "Moderate",
    val large: String = "Large",
    val veryLarge: String = "Very large",
    /** Has one number in it: the hours, as in "3h ago". */
    val hoursAgo: String = "%dh ago",
)

/** What one row of the widget says, ready to put on screen. */
data class RowModel(
    val id: String,
    val name: String,
    /** The tide height now, like "3.2 ft". Empty if it isn't known. */
    val height: String,
    /** "▲ Rising" or "▼ Falling". Empty if it isn't known. */
    val direction: String,
    val rising: Boolean?,
    /** The next high and low, like "Low 10:38 PM · High 4:48 AM", or a message if the tides ran out. */
    val detail: String,
)

/** One small box of the tide tile: a label, the main value, and a line under it. */
data class Cell(val label: String, val value: String, val sub: String)

/** What the tide tile says, ready to put on screen. */
data class TileModel(
    val id: String,
    val name: String,
    /** The tide height now, like "3.2 ft". Empty if it isn't known. */
    val height: String,
    /** "▲ Rising" or "▼ Falling". Empty if it isn't known. */
    val direction: String,
    val rising: Boolean?,
    val nextHigh: Cell?,
    val nextLow: Cell?,
    /** Null when there is nothing trustworthy to say about the waves. */
    val waves: Cell?,
    /** Null when there is nothing trustworthy to say about the water temperature. */
    val water: Cell?,
    /** Shown instead of the boxes when the tides ran out. */
    val message: String?,
)

/** Turns tide data into the text shown on the widget, in the units and time format the user chose. */
object WidgetFormat {
    private const val FEET_PER_METER = 3.28084

    /** "3.2 ft" or "0.98 m". Never "-0.0". */
    fun heightText(feet: Double, useFeet: Boolean): String {
        val value = if (useFeet) feet else feet / FEET_PER_METER
        val text = String.format(Locale.US, "%.${if (useFeet) 1 else 2}f", value)
        val shown = if (text.toDouble() == 0.0) text.removePrefix("-") else text
        return "$shown ${if (useFeet) "ft" else "m"}"
    }

    /** "72°F" or "22°C", to the nearest degree. Never "-0°". */
    fun temperatureText(celsius: Double, useFahrenheit: Boolean): String {
        val value = if (useFahrenheit) celsius * 9 / 5 + 32 else celsius
        val text = String.format(Locale.US, "%.0f", value)
        val shown = if (text.toDouble() == 0.0) text.removePrefix("-") else text
        return "$shown°${if (useFahrenheit) "F" else "C"}"
    }

    /**
     * A wave height the way people say it: feet to the nearest half foot
     * ("2.5 ft", "3 ft"), meters to a tenth ("0.8 m").
     */
    fun waveText(feet: Double, useFeet: Boolean): String {
        if (!useFeet) return String.format(Locale.US, "%.1f m", feet / FEET_PER_METER)
        val rounded = Math.round(feet * 2) / 2.0
        val text = if (rounded == Math.floor(rounded)) String.format(Locale.US, "%.0f", rounded) else String.format(Locale.US, "%.1f", rounded)
        return "$text ft"
    }

    /** A plain word for how big the waves are (takes feet whatever unit is shown). */
    fun waveSize(feet: Double, labels: Labels): String = when {
        feet < 1 -> labels.calm
        feet < 2 -> labels.small
        feet < 4 -> labels.moderate
        feet < 6 -> labels.large
        else -> labels.veryLarge
    }

    /** "4:48 PM" or "16:48", in the phone's time zone. */
    fun clockText(timeMs: Long, use24Hour: Boolean, zone: TimeZone, locale: Locale): String {
        val clock = SimpleDateFormat(if (use24Hour) "HH:mm" else "h:mm a", locale)
        clock.timeZone = zone
        return clock.format(timeMs)
    }

    /** "Wed", in the phone's time zone. */
    fun weekdayText(timeMs: Long, zone: TimeZone, locale: Locale): String {
        val weekday = SimpleDateFormat("EEE", locale)
        weekday.timeZone = zone
        return weekday.format(timeMs)
    }

    /**
     * "4:48 PM" for a time today, "Wed 4:48 PM" for any other day (or "16:48" and
     * "Wed 16:48" with the 24-hour setting), in the phone's time zone.
     */
    fun timeText(timeMs: Long, nowMs: Long, use24Hour: Boolean, zone: TimeZone, locale: Locale): String {
        val time = clockText(timeMs, use24Hour, zone, locale)
        if (sameDay(timeMs, nowMs, zone)) return time
        return "${weekdayText(timeMs, zone, locale)} $time"
    }

    private fun sameDay(a: Long, b: Long, zone: TimeZone): Boolean {
        val first = Calendar.getInstance(zone).apply { timeInMillis = a }
        val second = Calendar.getInstance(zone).apply { timeInMillis = b }
        return first.get(Calendar.YEAR) == second.get(Calendar.YEAR) &&
            first.get(Calendar.DAY_OF_YEAR) == second.get(Calendar.DAY_OF_YEAR)
    }

    /** What to show for [location] at [nowMs]. */
    fun buildRow(
        location: WidgetLocation,
        snapshot: WidgetSnapshot,
        nowMs: Long,
        zone: TimeZone,
        locale: Locale,
        labels: Labels = Labels(),
    ): RowModel {
        val height = TideMath.heightAt(location.extremes, nowMs)

        // The saved tides don't cover now (the app hasn't been opened in a
        // couple of weeks, or the tides couldn't be loaded). Say so instead
        // of showing a wrong number.
        if (height == null) {
            return RowModel(location.id, location.name, "", "", null, labels.needsRefresh)
        }

        val rising = TideMath.isRising(location.extremes, nowMs)
        val direction = when (rising) {
            true -> "▲ ${labels.rising}"
            false -> "▼ ${labels.falling}"
            null -> ""
        }

        // The next low and the next high, whichever comes first, first.
        val upcoming = listOfNotNull(
            TideMath.nextHigh(location.extremes, nowMs)?.let { it to labels.high },
            TideMath.nextLow(location.extremes, nowMs)?.let { it to labels.low },
        ).sortedBy { it.first.timeMs }
        val detail = upcoming.joinToString(" · ") { (extreme, label) ->
            "$label ${timeText(extreme.timeMs, nowMs, snapshot.use24Hour, zone, locale)}"
        }

        return RowModel(
            id = location.id,
            name = location.name,
            height = heightText(height, snapshot.useFeet),
            direction = direction,
            rising = rising,
            detail = detail,
        )
    }

    /** Waves and water temperature are forecasts, so they are not shown once this old. */
    const val MARINE_MAX_AGE_MS = 24L * 60 * 60 * 1000

    /** Past this age they are shown with how old they are instead of their usual note. */
    const val MARINE_STALE_AGE_MS = 3L * 60 * 60 * 1000

    /** What the tide tile for [location] says at [nowMs]. */
    fun buildTile(
        location: WidgetLocation,
        snapshot: WidgetSnapshot,
        nowMs: Long,
        zone: TimeZone,
        locale: Locale,
        labels: Labels = Labels(),
    ): TileModel {
        val height = TideMath.heightAt(location.extremes, nowMs)

        // The saved tides don't cover now: say so instead of showing wrong numbers.
        if (height == null) {
            return TileModel(location.id, location.name, "", "", null, null, null, null, null, labels.needsRefresh)
        }

        val rising = TideMath.isRising(location.extremes, nowMs)
        val direction = when (rising) {
            true -> "▲ ${labels.rising}"
            false -> "▼ ${labels.falling}"
            null -> ""
        }

        val (waves, water) = marineCells(location.marine, snapshot, nowMs, labels)

        return TileModel(
            id = location.id,
            name = location.name,
            height = heightText(height, snapshot.useFeet),
            direction = direction,
            rising = rising,
            nextHigh = tideCell(labels.nextHigh, TideMath.nextHigh(location.extremes, nowMs), snapshot, nowMs, zone, locale),
            nextLow = tideCell(labels.nextLow, TideMath.nextLow(location.extremes, nowMs), snapshot, nowMs, zone, locale),
            waves = waves,
            water = water,
            message = null,
        )
    }

    // "Next high / 4:48 PM / Wed 4.1 ft" (no weekday when it's today).
    private fun tideCell(
        label: String,
        tide: Extreme?,
        snapshot: WidgetSnapshot,
        nowMs: Long,
        zone: TimeZone,
        locale: Locale,
    ): Cell {
        if (tide == null) return Cell(label, "—", "")
        val height = heightText(tide.feet, snapshot.useFeet)
        val sub = if (sameDay(tide.timeMs, nowMs, zone)) height else "${weekdayText(tide.timeMs, zone, locale)} $height"
        return Cell(label, clockText(tide.timeMs, snapshot.use24Hour, zone, locale), sub)
    }

    // The waves box and the water temperature box. Each is null when it has
    // nothing to say: never read, only part of it known, or too old to trust.
    private fun marineCells(marine: Marine?, snapshot: WidgetSnapshot, nowMs: Long, labels: Labels): Pair<Cell?, Cell?> {
        if (marine == null) return null to null
        val age = nowMs - marine.readAtMs
        if (age > MARINE_MAX_AGE_MS) return null to null

        // Fresh readings carry their usual note; older ones say how old they are.
        val stale = if (age > MARINE_STALE_AGE_MS) String.format(Locale.US, labels.hoursAgo, age / 3_600_000L) else null

        val waves = marine.waveFeet?.let {
            Cell(labels.waves, waveText(it, snapshot.useFeet), stale ?: waveSize(it, labels))
        }
        val water = marine.waterCelsius?.let {
            Cell(labels.water, temperatureText(it, snapshot.useFahrenheit), stale ?: "")
        }
        return waves to water
    }
}
