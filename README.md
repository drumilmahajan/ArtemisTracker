# Artemis Tracker

A native macOS menu bar app that tracks NASA's Artemis II mission to the Moon in real-time. The only desktop-native Artemis tracker — no browser needed.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

**Menu Bar Popover**
- Mission Elapsed Time (MET) updating every second
- Distance from Earth and Moon (live interpolated)
- Speed in Mach number and km/h
- Current mission phase and next upcoming event
- Signal delay (one-way light-time)
- Mission progress percentage

**3D Trajectory View**
- Top-down SceneKit visualization of the Earth-Moon system
- Full planned trajectory: solid green (flown) + dotted cyan (remaining)
- Complete Moon orbit shown as dotted ring
- Artemis spacecraft model with solar panels and engine glow
- Pan and zoom with trackpad (rotation locked for clarity)
- Scrollable sidebar with all mission data:
  - Live telemetry (distance, speed, signal delay, range rate)
  - XYZ position coordinates
  - Crew roster (Wiseman, Glover, Koch, Hansen)
  - Full 19-event mission timeline with completion status

**Data**
- Powered by [NASA JPL Horizons API](https://ssd.jpl.nasa.gov/horizons/) (spacecraft ID `-1024`)
- API fetches every 30 seconds, position interpolated 10x/sec using velocity vectors
- Full planned trajectory and Moon orbit fetched on startup
- Automatic retry with backoff for transient API errors

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

Or build and run directly:

```bash
swift build -c release
.build/release/ArtemisTracker
```

## License

MIT
