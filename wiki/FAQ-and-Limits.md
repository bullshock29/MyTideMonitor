# FAQ and Limits

## Is it safe to use for boating or swimming decisions?
**No.** Tide predictions don't include wind, storms or storm surge, and the waves are a model of open water, not a surf report. Use proper marine forecasts and local knowledge for anything where safety matters.

## Why is it tides only? Where is the weather?
On purpose. This started as a free, no-paywall alternative to tide apps, and the author already has weather widgets. Keeping it to tides keeps it simple, and the home screen stays a quick glance.

## Which places does it cover?
Anywhere NOAA has a tide-prediction station: the US coasts (including Alaska and Hawaii) and US territories. The app has no tide data for other countries.

## Two nearby stations show very different high tides. Which is right?
Both can be. A coastal station and a station on a waterway behind it really do see the tide at different times and heights. The app tries to pick the one that fits the place you searched for, and only asks you when they disagree. See [How It Works](How-It-Works#choosing-a-station). If you're picking by hand from the NOAA Stations list, the detail screen says whether a station is a reference or subordinate one, and its name often hints at a waterway.

## Why does my location show no waves or water temperature?
Either the place looks like a waterway (the model would be describing the ocean outside it), or it's inland, or the model has nothing there. The app would rather show nothing than something misleading.

## Why does the tide chart say "estimated"?
That station only publishes highs and lows, so the chart is drawn smoothly between them. It is usually within about a tenth of a foot. See [How It Works](How-It-Works#the-tide-chart).

## The widget's height is a few minutes behind.
Android redraws widgets about every 15 minutes at best, and can delay that when the phone has been idle. The widget works out the height from saved tides each time it redraws, so it catches up at the next redraw. Opening the app also refreshes everything. See [Widgets](Widgets#how-fresh-is-it).

## The widget says "Open My Tide Monitor to refresh".
Its saved tides (about two weeks) have run out. Open the app once with a connection.

## Why doesn't the widget glass blur the wallpaper?
Android doesn't let a widget blur what's behind it. The glass look is a tinted, see-through card with a soft highlight and a thin edge. The **Opacity** setting controls how solid it is.

## Does it work offline?
Yes, for what it has already loaded. See the end of the [User Guide](User-Guide#using-it-with-no-connection).

## Is there an iPhone version?
No. It's an Android app. The app itself is written in Flutter, which can target iOS, but the widgets are Android code and nothing has been built or tested for iOS.

## Does it collect any data?
There is no account, no analytics and no ads. Your location is read only when you tap **Use my current location**, and is used to find a station. The app does contact NOAA and Open-Meteo to get data, which means those services see requests from your phone like any website would.

## Known limits, in short
- Android only; NOAA coverage only.
- Wave height is open-water model output, not a surf report.
- Widgets redraw about every 15 minutes, not instantly.
- Waves and water temperature on widgets refresh only when the app is opened.
- Saved tides for the widgets last about two weeks.
- The glass look is translucent, not blurred.
- The release APK is signed with a debug key (see [Releasing](Releasing)).
