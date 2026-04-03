# Artemis Tracker

A macOS menu bar app that tracks NASA's Artemis II mission to the Moon in real-time using data from NASA's JPL Horizons API.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Menu bar icon** showing live distance from Earth
- **Detailed popover** with distance from Earth/Moon, speed, mission phase, position vectors, and a visual Earth-to-Moon progress bar
- **Floating overlay** — compact always-on-top panel showing key stats at the top of your screen
- Auto-refreshes every 5 minutes from JPL Horizons API

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Run

```bash
git clone git@github.com:drumilmahajan/ArtemisTracker.git
cd ArtemisTracker
bash build-app.sh
open ArtemisTracker.app
```

Or build and run directly with Swift:

```bash
swift build -c release
.build/release/ArtemisTracker
```

## Usage

1. After launching, a **moon icon** appears in your menu bar along with the current distance from Earth
2. **Click the icon** to open the popover with full mission details:
   - Distance from Earth and Moon
   - Current speed
   - Mission phase (Near Earth, Outbound Transit, Lunar Approach, etc.)
   - Earth-to-Moon progress bar
   - J2000 Earth-centered position coordinates
3. Click **Floating Overlay** to pin a compact tracker to the top of your screen — it stays visible across all spaces and apps
4. Click **Refresh** to manually fetch the latest data
5. Click **Quit** to exit

## Data Source

Position data comes from [NASA JPL Horizons](https://ssd.jpl.nasa.gov/horizons/) — spacecraft ID `-1024` (Artemis II Orion). The API provides Earth-centered J2000 state vectors which are used to compute distances and velocity.

## License

MIT
