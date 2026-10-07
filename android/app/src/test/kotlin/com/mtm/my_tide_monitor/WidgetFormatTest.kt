package com.mtm.my_tide_monitor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale
import java.util.TimeZone

class WidgetFormatTest {
    private val newYork = TimeZone.getTimeZone("America/New_York")
    private val us = Locale.US

    // Newer Java versions put a narrow no-break space before AM/PM. It looks
    // the same, so compare with a normal space.
    private fun normal(text: String) = text.replace(' ', ' ').replace(' ', ' ')

    // 2026-10-06 21:00 UTC is 17:00 (5 PM) in New York (daylight time).
    private val now = 1791320400000L

    private fun timeText(timeMs: Long, use24Hour: Boolean = false) =
        normal(WidgetFormat.timeText(timeMs, now, use24Hour, newYork, us))

    @Test
    fun feetAreShownToOneDecimal() {
        assertEquals("3.2 ft", WidgetFormat.heightText(3.2, true))
        assertEquals("6.0 ft", WidgetFormat.heightText(6.003, true))
        assertEquals("0.6 ft", WidgetFormat.heightText(0.629, true))
        assertEquals("-0.6 ft", WidgetFormat.heightText(-0.6, true))
    }

    @Test
    fun metersAreConvertedAndShownToTwoDecimals() {
        assertEquals("0.98 m", WidgetFormat.heightText(3.2, false)) // 3.2 ft
        assertEquals("1.83 m", WidgetFormat.heightText(6.003, false))
        assertEquals("1.65 m", WidgetFormat.heightText(5.4, false))
    }

    @Test
    fun aTinyNegativeHeightNeverShowsAsMinusZero() {
        assertEquals("0.0 ft", WidgetFormat.heightText(-0.04, true))
        assertEquals("0.00 m", WidgetFormat.heightText(-0.01, false))
    }

    @Test
    fun matchesTheAppsHeightFormatting() {
        // The same numbers the Dart tests use (test/settings_service_test.dart).
        assertEquals("5.4 ft", WidgetFormat.heightText(5.4, true))
        assertEquals("1.65 m", WidgetFormat.heightText(5.4, false))
        assertEquals("3.05 m", WidgetFormat.heightText(10.0, false))
    }

    @Test
    fun aTimeTodayHasNoDayName() {
        // 22:48 UTC is 6:48 PM in New York, later the same day as "now".
        val sixFortyEightPm = 1791326880000L
        assertEquals("6:48 PM", timeText(sixFortyEightPm))
        assertEquals("18:48", timeText(sixFortyEightPm, use24Hour = true))
    }

    @Test
    fun aTimeOnAnotherDayHasTheDayName() {
        // "Now" is Tuesday Oct 6 at 5 PM in New York. The next morning is Wednesday.
        val nextMorning = 1791354600000L // 2026-10-07 06:30 UTC = 2:30 AM Wed
        assertEquals("Wed 2:30 AM", timeText(nextMorning))
        assertEquals("Wed 02:30", timeText(nextMorning, use24Hour = true))
    }

    @Test
    fun twentyFourHourTimesHaveALeadingZero() {
        val fiveAm = 1791277200000L // 2026-10-06 09:00 UTC = 5:00 AM New York, today
        assertEquals("5:00 AM", timeText(fiveAm))
        assertEquals("05:00", timeText(fiveAm, use24Hour = true))
    }

    @Test
    fun theDayIsJudgedInThePhonesTimeZoneNotUtc() {
        // 02:00 UTC on Oct 7 is still 10 PM on Oct 6 in New York, so it is
        // "today" there even though the UTC date has moved on.
        val tenPmInNewYork = 1791338400000L
        assertEquals("10:00 PM", timeText(tenPmInNewYork))

        // 12:00 UTC on Oct 6 is the same day as "now" in New York (8 AM Oct 6)...
        val noonUtc = 1791288000000L
        assertEquals("8:00 AM", timeText(noonUtc))

        // ...but in Tokyo "now" is already Oct 7 (6 AM), so that moment (9 PM
        // Oct 6) is yesterday and needs its day name.
        val tokyo = TimeZone.getTimeZone("Asia/Tokyo")
        assertEquals("Tue 9:00 PM", normal(WidgetFormat.timeText(noonUtc, now, false, tokyo, us)))
    }

    // ---- whole rows ----

    private fun snapshot(useFeet: Boolean = true, use24Hour: Boolean = false, useFahrenheit: Boolean = true) = WidgetSnapshot(
        generatedAtMs = now,
        useFeet = useFeet,
        useFahrenheit = useFahrenheit,
        use24Hour = use24Hour,
        light = WidgetTheme.fallback(false).palette,
        dark = WidgetTheme.fallback(true).palette,
        locations = emptyList(),
    )

