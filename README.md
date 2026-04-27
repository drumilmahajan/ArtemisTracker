# Galileo

A native macOS menu bar app for tracking space missions in real-time. Watch the ISS orbit Earth, follow Artemis II to the Moon, or track Voyager 1 in interstellar space — all from your desktop.

Named after Galileo Galilei, the astronomer who first turned a telescope toward the sky.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

**Menu Bar Dashboard**
- Live telemetry: distance, speed, signal delay, range rate
- Upcoming launches from Launch Library 2 with countdowns
- Click any launch for mission details
- Metric (km) / Imperial (mi) unit toggle

**Active Missions**
- **ISS** — International Space Station in low Earth orbit
- **Hubble** — Space telescope at ~569 km altitude
- **JWST** — James Webb at Sun-Earth L2, 1.5M km away
- **Voyager 1** — Farthest human-made object, interstellar space
- **Parker Solar Probe** — Studying the Sun's corona

**3D Trajectory View**
- Real-time 3D visualization of any tracked spacecraft
- NASA Blue Marble Earth texture with real axial tilt (23.4°)
- Real-time Earth rotation via GMST calculation
- Sun lighting from actual Sun position (JPL Horizons)
- Orbital trails: LEO orbits, lunar trajectories, interplanetary arcs
- Pan and zoom with trackpad
- Live telemetry sidebar with position coordinates

**Data**
- Spacecraft positions from [NASA JPL Horizons API](https://ssd.jpl.nasa.gov/horizons/)
- Upcoming launches from [Launch Library 2](https://thespacedevs.com/llapi)
- Real-time interpolation using velocity vectors between API fetches

## Install

### Installer (recommended)

Download **`Galileo.pkg`** from the [latest release](https://github.com/drumilmahajan/galileo/releases) and double-click to install. Installs to `/Applications` — searchable via Spotlight and Launchpad.

### Zip

Download **`Galileo.zip`** from the [latest release](https://github.com/drumilmahajan/galileo/releases), unzip, and run directly or move to Applications.

Both are signed and notarized by Apple. Universal binary (Apple Silicon + Intel).

### Build from source

Requires macOS 13.0+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone git@github.com:drumilmahajan/galileo.git
cd galileo
bash build-app.sh
open Galileo.app
```

## Requirements

- macOS 13.0 (Ventura) or later
- No dependencies — uses only Apple frameworks (SwiftUI, SceneKit, Foundation)

## License

MIT
