# My Tide Monitor

A free Android app for checking the tide, and the surf, at the beaches you care about. No paywall, no ads, no account.

It is **tides only on purpose**. It is not a weather app: use your phone's weather widgets for that. It tries to be as simple as looking up a place on a tide website, with the detail one tap away.

## What it shows
- The **next high and low tide**, with time and height
- A **tide chart** with an accurate "right now" height, and whether the tide is rising or falling
- **Wave height** and **water temperature** near the spot
- Two **home screen widgets** that follow your theme color and have a glassy look

## Where to start

| I want to... | Read |
|---|---|
| Use the app | [User Guide](User-Guide) |
| Put the tide on my home screen | [Widgets](Widgets) |
| Understand where the numbers come from, and how accurate they are | [How It Works](How-It-Works) |
| Know what it can't do | [FAQ and Limits](FAQ-and-Limits) |
| Read or change the code | [Architecture](Architecture) |
| Build and test it | [Building and Testing](Building-and-Testing) |
| Make a release | [Releasing](Releasing) |
| See who and what made it possible | [Credits](Credits) |

## At a glance
- **Platform:** Android (built with Flutter and Dart, plus Kotlin for the widgets)
- **Tide data:** NOAA CO-OPS, so US coasts and territories
- **Waves, water temperature and place search:** Open-Meteo
- **License:** GNU GPL v3 (see the `LICENSE` file in the repository)

> **Not for navigation or safety decisions.** Tide predictions are calculated from astronomy. Wind, weather and storm surge can change the real water level, and the wave numbers are a computer model of open water, not a surf report.
