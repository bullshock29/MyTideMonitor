package com.mtm.my_tide_monitor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetConfigTest {
    @Test
    fun aNewWidgetFollowsThePhoneAtThreeQuartersSolidWithNoLocationChosen() {
        val config = WidgetConfig.DEFAULT

        assertEquals("system", config.appearance)
        assertEquals(0.75, config.opacity, 1e-9)
        assertNull(config.stationId)
    }

    @Test
    fun goodValuesAreKept() {
        val config = WidgetConfig.of("dark", 0.4, "8661070")

        assertEquals("dark", config.appearance)
        assertEquals(0.4, config.opacity, 1e-9)
        assertEquals("8661070", config.stationId)
    }

    @Test
    fun anUnknownOrMissingModeFollowsThePhone() {
        assertEquals("system", WidgetConfig.of("sparkly", 0.5, null).appearance)
        assertEquals("system", WidgetConfig.of(null, 0.5, null).appearance)
        assertEquals("light", WidgetConfig.of("light", 0.5, null).appearance)
    }

    @Test
    fun opacityIsKeptBetweenTheMinimumAndFullySolid() {
        assertEquals(0.2, WidgetConfig.of("system", 0.0, null).opacity, 1e-9)
        assertEquals(0.2, WidgetConfig.of("system", -3.0, null).opacity, 1e-9)
        assertEquals(1.0, WidgetConfig.of("system", 7.0, null).opacity, 1e-9)
    }

    @Test
    fun opacityMovesInStepsOfFivePercent() {
        assertEquals(0.6, WidgetConfig.of("system", 0.62, null).opacity, 1e-9)
        assertEquals(0.65, WidgetConfig.of("system", 0.63, null).opacity, 1e-9)
        assertEquals(0.75, WidgetConfig.of("system", 0.75, null).opacity, 1e-9)
    }

    @Test
    fun aMissingOrBrokenOpacityGetsTheDefault() {
        assertEquals(0.75, WidgetConfig.of("system", null, null).opacity, 1e-9)
        assertEquals(0.75, WidgetConfig.of("system", Double.NaN, null).opacity, 1e-9)
    }

    @Test
    fun aBlankLocationMeansTheFirstOne() {
        assertNull(WidgetConfig.of("system", 0.5, "").stationId)
        assertNull(WidgetConfig.of("system", 0.5, "   ").stationId)
    }

    @Test
    fun theSavedMinimumIsTheSameAsTheSettingsSlidersMinimum() {
        // The settings screen's slider starts at 20%; it must not be possible to save less.
        assertEquals(0.2, WidgetConfig.MIN_OPACITY, 1e-9)
    }

    // ---- text size ----

    @Test
    fun aNewWidgetHasMediumText() {
        assertEquals("medium", WidgetConfig.DEFAULT.textSize)
        assertEquals(1f, WidgetConfig.DEFAULT.textScale, 0f)
    }

    @Test
    fun smallMediumAndLargeAreKept() {
        for (size in listOf("small", "medium", "large")) {
            assertEquals(size, WidgetConfig.of("system", 0.5, null, size).textSize)
        }
    }

    @Test
    fun anUnknownOrMissingTextSizeIsMedium() {
        assertEquals("medium", WidgetConfig.of("system", 0.5, null, "huge").textSize)
        assertEquals("medium", WidgetConfig.of("system", 0.5, null, null).textSize)
        assertEquals("medium", WidgetConfig.of("system", 0.5, null).textSize)
    }

    @Test
    fun smallIsSmallerAndLargeIsLargerThanMedium() {
        val small = WidgetConfig.of("system", 0.5, null, "small").textScale
        val medium = WidgetConfig.of("system", 0.5, null, "medium").textScale
        val large = WidgetConfig.of("system", 0.5, null, "large").textScale

        assertEquals(1f, medium, 0f)
        assertTrue(small < medium)
        assertTrue(large > medium)
    }

    @Test
    fun theStepsAreNoticeableButNotExtreme() {
        // Big enough to see, small enough that the tile's plates and rows still fit.
        assertTrue(WidgetConfig.scaleFor("small") in 0.8f..0.95f)
        assertTrue(WidgetConfig.scaleFor("large") in 1.1f..1.25f)
    }

    @Test
    fun theOtherChoicesAreUntouchedByTheTextSize() {
        val config = WidgetConfig.of("dark", 0.4, "8661070", "large")

        assertEquals("dark", config.appearance)
        assertEquals(0.4, config.opacity, 1e-9)
        assertEquals("8661070", config.stationId)
    }
}