    // Springmaid Pier: low 14:38, high 20:48, low 03:29 (next day), high 09:22 (UTC).
    private val beach = WidgetLocation(
        id = "8661070",
        name = "The Beach",
        extremes = listOf(
            Extreme(1791297480000, 0.629, false),
            Extreme(1791319680000, 6.003, true),
            Extreme(1791343740000, 0.671, false),
            Extreme(1791364920000, 5.677, true),
        ),
    )

    private fun row(
        location: WidgetLocation,
        at: Long,
        snapshot: WidgetSnapshot = snapshot(),
    ): RowModel {
        val row = WidgetFormat.buildRow(location, snapshot, at, newYork, us)
        return row.copy(detail = normal(row.detail))
    }

    @Test
    fun aRowHasTheNameTheHeightNowAndTheNextTides() {
        // 17:43 UTC = 1:43 PM New York, halfway up the rise to the 20:48 UTC high.
        val row = row(beach, 1791308580000L)

        assertEquals("8661070", row.id)
        assertEquals("The Beach", row.name)
        assertEquals("3.3 ft", row.height)
        assertEquals("▲ Rising", row.direction)
        assertEquals(true, row.rising)
        // The next high (4:48 PM) comes before the next low (11:29 PM).
        assertEquals("High 4:48 PM · Low 11:29 PM", row.detail)
    }

    @Test
    fun aFallingTideSaysSo() {
        val row = row(beach, 1791324000000L) // 22:00 UTC, past the high
        assertEquals("▼ Falling", row.direction)
        assertEquals(false, row.rising)
        assertEquals("Low 11:29 PM · High Wed 5:22 AM", row.detail)
    }

    @Test
    fun theNextTidesAreListedInTheOrderTheyHappen() {
        val rising = row(beach, 1791308580000L).detail
        val falling = row(beach, 1791324000000L).detail

        assertTrue(rising.startsWith("High"))
        assertTrue(falling.startsWith("Low"))
    }

    @Test
    fun theRowFollowsTheUnitsAndTimeFormat() {
        val row = row(beach, 1791308580000L, snapshot(useFeet = false, use24Hour = true))

        assertEquals("1.01 m", row.height) // 3.3 ft
        assertEquals("High 16:48 · Low 23:29", row.detail)
    }

    @Test
    fun theRowsAreInTheWordsOfTheLabels() {
        val french = Labels(high = "Haute", low = "Basse", rising = "Montante", falling = "Descendante")
        val row = WidgetFormat.buildRow(beach, snapshot(), 1791308580000L, newYork, us, french)

        assertEquals("▲ Montante", row.direction)
        assertTrue(normal(row.detail).startsWith("Haute"))
        assertTrue(normal(row.detail).contains("Basse"))
    }

    @Test
    fun whenTheSavedTidesHaveRunOutTheRowSaysToOpenTheApp() {
        val farFuture = 1791364920000L + 10 * 24 * 3_600_000L
        val row = row(beach, farFuture)

        assertEquals("The Beach", row.name)
        assertEquals("", row.height)
        assertEquals("", row.direction)
        assertNull(row.rising)
        assertEquals("Open My Tide Monitor to refresh", row.detail)
    }

    @Test
    fun aLocationWithNoTidesAtAllSaysToOpenTheApp() {
        val none = WidgetLocation("x", "Nowhere", emptyList())
        val row = row(none, now)

        assertEquals("Open My Tide Monitor to refresh", row.detail)
        assertEquals("", row.height)
    }

    @Test
    fun theLastTideBeforeTheDataEndsStillShowsWhatItCan() {
        // Between the last low and the last high there is no "next low", only the high.
        val row = row(beach, 1791350000000L) // 04:53 UTC Oct 7
        assertEquals("▲ Rising", row.direction)
        assertTrue(row.detail.startsWith("High"))
        assertFalse(row.detail.contains("Low"))
    }

    @Test
    fun aNameWithUnusualCharactersIsKeptAsIs() {
        val odd = beach.copy(name = "Joe's \"Place\" & Café ☀")
        assertEquals("Joe's \"Place\" & Café ☀", row(odd, 1791308580000L).name)
    }

    // ---- temperatures and waves ----

    @Test
    fun temperaturesAreRoundedToTheDegreeInTheChosenUnit() {
        assertEquals("72\u00B0F", WidgetFormat.temperatureText(22.0, true))
        assertEquals("71\u00B0F", WidgetFormat.temperatureText(21.5, true)) // 70.7
        assertEquals("22\u00B0C", WidgetFormat.temperatureText(21.5, false))
        assertEquals("32\u00B0F", WidgetFormat.temperatureText(0.0, true))
    }

