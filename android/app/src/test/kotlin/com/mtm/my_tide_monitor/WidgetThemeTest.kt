package com.mtm.my_tide_monitor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetThemeTest {
    private val light = Palette(0xFFF0F4FB.toInt(), 0xFF191C20.toInt(), 0xFF44474E.toInt(), 0xFF005EB4.toInt(), 0xFF74777F.toInt())
    private val dark = Palette(0xFF0F141C.toInt(), 0xFFE1E2E9.toInt(), 0xFFC4C6D0.toInt(), 0xFFA8C8FF.toInt(), 0xFF8E9099.toInt())

    private val snapshot = WidgetSnapshot(
        generatedAtMs = 0,
        useFeet = true,
        useFahrenheit = true,
        use24Hour = false,
        light = light,
        dark = dark,
        locations = emptyList(),
    )

    // The look of a widget whose own choices are [appearance] and [opacity].
    private fun resolve(appearance: String, systemIsNight: Boolean, opacity: Double = 0.75) =
        WidgetTheme.resolve(snapshot, WidgetConfig(appearance, opacity), systemIsNight)

    @Test
    fun followingThePhoneUsesTheLookThePhoneIsUsing() {
        assertTrue(WidgetTheme.isDark("system", systemIsNight = true))
        assertFalse(WidgetTheme.isDark("system", systemIsNight = false))
    }

    @Test
    fun anExplicitChoiceOverridesThePhone() {
        assertTrue(WidgetTheme.isDark("dark", systemIsNight = false))
        assertFalse(WidgetTheme.isDark("light", systemIsNight = true))
    }

    @Test
    fun anUnknownModeFollowsThePhone() {
        assertTrue(WidgetTheme.isDark("something-new", systemIsNight = true))
        assertFalse(WidgetTheme.isDark("", systemIsNight = false))
    }

    @Test
    fun picksThePaletteForTheLookInUse() {
        assertEquals(dark, resolve("system", true).palette)
        assertEquals(light, resolve("system", false).palette)
        assertEquals(dark, resolve("dark", false).palette)
        assertEquals(light, resolve("light", true).palette)
    }

    @Test
    fun aWidgetFollowingThePhoneCarriesBothLooksSoAndroidCanSwitchByItself() {
        for (night in listOf(false, true)) {
            val theme = resolve("system", night)
            assertEquals(light, theme.notNightPalette)
            assertEquals(dark, theme.nightPalette)
        }
    }

    @Test
    fun anExplicitChoiceUsesTheSameLookWhateverThePhoneDoes() {
        // Dark was chosen: even if the phone goes to light mode, it stays dark.
        for (night in listOf(false, true)) {
            val dark = resolve("dark", night)
            assertEquals(this.dark, dark.notNightPalette)
            assertEquals(this.dark, dark.nightPalette)

            val light = resolve("light", night)
            assertEquals(this.light, light.notNightPalette)
            assertEquals(this.light, light.nightPalette)
        }
    }

    @Test
    fun anUnknownModeIsTreatedAsFollowingThePhone() {
        val theme = resolve("something-new", false)
        assertEquals(light, theme.notNightPalette)
        assertEquals(dark, theme.nightPalette)
    }

    @Test
    fun theLookInUseIsAlwaysOneOfTheTwo() {
        for (mode in listOf("system", "light", "dark")) {
            for (night in listOf(false, true)) {
                val theme = resolve(mode, night)
                assertTrue(theme.palette == theme.notNightPalette || theme.palette == theme.nightPalette)
            }
        }
    }

    @Test
    fun theAppsColorsAreUsedWhateverTheWidgetsOwnChoicesAre() {
        // Only the mode and the opacity are the widget's own; the colors come from the app's snapshot.
        assertEquals(dark.accent, resolve("dark", false).palette.accent)
        assertEquals(light.accent, resolve("light", true).palette.accent)
    }

    @Test
    fun twoWidgetsCanLookDifferentFromTheSameSnapshot() {
        val first = WidgetTheme.resolve(snapshot, WidgetConfig("dark", 0.3), systemIsNight = false)
        val second = WidgetTheme.resolve(snapshot, WidgetConfig("light", 1.0), systemIsNight = false)

        assertEquals(dark, first.palette)
        assertEquals(light, second.palette)
        assertEquals(WidgetTheme.alphaFor(0.3), first.backgroundAlpha)
        assertEquals(255, second.backgroundAlpha)
    }

    @Test
    fun theFallbackHonorsTheWidgetsOwnChoices() {
        // Before the app has ever sent anything, a widget set to dark at 40% is still dark at 40%.
        val theme = WidgetTheme.fallback(systemIsNight = false, config = WidgetConfig("dark", 0.4))
        assertTrue(theme.isDark)
        assertEquals(WidgetTheme.alphaFor(0.4), theme.backgroundAlpha)
        assertEquals(theme.palette, theme.notNightPalette)
        assertEquals(theme.palette, theme.nightPalette)
    }

    @Test
    fun theFallbackAlsoFollowsThePhone() {
        val theme = WidgetTheme.fallback(systemIsNight = false)
        assertNotEquals(theme.notNightPalette, theme.nightPalette)
        assertEquals(theme.notNightPalette, theme.palette)
        assertEquals(WidgetTheme.fallback(true).nightPalette, theme.nightPalette)
    }

    @Test
    fun saysWhetherTheLookIsDark() {
        assertTrue(resolve("dark", false).isDark)
        assertFalse(resolve("light", true).isDark)
    }

    @Test
    fun opacityBecomesAnAlphaFrom0To255() {
        assertEquals(255, WidgetTheme.alphaFor(1.0))
        assertEquals(51, WidgetTheme.alphaFor(0.2))
        assertEquals(191, WidgetTheme.alphaFor(0.75))
        assertEquals(128, WidgetTheme.alphaFor(0.5))
    }

    @Test
    fun anOutOfRangeOpacityNeverGivesAnInvalidAlpha() {
        assertEquals(255, WidgetTheme.alphaFor(5.0))
        assertEquals(0, WidgetTheme.alphaFor(-1.0))
    }

    @Test
    fun theSnapshotsOpacityIsUsedForTheBackground() {
        assertEquals(51, resolve("light", false, 0.2).backgroundAlpha)
        assertEquals(255, resolve("light", false, 1.0).backgroundAlpha)
    }

    @Test
    fun beforeTheAppHasSentAnythingThereIsASensibleLook() {
        val day = WidgetTheme.fallback(systemIsNight = false)
        val night = WidgetTheme.fallback(systemIsNight = true)

        assertNotEquals(day.palette, night.palette)
        assertFalse(day.isDark)
        assertTrue(night.isDark)
        assertEquals(191, day.backgroundAlpha)
    }

    private fun luminance(color: Int): Double {
        fun channel(shift: Int): Double {
            val c = ((color shr shift) and 0xFF) / 255.0
            return if (c <= 0.03928) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    private fun contrast(a: Int, b: Int): Double {
        val l1 = luminance(a) + 0.05
        val l2 = luminance(b) + 0.05
        return if (l1 > l2) l1 / l2 else l2 / l1
    }

    @Test
    fun theFallbackLooksAreReadable() {
        for (night in listOf(false, true)) {
            val p = WidgetTheme.fallback(night).palette
            assertTrue("text on background, night=$night", contrast(p.onSurface, p.background) > 7)
            assertTrue("secondary text, night=$night", contrast(p.onSurfaceVariant, p.background) > 4.5)
            assertTrue("accent, night=$night", contrast(p.accent, p.background) > 3)
        }
    }
}
