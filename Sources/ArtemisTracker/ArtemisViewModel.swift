import Foundation
import SwiftUI

enum UnitSystem: String, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"

    var distanceUnit: String { self == .metric ? "km" : "mi" }
    var speedUnit: String { self == .metric ? "km/h" : "mph" }
    var velocityUnit: String { self == .metric ? "km/s" : "mi/s" }
    var label: String { self == .metric ? "Metric" : "Imperial" }

    static let kmToMi = 0.621371

    func convertDistance(_ km: Double) -> Double {
        self == .metric ? km : km * UnitSystem.kmToMi
    }

    func formatDistance(_ km: Double) -> String {
        let val = convertDistance(km)
        let unit = distanceUnit
        if val > 1_000_000 {
            return String(format: "%.1fM %@", val / 1_000_000, unit)
        }
        return String(format: "%.0f %@", val, unit)
    }

    func formatSpeed(_ kmPerSec: Double) -> String {
        let perHour = convertDistance(kmPerSec * 3600)
        let mach = kmPerSec / 0.343
        if mach > 1 {
            return String(format: "Mach %.0f (%.0f %@)", mach, perHour, speedUnit)
        }
        return String(format: "%.0f %@", perHour, speedUnit)
    }

    func formatVelocity(_ kmPerSec: Double) -> String {
        let val = convertDistance(kmPerSec)
        return String(format: "%+.2f %@", val, velocityUnit)
    }

    func formatPosition(_ km: Double) -> String {
        let val = convertDistance(km)
        return String(format: "%.1f", val)
    }
}

struct ArtemisData {
    let timestamp: Date
    let positionKm: (x: Double, y: Double, z: Double)
    let velocityKmS: (vx: Double, vy: Double, vz: Double)
    let moonPositionKm: (x: Double, y: Double, z: Double)
    let moonVelocityKmS: (vx: Double, vy: Double, vz: Double)
    let distanceFromEarthKm: Double
    let distanceFromMoonKm: Double
    let speedKmS: Double
    let lightTimeSeconds: Double    // one-way signal delay
    let rangeRateKmS: Double        // positive = moving away from Earth

    var distanceFromEarthFormatted: String {
        if distanceFromEarthKm > 1_000_000 {
            return String(format: "%.1fM km", distanceFromEarthKm / 1_000_000)
        }
        return String(format: "%.0f km", distanceFromEarthKm)
    }

    var distanceFromMoonFormatted: String {
        if distanceFromMoonKm > 1_000_000 {
            return String(format: "%.1fM km", distanceFromMoonKm / 1_000_000)
        }
        return String(format: "%.0f km", distanceFromMoonKm)
    }

    var speedFormatted: String {
        return String(format: "%.2f km/s", speedKmS)
    }

    var signalDelayFormatted: String {
        return String(format: "%.2fs", lightTimeSeconds)
    }

    var missionPhase: String {
        let now = Date()
        let launch = MissionData.launchDate
        let enterSOI = MissionData.utcDate(2026, 4, 6, 4, 43)
        let closestApproach = MissionData.utcDate(2026, 4, 6, 23, 6)
        let exitSOI = MissionData.utcDate(2026, 4, 7, 17, 27)
        let splashdown = MissionData.splashdownDate

        if now < launch {
            return "Pre-Launch"
        } else if now > splashdown {
            return "Mission Complete"
        } else if now < enterSOI {
            if distanceFromEarthKm < 38_440 {
                return "Near Earth"
            }
            return "Outbound Transit"
        } else if now < closestApproach {
            return "Lunar Approach"
        } else if now < exitSOI {
            if distanceFromMoonKm < 15_000 {
                return "Lunar Flyby"
            }
            return "Lunar Vicinity"
        } else {
            if distanceFromEarthKm < 38_440 {
                return "Reentry Approach"
            }
            return "Return Transit"
        }
    }

    var progressToMoon: Double {
        let earthMoonDistance = 384_400.0
        return min(1.0, distanceFromEarthKm / earthMoonDistance)
    }
}