    @Test
    fun aTemperatureNearZeroNeverShowsAsMinusZero() {
        assertEquals("0\u00B0F", WidgetFormat.temperatureText(-17.9, true)) // -0.2 F
        assertEquals("0\u00B0C", WidgetFormat.temperatureText(-0.3, false))
        assertEquals("-3\u00B0C", WidgetFormat.temperatureText(-3.0, false))
    }

    @Test
    fun matchesTheAppsTemperatureFormatting() {
        // Same as SettingsService.formatTemperature(22) in the Dart tests.
        assertEquals("72\u00B0F", WidgetFormat.temperatureText(22.0, true))
        assertEquals("22\u00B0C", WidgetFormat.temperatureText(22.0, false))
    }

    @Test
    fun waveHeightsInFeetAreRoundedToTheNearestHalfFoot() {
        assertEquals("0.5 ft", WidgetFormat.waveText(0.4, true))
        assertEquals("1 ft", WidgetFormat.waveText(1.0, true))
        assertEquals("2.5 ft", WidgetFormat.waveText(2.4, true))
        assertEquals("3 ft", WidgetFormat.waveText(3.24, true))
        assertEquals("3.5 ft", WidgetFormat.waveText(3.26, true))
        assertEquals("10 ft", WidgetFormat.waveText(10.1, true))
    }

    @Test
    fun waveHeightsInMetersAreShownToATenth() {
        assertEquals("0.9 m", WidgetFormat.waveText(3.0, false))
        assertEquals("3.0 m", WidgetFormat.waveText(10.0, false))
        assertEquals("0.7 m", WidgetFormat.waveText(2.4, false))
    }

    @Test
    fun waveSizesHaveAPlainWord() {
        val labels = Labels()
        assertEquals("Calm", WidgetFormat.waveSize(0.99, labels))
        assertEquals("Small", WidgetFormat.waveSize(1.0, labels))
        assertEquals("Small", WidgetFormat.waveSize(1.99, labels))
        assertEquals("Moderate", WidgetFormat.waveSize(2.0, labels))
        assertEquals("Moderate", WidgetFormat.waveSize(3.99, labels))
        assertEquals("Large", WidgetFormat.waveSize(4.0, labels))
        assertEquals("Large", WidgetFormat.waveSize(5.99, labels))
        assertEquals("Very large", WidgetFormat.waveSize(6.0, labels))
    }

    // ---- the tide tile ----

    private val halfAnHour = 30 * 60_000L
    private val hour = 3_600_000L

    // 1:43 PM New York on Oct 6, halfway up to the 4:48 PM high.
    private val risingAt = 1791308580000L

    private fun withMarine(marine: Marine?) = beach.copy(marine = marine)

    private fun tile(
        location: WidgetLocation,
        at: Long = risingAt,
        snapshot: WidgetSnapshot = snapshot(),
    ): TileModel = WidgetFormat.buildTile(location, snapshot, at, newYork, us).let { model ->
        fun Cell?.plain() = this?.copy(value = normal(value), sub = normal(sub))
        model.copy(nextHigh = model.nextHigh.plain(), nextLow = model.nextLow.plain(), waves = model.waves.plain(), water = model.water.plain())
    }

    @Test
    fun aTileHasTheNameTheTideNowAndTheNextHighAndLow() {
        val tile = tile(beach)

        assertEquals("8661070", tile.id)
        assertEquals("The Beach", tile.name)
        assertEquals("3.3 ft", tile.height)
        assertEquals("\u25B2 Rising", tile.direction)
        assertNull(tile.message)
        assertEquals(Cell("Next high", "4:48 PM", "6.0 ft"), tile.nextHigh)
        assertEquals(Cell("Next low", "11:29 PM", "0.7 ft"), tile.nextLow)
    }

    @Test
    fun aTideOnAnotherDayNamesTheDay() {
        // 6 PM: the next low is tonight, the next high is tomorrow morning.
        val tile = tile(beach, at = 1791324000000L)

        assertEquals(Cell("Next low", "11:29 PM", "0.7 ft"), tile.nextLow)
        assertEquals(Cell("Next high", "5:22 AM", "Wed 5.7 ft"), tile.nextHigh)
    }

    @Test
    fun theTileFollowsTheUnitsAndTimeFormat() {
        val tile = tile(beach, snapshot = snapshot(useFeet = false, use24Hour = true))

        assertEquals("1.01 m", tile.height)
        assertEquals(Cell("Next high", "16:48", "1.83 m"), tile.nextHigh)
    }

