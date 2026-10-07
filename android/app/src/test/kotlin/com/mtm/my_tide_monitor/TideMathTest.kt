package com.mtm.my_tide_monitor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TideMathTest {
    // Real Springmaid Pier predictions for 2026-10-06 and -07, in UTC.
    private val high0424 = Extreme(1791260640000, 0.806, true)
    private val low1438 = Extreme(1791297480000, 0.629, false)
    private val high2048 = Extreme(1791319680000, 6.003, true)
    private val low0329 = Extreme(1791343740000, 0.671, false)
    private val high0922 = Extreme(1791364920000, 5.677, true)
    private val extremes = listOf(high0424, low1438, high2048, low0329, high0922)

    private fun height(timeMs: Long) = TideMath.heightAt(extremes, timeMs)

    // These expected heights come from the app's own Dart tide chart code
    // (lib/services/tide_curve.dart), so the widget and the app agree.
    @Test
    fun matchesTheAppsDartMath() {
        val expected = mapOf(
            1791266400000L to 0.7955, // 06:00
            1791279060000L to 0.7175, // 09:31
            1791298800000L to 0.6765, // 15:00
            1791308580000L to 3.3160, // 17:43
            1791316800000L to 5.7822, // 20:00
            1791319620000L to 6.0026, // 20:47
            1791324000000L to 5.5900, // 22:00
            1791334800000L to 2.2903, // 01:00 next day
            1791343680000L to 0.6714, // 03:28
            1791354600000L to 3.2742, // 06:30
        )
        for ((time, dart) in expected) {
            assertEquals("at $time", dart, height(time)!!, 0.005)
        }
    }

    @Test
    fun isExactlyOnAHighOrLowAtItsTime() {
        assertEquals(0.629, height(low1438.timeMs)!!, 1e-9)
        assertEquals(6.003, height(high2048.timeMs)!!, 1e-9)
        assertEquals(0.671, height(low0329.timeMs)!!, 1e-9)
    }

    @Test
    fun halfwayBetweenALowAndAHighIsTheirAverage() {
        // 14:38 to 20:48 is 370 minutes, so the middle is 185 minutes in.
        val middle = low1438.timeMs + 185 * 60_000L
        assertEquals((0.629 + 6.003) / 2, height(middle)!!, 1e-9)
    }

    @Test
    fun movesSlowlyNearAnExtremeAndFastInTheMiddle() {
        val oneHourAfterLow = height(low1438.timeMs + 60 * 60_000L)!! - 0.629
        val oneHourInTheMiddle =
            height(low1438.timeMs + 215 * 60_000L)!! - height(low1438.timeMs + 155 * 60_000L)!!
        assertTrue(oneHourAfterLow < oneHourInTheMiddle)
    }

    @Test
    fun neverGoesAboveTheHighOrBelowTheLow() {
        var time = low1438.timeMs
        while (time < high2048.timeMs) {
            val h = height(time)!!
            assertTrue(h >= 0.629 - 1e-9 && h <= 6.003 + 1e-9)
            time += 5 * 60_000L
        }
    }

    @Test
    fun isUnknownOutsideTheRangeTheTidesCover() {
        assertNull(height(high0424.timeMs - 1))
        assertNull(height(high0922.timeMs)) // the last one has no "next" to go towards
        assertNull(height(high0922.timeMs + 3_600_000))
        assertNull(TideMath.isRising(extremes, high0424.timeMs - 1))
        assertNull(TideMath.isRising(extremes, high0922.timeMs + 1))
    }

    @Test
    fun isUnknownWithTooFewTides() {
        assertNull(TideMath.heightAt(emptyList(), 1000))
        assertNull(TideMath.heightAt(listOf(low1438), low1438.timeMs))
        assertNull(TideMath.isRising(emptyList(), 1000))
    }

    @Test
    fun saysWhichWayTheTideIsGoing() {
        // After the 04:24 high and before the 14:38 low: falling.
        assertEquals(false, TideMath.isRising(extremes, 1791266400000L))
        // After the low and before the 20:48 high: rising.
        assertEquals(true, TideMath.isRising(extremes, 1791298800000L))
        // After the high: falling again.
        assertEquals(false, TideMath.isRising(extremes, 1791324000000L))
        assertEquals(true, TideMath.isRising(extremes, 1791354600000L))
    }

    @Test
    fun findsTheNextHighAndLow() {
        val now = 1791308580000L // 17:43, rising towards the 20:48 high

        assertEquals(high2048, TideMath.nextHigh(extremes, now))
        assertEquals(low0329, TideMath.nextLow(extremes, now))
    }

    @Test
    fun theNextOneIsStrictlyInTheFuture() {
        // Exactly at a high, the next high is the following one, not this one.
        assertEquals(high0922, TideMath.nextHigh(extremes, high2048.timeMs))
        // One millisecond before a low, that low is next. At the low itself, the following one is.
        assertEquals(low1438, TideMath.nextLow(extremes, low1438.timeMs - 1))
        assertEquals(low0329, TideMath.nextLow(extremes, low1438.timeMs))
    }

    @Test
    fun hasNoNextWhenTheTidesRunOut() {
        assertNull(TideMath.nextHigh(extremes, high0922.timeMs))
        assertNull(TideMath.nextLow(extremes, low0329.timeMs + 1))
        assertNull(TideMath.nextHigh(emptyList(), 0))
    }

    @Test
    fun aRisingTideNeverShowsAsFalling() {
        var time = low1438.timeMs + 60_000L
        while (time < high2048.timeMs) {
            assertTrue(TideMath.isRising(extremes, time)!!)
            time += 17 * 60_000L
        }
        assertFalse(TideMath.isRising(extremes, high2048.timeMs + 60_000L)!!)
        assertNotNull(height(high2048.timeMs + 60_000L))
    }
}
