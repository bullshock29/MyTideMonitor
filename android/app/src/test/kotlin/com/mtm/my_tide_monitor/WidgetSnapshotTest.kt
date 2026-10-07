package com.mtm.my_tide_monitor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetSnapshotTest {
    // A snapshot exactly as the app's Dart code produces it (see
    // lib/services/widget_snapshot.dart), with meters, Celsius, 24-hour time
    // and the green theme. The first location has waves and water temperature.
    private val fromTheApp =
        """{"version":2,"generatedAt":1791288000000,"heightUnit":"meters","temperatureUnit":"celsius","use24Hour":true,"palette":{"light":{"background":4292407264,"onSurface":4279442967,"onSurfaceVariant":4282141248,"accent":4278218052,"border":4285299568},"dark":{"background":4278794020,"onSurface":4292470491,"onSurfaceVariant":4290497470,"accent":4278248082,"border":4286944393}},"locations":[{"id":"8661070","name":"The Beach","extremes":[[1791297480000,0.629,"L"],[1791319680000,6.003,"H"],[1791343740000,0.671,"L"]],"marine":{"waveFeet":2.4,"waterCelsius":21.5,"readAt":1791286200000}},{"id":"8660854","name":"Combination Bridge","extremes":[]}]}"""

    @Test
    fun readsWhatTheAppSends() {
        val snapshot = WidgetSnapshot.parse(fromTheApp)!!

        assertEquals(1791288000000, snapshot.generatedAtMs)
        assertFalse(snapshot.useFeet)
        assertFalse(snapshot.useFahrenheit)
        assertTrue(snapshot.use24Hour)
        assertEquals(2, snapshot.locations.size)
    }

    @Test
    fun readsTheWavesAndWaterTemperatureOfALocationThatHasThem() {
        val beach = WidgetSnapshot.parse(fromTheApp)!!.locations[0]

        assertEquals(Marine(waveFeet = 2.4, waterCelsius = 21.5, readAtMs = 1791286200000), beach.marine)
    }

    @Test
    fun aLocationWithoutThemHasNone() {
        val bridge = WidgetSnapshot.parse(fromTheApp)!!.locations[1]
        assertNull(bridge.marine)
    }

    @Test
    fun readsTheLocationsInOrderWithTheirTides() {
        val snapshot = WidgetSnapshot.parse(fromTheApp)!!

        val beach = snapshot.locations[0]
        assertEquals("8661070", beach.id)
        assertEquals("The Beach", beach.name)
        assertEquals(
            listOf(
                Extreme(1791297480000, 0.629, false),
                Extreme(1791319680000, 6.003, true),
                Extreme(1791343740000, 0.671, false),
            ),
            beach.extremes,
        )

        val bridge = snapshot.locations[1]
        assertEquals("Combination Bridge", bridge.name)
        assertTrue(bridge.extremes.isEmpty())
    }

    @Test
    fun readsTheColorsAsAndroidColorNumbers() {
        val snapshot = WidgetSnapshot.parse(fromTheApp)!!

        // Dart sends 4278248082 (0xFF00E292); Android wants the same bits as a signed Int.
        assertEquals(0xFF00E292.toInt(), snapshot.dark.accent)
        assertEquals(4278248082L.toInt(), snapshot.dark.accent)
        // Every color is solid (alpha FF).
        for (palette in listOf(snapshot.light, snapshot.dark)) {
            for (color in listOf(palette.background, palette.onSurface, palette.onSurfaceVariant, palette.accent, palette.border)) {
                assertEquals(0xFF, (color shr 24) and 0xFF)
            }
        }
    }

    @Test
    fun theLightAndDarkColorsStayApart() {
        val snapshot = WidgetSnapshot.parse(fromTheApp)!!
        assertEquals(4292407264L.toInt(), snapshot.light.background)
        assertEquals(4278794020L.toInt(), snapshot.dark.background)
    }

    private fun minimal(
        heightUnit: String = "\"feet\"",
        temperatureUnit: String = "\"fahrenheit\"",
        locations: String = "[]",
    ) = """{"generatedAt":1,"heightUnit":$heightUnit,"temperatureUnit":$temperatureUnit,"use24Hour":false,
        "palette":{"light":{"background":4294967295,"onSurface":4278190080,"onSurfaceVariant":4278190080,"accent":4278190080,"border":4278190080},
        "dark":{"background":4278190080,"onSurface":4294967295,"onSurfaceVariant":4294967295,"accent":4294967295,"border":4294967295}},
        "locations":$locations}"""

    @Test
    fun feetAreTheDefaultAndOnlyMetersTurnThemOff() {
        assertTrue(WidgetSnapshot.parse(minimal(heightUnit = "\"feet\""))!!.useFeet)
        assertFalse(WidgetSnapshot.parse(minimal(heightUnit = "\"meters\""))!!.useFeet)
        assertTrue(WidgetSnapshot.parse(minimal(heightUnit = "\"cubits\""))!!.useFeet)
    }

    @Test
    fun fahrenheitIsTheDefaultAndOnlyCelsiusTurnsItOff() {
        assertTrue(WidgetSnapshot.parse(minimal(temperatureUnit = "\"fahrenheit\""))!!.useFahrenheit)
        assertFalse(WidgetSnapshot.parse(minimal(temperatureUnit = "\"celsius\""))!!.useFahrenheit)
        assertTrue(WidgetSnapshot.parse(minimal(temperatureUnit = "\"kelvin\""))!!.useFahrenheit)
    }

    @Test
    fun whiteAndBlackSurviveTheTripThroughJson() {
        val snapshot = WidgetSnapshot.parse(minimal())!!
        assertEquals(-1, snapshot.light.background) // 0xFFFFFFFF
        assertEquals(0xFF000000.toInt(), snapshot.light.onSurface)
    }

    private fun withMarine(marine: String) =
        minimal(locations = """[{"id":"a","name":"A","extremes":[],"marine":$marine}]""")

    @Test
    fun eitherPartOfTheWaterConditionsCanBeMissing() {
        val noTemperature = WidgetSnapshot.parse(withMarine("""{"waveFeet":3.0,"waterCelsius":null,"readAt":5}"""))!!
        assertEquals(Marine(3.0, null, 5), noTemperature.locations.single().marine)

        val noWaves = WidgetSnapshot.parse(withMarine("""{"waveFeet":null,"waterCelsius":18.0,"readAt":5}"""))!!
        assertEquals(Marine(null, 18.0, 5), noWaves.locations.single().marine)
    }

    @Test
    fun waterConditionsWithNothingInThemOrNoReadTimeAreLeftOut() {
        val neither = WidgetSnapshot.parse(withMarine("""{"waveFeet":null,"waterCelsius":null,"readAt":5}"""))!!
        assertNull(neither.locations.single().marine)

        val noTime = WidgetSnapshot.parse(withMarine("""{"waveFeet":3.0,"waterCelsius":18.0}"""))!!
        assertNull(noTime.locations.single().marine)
    }

    @Test
    fun anOlderSnapshotWithoutWaterConditionsStillReads() {
        // The app sent this before the tide tile existed. It also carried the look of the one widget.
        val old = """{"version":1,"generatedAt":1,"heightUnit":"feet","use24Hour":false,"appearance":"dark","opacity":0.4,
            "palette":{"light":{"background":1,"onSurface":1,"onSurfaceVariant":1,"accent":1,"border":1},
            "dark":{"background":1,"onSurface":1,"onSurfaceVariant":1,"accent":1,"border":1}},
            "locations":[{"id":"a","name":"A","extremes":[]}]}"""

        val snapshot = WidgetSnapshot.parse(old)!!
        assertNull(snapshot.locations.single().marine)
        assertTrue(snapshot.useFahrenheit) // not in the old one: the default
    }

    @Test
    fun tidesAreSortedIntoTimeOrder() {
        val json = minimal(
            locations = """[{"id":"a","name":"A","extremes":[[300,5.0,"H"],[100,0.5,"L"],[200,4.0,"H"]]}]""",
        )
        val times = WidgetSnapshot.parse(json)!!.locations.single().extremes.map { it.timeMs }
        assertEquals(listOf(100L, 200L, 300L), times)
    }

    @Test
    fun anythingThatIsNotAHighIsALow() {
        val json = minimal(locations = """[{"id":"a","name":"A","extremes":[[100,5.0,"H"],[200,0.5,"L"]]}]""")
        val extremes = WidgetSnapshot.parse(json)!!.locations.single().extremes
        assertTrue(extremes[0].isHigh)
        assertFalse(extremes[1].isHigh)
    }

    @Test
    fun namesWithQuotesAndUnicodeSurvive() {
        val json = minimal(locations = """[{"id":"a","name":"Joe's \"Place\" ☀ Café","extremes":[]}]""")
        assertEquals("Joe's \"Place\" ☀ Café", WidgetSnapshot.parse(json)!!.locations.single().name)
    }

    // ---- bad input never crashes the widget ----

    @Test
    fun textThatIsNotJsonGivesNull() {
        assertNull(WidgetSnapshot.parse("this is not json"))
        assertNull(WidgetSnapshot.parse(""))
        assertNull(WidgetSnapshot.parse("[]"))
    }

    @Test
    fun jsonMissingWhatIsRequiredGivesNull() {
        assertNull(WidgetSnapshot.parse("{}"))
        assertNull(WidgetSnapshot.parse("""{"generatedAt":1}"""))
        // No palette:
        assertNull(WidgetSnapshot.parse("""{"generatedAt":1,"locations":[]}"""))
        // A palette missing a color:
        assertNull(
            WidgetSnapshot.parse(
                """{"generatedAt":1,"palette":{"light":{"background":1},"dark":{"background":1}},"locations":[]}""",
            ),
        )
    }

    @Test
    fun aDamagedTideEntryGivesNullRatherThanWrongNumbers() {
        val json = minimal(locations = """[{"id":"a","name":"A","extremes":[[100,"oops","H"]]}]""")
        assertNull(WidgetSnapshot.parse(json))
    }

    @Test
    fun anEmptySnapshotIsFine() {
        val snapshot = WidgetSnapshot.parse(minimal())
        assertNotNull(snapshot)
        assertTrue(snapshot!!.locations.isEmpty())
    }
}