    @Test
    fun whenThereIsNoMoreHighOrLowAheadTheBoxSaysSo() {
        // Between the last low and the last high there is no next low.
        val tile = tile(beach, at = 1791350000000L)

        assertEquals(Cell("Next low", "\u2014", ""), tile.nextLow)
        assertEquals("Next high", tile.nextHigh!!.label)
    }

    @Test
    fun wavesAndWaterTemperatureAreShownWhenKnown() {
        val tile = tile(withMarine(Marine(2.4, 21.5, readAtMs = risingAt - halfAnHour)))

        assertEquals(Cell("Waves", "2.5 ft", "Moderate"), tile.waves)
        assertEquals(Cell("Water", "71\u00B0F", ""), tile.water)
    }

    @Test
    fun wavesAndWaterTemperatureFollowTheUnits() {
        val tile = tile(
            withMarine(Marine(2.4, 21.5, readAtMs = risingAt)),
            snapshot = snapshot(useFeet = false, useFahrenheit = false),
        )

        assertEquals(Cell("Waves", "0.7 m", "Moderate"), tile.waves)
        assertEquals(Cell("Water", "22\u00B0C", ""), tile.water)
    }

    @Test
    fun aPlaceWithNoWaterConditionsHasNoWavesOrWaterBox() {
        val tile = tile(beach)

        assertNull(tile.waves)
        assertNull(tile.water)
        assertNotNull(tile.nextHigh) // the rest is unaffected
    }

    @Test
    fun onlyThePartThatIsKnownGetsABox() {
        val onlyWaves = tile(withMarine(Marine(1.5, null, risingAt)))
        assertEquals("Waves", onlyWaves.waves!!.label)
        assertNull(onlyWaves.water)

        val onlyWater = tile(withMarine(Marine(null, 18.0, risingAt)))
        assertNull(onlyWater.waves)
        assertEquals("Water", onlyWater.water!!.label)
    }

    @Test
    fun readingsOlderThanAFewHoursSayHowOldTheyAre() {
        val fresh = tile(withMarine(Marine(2.4, 21.5, readAtMs = risingAt - 3 * hour)))
        assertEquals("Moderate", fresh.waves!!.sub) // exactly 3 hours is still fresh

        val older = tile(withMarine(Marine(2.4, 21.5, readAtMs = risingAt - 5 * hour - halfAnHour)))
        assertEquals("5h ago", older.waves!!.sub)
        assertEquals("5h ago", older.water!!.sub)
    }

    @Test
    fun readingsOlderThanADayAreNotShownAtAll() {
        val tile = tile(withMarine(Marine(2.4, 21.5, readAtMs = risingAt - 24 * hour - 1)))
        assertNull(tile.waves)
        assertNull(tile.water)

        val almost = tile(withMarine(Marine(2.4, 21.5, readAtMs = risingAt - 23 * hour)))
        assertEquals("23h ago", almost.waves!!.sub)
    }

    @Test
    fun aReadingFromTheFutureIsTreatedAsFresh() {
        // The phone's clock was set back; don't hide good data over it.
        val tile = tile(withMarine(Marine(2.4, 21.5, readAtMs = risingAt + hour)))
        assertEquals("Moderate", tile.waves!!.sub)
    }

    @Test
    fun whenTheSavedTidesHaveRunOutTheTileSaysToOpenTheApp() {
        val farFuture = 1791364920000L + 10 * 24 * hour
        val tile = tile(withMarine(Marine(2.4, 21.5, readAtMs = farFuture)), at = farFuture)

        assertEquals("The Beach", tile.name)
        assertEquals("Open My Tide Monitor to refresh", tile.message)
        assertEquals("", tile.height)
        assertNull(tile.nextHigh)
        assertNull(tile.waves)
    }

    @Test
    fun theTilesWordsComeFromTheLabels() {
        val labels = Labels(nextHigh = "Haute", nextLow = "Basse", waves = "Vagues", water = "Eau", moderate = "Mod\u00E9r\u00E9es")
        val model = WidgetFormat.buildTile(withMarine(Marine(2.4, 21.5, risingAt)), snapshot(), risingAt, newYork, us, labels)

        assertEquals("Haute", model.nextHigh!!.label)
        assertEquals("Basse", model.nextLow!!.label)
        assertEquals("Vagues", model.waves!!.label)
        assertEquals("Eau", model.water!!.label)
        assertEquals("Mod\u00E9r\u00E9es", model.waves.sub)
    }
}