@MainActor
class ArtemisViewModel: ObservableObject {
    @Published var latestData: ArtemisData?
    @AppStorage("unitSystem") var unitSystem: String = UnitSystem.metric.rawValue
    var units: UnitSystem { UnitSystem(rawValue: unitSystem) ?? .metric }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastAPIFetch: Date?
    @Published var met: String = MissionData.metString()
    @Published var missionProgress: Double = MissionData.missionProgress()

    @Published var plannedTrajectory: [(x: Double, y: Double, z: Double)] = []
    @Published var moonOrbit: [(x: Double, y: Double, z: Double)] = []

    private var baseArtemis: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double)?
    private var baseMoon: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double)?
    private var baseLightTime: Double = 0
    private var baseRangeRate: Double = 0
    private var baseTime: Date?

    private var apiTimer: Timer?
    private var interpolationTimer: Timer?
    private var metTimer: Timer?
    private let horizonsAPI = HorizonsAPI()

    func startTracking() {
        fetchFromAPI()
        fetchTrajectory()

        apiTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchFromAPI()
            }
        }
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.interpolate()
            }
        }
        // Update MET every second
        metTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.met = MissionData.metString()
                self?.missionProgress = MissionData.missionProgress()
            }
        }
    }

    func fetchFromAPI() {
        if latestData == nil { isLoading = true }
        errorMessage = nil

        Task {
            do {
                let result = try await horizonsAPI.fetchRawVectors()
                self.baseArtemis = result.artemis
                self.baseMoon = result.moon
                self.baseLightTime = result.lightTime
                self.baseRangeRate = result.rangeRate
                self.baseTime = Date()
                self.lastAPIFetch = Date()
                self.isLoading = false
                self.interpolate()
            } catch {
                if self.latestData == nil {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }

    private func fetchTrajectory() {
        Task {
            do {
                let traj = try await horizonsAPI.fetchFullTrajectory()
                self.plannedTrajectory = traj
            } catch {
                print("Could not fetch trajectory: \(error)")
            }
        }
        Task {
            do {
                let orb = try await horizonsAPI.fetchMoonOrbit()
                self.moonOrbit = orb
            } catch {
                print("Could not fetch moon orbit: \(error)")
            }
        }
    }

    private func interpolate() {
        guard let art = baseArtemis, let moon = baseMoon, let base = baseTime else { return }

        let dt = Date().timeIntervalSince(base)

        let ax = art.x + art.vx * dt
        let ay = art.y + art.vy * dt
        let az = art.z + art.vz * dt

        let mx = moon.x + moon.vx * dt
        let my = moon.y + moon.vy * dt
        let mz = moon.z + moon.vz * dt

        let distEarth = sqrt(ax * ax + ay * ay + az * az)
        let dx = ax - mx, dy = ay - my, dz = az - mz
        let distMoon = sqrt(dx * dx + dy * dy + dz * dz)
        let speed = sqrt(art.vx * art.vx + art.vy * art.vy + art.vz * art.vz)

        // Interpolate light-time based on distance change
        let lt = distEarth / 299_792.458 // speed of light in km/s

        latestData = ArtemisData(
            timestamp: Date(),
            positionKm: (x: ax, y: ay, z: az),
            velocityKmS: (vx: art.vx, vy: art.vy, vz: art.vz),
            moonPositionKm: (x: mx, y: my, z: mz),
            moonVelocityKmS: (vx: moon.vx, vy: moon.vy, vz: moon.vz),
            distanceFromEarthKm: distEarth,
            distanceFromMoonKm: distMoon,
            speedKmS: speed,
            lightTimeSeconds: lt,
            rangeRateKmS: baseRangeRate
        )
    }

    func stopTracking() {
        apiTimer?.invalidate(); apiTimer = nil
        interpolationTimer?.invalidate(); interpolationTimer = nil
        metTimer?.invalidate(); metTimer = nil
    }
}
