package com.mtm.my_tide_monitor

import kotlin.math.roundToInt

/** Picks the widget's colors and how see-through its background is. */
object WidgetTheme {
    /**
     * What to draw with.
     *
     * [palette] is the look in use right now. [notNightPalette] and
     * [nightPalette] are the looks for when the phone is in light mode and
     * dark mode. When the widget follows the phone they differ, and newer
     * Android versions switch between them by themselves when the phone's
     * mode changes. When the user picked light or dark, both are the same.
     */
    data class Resolved(
        val palette: Palette,
        val notNightPalette: Palette,
        val nightPalette: Palette,
        val backgroundAlpha: Int,
        val isDark: Boolean,
    )

    // Used until the app has sent its first snapshot.
    private val FALLBACK_LIGHT = Palette(
        background = 0xFFEAF1FB.toInt(),
        onSurface = 0xFF191C20.toInt(),
        onSurfaceVariant = 0xFF44474E.toInt(),
        accent = 0xFF005EB4.toInt(),
        border = 0xFF74777F.toInt(),
    )
    private val FALLBACK_DARK = Palette(
        background = 0xFF161C26.toInt(),
        onSurface = 0xFFE1E2E9.toInt(),
        onSurfaceVariant = 0xFFC4C6D0.toInt(),
        accent = 0xFFA8C8FF.toInt(),
        border = 0xFF8E9099.toInt(),
    )

    /**
     * Whether to use the dark look. "dark" and "light" are the user's explicit
     * choice; anything else follows the phone ([systemIsNight]).
     */
    fun isDark(appearance: String, systemIsNight: Boolean): Boolean = when (appearance) {
        "dark" -> true
        "light" -> false
        else -> systemIsNight
    }

    /** 0.0 to 1.0 as 0 to 255. */
    fun alphaFor(opacity: Double): Int = (opacity * 255).roundToInt().coerceIn(0, 255)

    /**
     * The look for one widget: the app's colors, in the light or dark mode the
     * widget's own [config] asks for, at the opacity it asks for.
     */
    fun resolve(snapshot: WidgetSnapshot, config: WidgetConfig, systemIsNight: Boolean): Resolved =
        build(snapshot.light, snapshot.dark, config, systemIsNight)

    private fun build(light: Palette, dark: Palette, config: WidgetConfig, systemIsNight: Boolean): Resolved {
        val isDark = isDark(config.appearance, systemIsNight)
        val followsPhone = config.appearance != "light" && config.appearance != "dark"

        // Following the phone: light colors for light mode, dark colors for
        // dark mode. An explicit choice uses the same colors either way.
        val chosen = if (isDark) dark else light
        return Resolved(
            palette = chosen,
            notNightPalette = if (followsPhone) light else chosen,
            nightPalette = if (followsPhone) dark else chosen,
            backgroundAlpha = alphaFor(config.opacity),
            isDark = isDark,
        )
    }

    /** The look before the app has sent any colors; still honors the widget's own choices. */
    fun fallback(systemIsNight: Boolean, config: WidgetConfig = WidgetConfig.DEFAULT): Resolved =
        build(FALLBACK_LIGHT, FALLBACK_DARK, config, systemIsNight)
}
