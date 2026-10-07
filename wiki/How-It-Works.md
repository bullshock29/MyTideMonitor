# How It Works

Where each number comes from, and how far to trust it.

## Data sources

| What | Source | Notes |
|---|---|---|
| Tide predictions (highs, lows, 6-minute curve) | **NOAA CO-OPS** data API (`api.tidesandcurrents.noaa.gov`) | US coasts and territories |
| List of tide stations (~3,500) | NOAA CO-OPS metadata API | Saved on the phone for 30 days |
| Wave height and water temperature | **Open-Meteo Marine** API (`marine-api.open-meteo.com`) | A computer model of the ocean, not a measurement |
| Place search by name | **Open-Meteo Geocoding** API | |
| Your location | The phone's location service | Only when you tap **Use my current location** |

No account or API key is needed for any of them.

## Tide predictions
NOAA predicts tides from astronomy: the positions of the moon and sun plus the shape of the local coast. The app asks for heights in **feet above MLLW** (mean lower low water, the average of the lowest tide of each day) in GMT, then shows them in your phone's time zone. A height can be negative at an unusually low tide.

Predictions do **not** include weather. Strong wind, a storm surge or heavy rain upstream can make the real water level differ from the prediction.

### Reference and subordinate stations
- A **reference** station has full predictions, including a smooth value every 6 minutes.
- A **subordinate** station only has highs and lows, worked out from a nearby reference station using time and height offsets. Its numbers are still good, but it has no 6-minute curve.

### The tide chart
- For a **reference** station, the chart is NOAA's own 6-minute curve.
- For a **subordinate** station, the chart is **estimated**: a smooth curve is drawn between the predicted highs and lows. Between one high or low and the next, the water follows a half cosine wave, moving slowly near the turn and fastest halfway between.
- Checked against NOAA's real 6-minute predictions, that estimate was off by about **0.02 to 0.14 ft on average** (at worst 0.06 to 0.41 ft) at the stations tried. The detail screen says when a chart is estimated.

The "height right now" is read off this curve.

## Choosing a station
This is the hard part of a tide app: a place can have several stations nearby, and they can disagree a lot. A coastal pier a few miles away and a waterway station behind a barrier island can have high tides **hours apart** and different heights. The app tries to pick the right one for you without asking you to understand any of that.

1. **Rank by distance.** Stations within 50 miles are ranked by distance, and the five nearest are considered. A subordinate station is treated as if it were 2 miles farther away, so a reference station a little farther off wins over a slightly closer estimated one. The distances shown are always the real ones.
2. **Look at the close ones.** "Close" means within 5 miles, or twice the distance to the nearest station if that is larger.
3. **Do they agree?** Two stations *agree* when their next high tides are within **75 minutes** of each other and their heights are within about 30% (a ratio between 0.7 and 1.43). Real examples from testing: stations in Annapolis and Miami Beach differ by 48 to 57 minutes with similar heights, which isn't worth asking about, while Myrtle Beach's ocean and waterway stations differ by 3 to 4 hours and about 60% in height.
4. **One answer or a choice.** If the close stations agree, the app just shows the best one. If they really disagree, it offers up to three. A station that agrees with one already offered is skipped, so three waterway stations show up as one choice. The first item is always the best match.

Stations that return no tide data are left out first.

## Waves and water temperature
- Open-Meteo's marine model gives the wave height now and hourly for the next 24 hours, and the sea surface temperature.
- The model works on a grid, and a spot **snaps to the nearest ocean grid point**, a few miles wide. So it describes the **open water** near the spot, not the surf at one particular beach, which can be smaller or larger.
- Checked against real buoys, the water temperature agreed within about 0.3 °C, and the waves matched well offshore.
- For a station that looks like a **waterway** (the name contains words like creek, river, canal, bridge, channel, intracoastal and so on, unless it also says pier, ocean or jetty), the app shows **no waves or water temperature**. The model only knows the open water beyond a creek, and once reported 3 ft waves for one, so showing it would mislead. This is a guess from the station's name.
- Wave sizes in words: under 1 ft **Calm**, 1 to 2 **Small**, 2 to 4 **Moderate**, 4 to 6 **Large**, 6 and over **Very large**. In feet they round to the nearest half foot; in meters, to a tenth.
- Some places have waves but no water temperature, or the reverse. Each part is shown only when it is there. Inland places get neither.

## Saving data on the phone
- Every good answer from NOAA and Open-Meteo is saved in the app's storage, so the app works with no signal.
- Tide predictions are saved and reused as long as they still cover the time being asked about.
- Waves and water temperature are reused only if they are under a day old, and are labeled with their age.
- Saved answers from stations you haven't looked at for two weeks are cleaned up when the app starts.
- The station list is refreshed after 30 days (or sooner on demand), and an older copy is used if the refresh fails.

## Why the widget and the app can differ slightly
The app uses NOAA's 6-minute curve for reference stations. The widget works from highs and lows only (two weeks' worth, saved on the phone) and draws the half-cosine curve between them, so it can run with no connection. The two usually agree to about 0.1 ft and can differ by up to roughly 0.4 ft.
