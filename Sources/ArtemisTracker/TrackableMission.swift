import Foundation

/// A spacecraft mission that can be tracked live via JPL Horizons.
struct TrackableMission: Identifiable, Hashable {
    let id: String
    let name: String
    let spacecraft: String
    let agency: String
    let horizonsId: String         // JPL Horizons target ID (e.g. "-125544")
    let centerBody: CenterBody
    let orbitType: OrbitType
    let description: String

    enum CenterBody: String, Hashable {
        case earth = "500@399"     // Earth center
        case sun = "500@10"        // Sun center
    }

    enum OrbitType: Hashable {
        case lowEarthOrbit         // ISS, Hubble (~400km altitude)
        case lunarTransit          // Artemis II (Earth-Moon)
        case lagrangePoint         // JWST (Sun-Earth L2)
        case interplanetary        // Voyager, Parker Solar Probe
    }

    /// Scale factor for 3D view (km per scene unit)
    var scaleFactor: Double {
        switch orbitType {
        case .lowEarthOrbit:    return 500.0       // ~400km orbit → visible at scene scale
        case .lunarTransit:     return 10_000.0    // Earth-Moon scale
        case .lagrangePoint:    return 100_000.0   // Sun-Earth L2
        case .interplanetary:   return 1_000_000.0 // Solar system scale
        }
    }

    /// Whether to show Moon in 3D view
    var showMoon: Bool {
        orbitType == .lunarTransit
    }

    /// API refresh interval in seconds
    var refreshInterval: TimeInterval {
        switch orbitType {
        case .lowEarthOrbit: return 15    // LEO moves fast
        case .lunarTransit:  return 30
        case .lagrangePoint: return 120   // Slow-moving
        case .interplanetary: return 300  // Very slow
        }
    }

    /// Whether a secondary body (Moon) needs to be fetched
    var secondaryBodyId: String? {
        showMoon ? "301" : nil  // Moon
    }
}

// MARK: - Registry of known trackable missions

extension TrackableMission {
    static let allMissions: [TrackableMission] = [
        .artemisII,
        .iss,
        .hubble,
        .jwst,
        .voyager1,
        .parkerSolarProbe,
    ]

    static let artemisII = TrackableMission(
        id: "artemis-ii",
        name: "Artemis II",
        spacecraft: "Orion",
        agency: "NASA",
        horizonsId: "-1024",
        centerBody: .earth,
        orbitType: .lunarTransit,
        description: "First crewed Artemis mission — lunar flyby and return"
    )

    static let iss = TrackableMission(
        id: "iss",
        name: "International Space Station",
        spacecraft: "ISS",
        agency: "NASA/ESA/JAXA/CSA/Roscosmos",
        horizonsId: "-125544",
        centerBody: .earth,
        orbitType: .lowEarthOrbit,
        description: "Continuously crewed orbital laboratory at ~408 km altitude"
    )

    static let hubble = TrackableMission(
        id: "hubble",
        name: "Hubble Space Telescope",
        spacecraft: "HST",
        agency: "NASA/ESA",
        horizonsId: "-48",
        centerBody: .earth,
        orbitType: .lowEarthOrbit,
        description: "Space telescope in low Earth orbit since 1990"
    )

    static let jwst = TrackableMission(
        id: "jwst",
        name: "James Webb Space Telescope",
        spacecraft: "JWST",
        agency: "NASA/ESA/CSA",
        horizonsId: "-170",
        centerBody: .sun,
        orbitType: .lagrangePoint,
        description: "Infrared observatory at Sun-Earth L2, 1.5M km from Earth"
    )

    static let voyager1 = TrackableMission(
        id: "voyager-1",
        name: "Voyager 1",
        spacecraft: "Voyager 1",
        agency: "NASA",
        horizonsId: "-31",
        centerBody: .sun,
        orbitType: .interplanetary,
        description: "Farthest human-made object — in interstellar space since 2012"
    )

    static let parkerSolarProbe = TrackableMission(
        id: "parker-solar-probe",
        name: "Parker Solar Probe",
        spacecraft: "PSP",
        agency: "NASA",
        horizonsId: "-96",
        centerBody: .sun,
        orbitType: .interplanetary,
        description: "Studying the Sun's corona from as close as 5.9M km"
    )
}
