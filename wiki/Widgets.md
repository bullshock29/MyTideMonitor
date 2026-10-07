# Widgets

My Tide Monitor has two home screen widgets. Both use your app theme color, a translucent "glass" look, and have their **own settings**.

| Widget | Size | Shows |
|---|---|---|
| **Tide tile** | 4 wide x 2 high | One location: the tide now and which way it's going, next high, next low, waves and water temperature |
| **Tide list** | 4 wide x 2 high (scrolls) | All your saved locations, one row each: the tide now, rising or falling, and the next high and low |

Both can be resized.

## Adding a widget
1. Touch and hold an empty spot on your home screen and choose **Widgets**.
2. Find **My Tide Monitor** and choose **Tide tile** or **Tide list**.
3. The widget's **settings screen** opens (see below). Choose what you want and tap **Done**.

You can add as many as you like, for example one tile per beach.

## Widget settings
Touch and hold a widget and choose **Settings** (Android 12 and newer) to reopen the same screen. A live preview shows your choices over a colorful backdrop so you can judge the glass.

| Setting | Choices |
|---|---|
| **Location** (tile only) | Any of your saved locations |
| **Look** | **Phone** (follow your phone's light/dark setting), **Light**, or **Dark** |
| **Text size** | **Small**, **Medium**, **Large** |
| **Opacity** | 20% to 100%, in 5% steps. Lower is more see-through |

The color always follows the theme color set in the app's Settings. Units and the 12/24-hour setting come from the app too.

Backing out of the settings screen with the back button cancels: a widget being added is not added, and one being changed keeps what it had.

## Tapping
Tapping a widget opens the app on that location's detail screen. On the list, tap the row you want.

## What the numbers mean
- The **tide height now** is worked out on your phone from the saved high and low tides each time the widget redraws, so it works with no connection.
- **Waves** and **water temperature** are what the app last read. If they are more than 3 hours old the plate shows how old (for example "5h ago"); after 24 hours they are hidden.
- If the saved tides have run out (about two weeks after the app was last opened), the widget says **Open My Tide Monitor to refresh**.
- If you remove the location a tile was showing, it says so and asks you to touch and hold to choose another.

## How fresh is it?
- Widgets redraw about **every 15 minutes**, which is the fastest Android allows, and Android may delay it to save battery. After the phone has been idle for a long time, the tide height can be a little behind until the next redraw.
- The data behind the widgets (tides, waves, water temperature) is refreshed **whenever you open the app**.
- On Android 14 and newer, a widget set to **Phone** switches between light and dark on its own when your phone does. On older versions it catches up at the next redraw.

## Limits
- The glass is a **tinted see-through card, not a real blur**. Android doesn't let a widget blur what is behind it.
- At low opacity with a dark look over a bright wallpaper, light text can be hard to read. That is a trade-off of the choices, not a fault. Raise the opacity or switch the look.
- **Large** text on the tile is snug at the smallest widget height. Make the widget a little taller if anything looks cramped.
- A new location you save reaches the widgets only when the app has run.

See [Architecture](Architecture#the-widgets) for how the widgets are built.
