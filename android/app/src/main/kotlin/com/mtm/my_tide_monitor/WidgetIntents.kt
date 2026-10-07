package com.mtm.my_tide_monitor

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

/** What a tap on a widget does: open the app, optionally on one location's detail screen. */
object WidgetIntents {
    private fun launchIntent(context: Context) =
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

    /** The address a tap on a location opens: mtm://station/<id>. */
    fun stationUri(stationId: String): Uri = Uri.parse("mtm://station/$stationId")

    // The "template" for taps on the rows of the list widget. Each row then
    // fills in which station it is (see TideRemoteViewsFactory). It has to be
    // mutable for that to work on Android 12 and newer.
    fun rowTemplate(context: Context): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0

        // Once a row adds its mtm://station/<id> address, this becomes a
        // "view this address" request, which MainActivity declares it
        // handles (see AndroidManifest.xml).
        val intent = launchIntent(context).apply { action = Intent.ACTION_VIEW }
        return PendingIntent.getActivity(context, 0, intent, flags)
    }

    /** Opens the app on one location's detail screen. */
    fun openStation(context: Context, stationId: String): PendingIntent {
        val intent = launchIntent(context).apply {
            action = Intent.ACTION_VIEW
            data = stationUri(stationId)
        }
        return PendingIntent.getActivity(
            context, 2, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Opens the app. */
    fun openApp(context: Context): PendingIntent {
        // The same request the app launcher sends, so it matches the
        // activity's launcher declaration.
        val intent = launchIntent(context).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        return PendingIntent.getActivity(
            context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
