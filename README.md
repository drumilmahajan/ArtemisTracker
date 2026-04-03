# Artemis Tracker

A macOS menu bar app that tracks NASA's Artemis II mission to the Moon in real-time using data from NASA's JPL Horizons API.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

<p align="center">
  <img src="assets/demo.gif" alt="Artemis Tracker Demo" width="720">
</p>

## Features

- **Menu bar icon** — click to see live mission data
- **Live position interpolation** — API fetches every 30s, position updates 10x/sec using velocity vectors
- **Detailed popover** with distance from Earth/Moon, speed, mission phase, and Earth-to-Moon progress bar
- **3D trajectory view** — SceneKit visualization with Earth, Moon, spacecraft model, planned trajectory path, and Moon orbit
- **Floating overlay** — compact always-on-top panel with key stats, visible across all spaces
- **Trackpad controls** — two-finger rotate, pinch zoom, Option+drag to pan in 3D view
- **Reset View** button to re-center the camera when lost in space

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

1. After launching, a **moon icon** appears in your menu bar
2. **Click the icon** to open the popover with:
   - Distance from Earth and Moon (live)
   - Current speed and mission phase
   - Earth-to-Moon progress bar
   - Mini 3D trajectory preview
3. Click **3D View** to open a full window with:
   - Earth, Moon, and Artemis spacecraft (3D model with solar panels)
   - Full planned mission trajectory (green/cyan path)
   - Moon's orbital path (dashed gray)
   - Stats sidebar with live telemetry
   - Reset View button to re-center camera
4. Click **Overlay** for a compact floating tracker pinned to the top of your screen
5. Click **Quit** to exit

## How It Works

Position data comes from [NASA JPL Horizons](https://ssd.jpl.nasa.gov/horizons/) (spacecraft ID `-1024`). The app fetches Earth-centered state vectors every 30 seconds and interpolates between fetches using the velocity vector for smooth real-time updates. The full planned trajectory is fetched once on startup.

Includes automatic retry with backoff for transient API errors (503s).

## License

MIT
