# User Guide

## The menu
Open the menu (top-left) for the four places in the app:

1. **Home**: your saved locations
2. **Find a Location**: search by name, or use your current location
3. **NOAA Stations**: every NOAA tide station, grouped by state
4. **Settings**: units, time format and theme

Every screen except Home has a **home button** at the top right that always takes you back.

## Adding a location
On Home, tap the **+** button, or choose **Find a Location** from the menu.

### By name
1. Type a city or place (two letters or more). Results appear when you pause typing.
2. Tap a result. The app picks the best nearby tide station for you.
3. If nearby stations really disagree about the tide (for example the open ocean versus a waterway behind it), the app shows up to three and asks you to choose. Otherwise it just shows the answer. See [How It Works](How-It-Works#choosing-a-station) for why.
4. Tap **Add to my home screen** to save it.

### By your current location
Tap **Use my current location**. The app asks for permission to read your location (Android lets you share only an approximate one, which is enough). It then picks the nearest suitable station the same way.

### From the station list
Menu, **NOAA Stations**. Stations are grouped by state and searchable. Tap one to see it, and tap the **star** to save it. Station details say whether it is a *reference* station (predicted directly) or a *subordinate* one (estimated from a reference station).

## Home screen
Each saved location is a card showing:
- the **next high** and **next low** tide, with time and height
- the **wave height**, when there is something trustworthy to say
- a **tide chart**, with the height right now and the **water temperature** beside the chart's title

Home is meant for a quick glance, so the small explanations are left out. Tap a card for the full detail screen.

### Rearranging, renaming and removing
- **Reorder:** long-press a card. The screen switches to **Reorder locations**; drag the cards into the order you want, then tap the check mark (or the back button) when you're done.
- **Rename:** open a location and tap the pencil. Your name is used on Home and on the widgets.
- **Remove:** use the card's menu and choose **Remove from home**. A message appears with **Undo** in case it was a slip.

## Location detail screen
The same information as the card, with the notes spelled out:
- what the heights mean (feet or meters above the lowest tide level, "MLLW")
- that times are in your device's time zone
- that waves are an open-water estimate
- whether the tide chart is NOAA's own curve or an **estimated** curve drawn between highs and lows
- if you are offline, how old the saved information is

## Settings
- **Appearance:** Light, Dark or follow the phone; and a theme color (**Blue**, **Green**, **Orange**). The whole app, including the widgets, uses the color.
- **Units:** temperature (°F / °C), distance (miles / km), height (feet / meters).
- **Time:** 12-hour or 24-hour.

The widgets' own options (location, light or dark, text size, opacity) are on each widget, not here. See [Widgets](Widgets).

## Using it with no connection
Everything the app has already loaded is saved on your phone. With no signal:
- **Tide times and the chart** keep working, because predictions don't expire. The detail screen notes when they were saved.
- **Waves and water temperature** show **"Offline • as of ..."** with their age, because they are forecasts that change. They are hidden once they are a day old.
- Saved tide predictions do run out eventually (about three days for the app, two weeks for the widgets). Connect once to refresh them.
