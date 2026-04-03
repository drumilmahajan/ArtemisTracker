import Foundation
import SwiftUI

struct ArtemisData {
    let timestamp: Date
    let positionKm: (x: Double, y: Double, z: Double)
    let velocityKmS: (vx: Double, vy: Double, vz: Double)
    let moonPositionKm: (x: Double, y: Double, z: Double)
    let moonVelocityKmS: (vx: Double, vy: Double, vz: Double)
    let distanceFromEarthKm: Double
    let distanceFromMoonKm: Double
    let speedKmS: Double

    var distanceFromEarthFormatted: String {
        if distanceFromEarthKm > 1_000_000 {
            return String(format: "%.1fM km", distanceFromEarthKm / 1_000_000)
        } else {
            return String(format: "%.0f km", distanceFromEarthKm)
        }
    }

    var distanceFromMoonFormatted: String {
        if distanceFromMoonKm > 1_000_000 {
            return String(format: "%.1fM km", distanceFromMoonKm / 1_000_000)
        } else {
            return String(format: "%.0f km", distanceFromMoonKm)
        }
    }

    var speedFormatted: String {
        return String(format: "%.2f km/s", speedKmS)
    }

    var missionPhase: String {
        let earthMoonDistance = 384_400.0
        let ratio = distanceFromEarthKm / earthMoonDistance
        if ratio < 0.1 {
            return "Near Earth"
        } else if ratio < 0.4 {
            return "Outbound Transit"
        } else if ratio < 0.7 {
            return "Mid-Course"
        } else if ratio < 0.95 {
            return "Lunar Approach"
        } else if distanceFromMoonKm < 10_000 {
            return "Lunar Flyby"
        } else if ratio > 0.7 {
            return "Return Transit"
        } else {
            return "In Transit"
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastAPIFetch: Date?

    // Raw state from last API call, used for interpolation
    private var baseArtemis: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double)?
    private var baseMoon: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double)?
    private var baseTime: Date?

    private var apiTimer: Timer?
    private var interpolationTimer: Timer?
    private let horizonsAPI = HorizonsAPI()

    func startTracking() {
        fetchFromAPI()
        // Fetch fresh data from API every 30 seconds
        apiTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchFromAPI()
            }
        }
        // Interpolate position every 100ms for smooth live updates
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.interpolate()
            }
        }
    }

    func fetchFromAPI() {
        if latestData == nil {
            isLoading = true
        }
        errorMessage = nil

        Task {
            do {
                let (artemis, moon) = try await horizonsAPI.fetchRawVectors()
                self.baseArtemis = artemis
                self.baseMoon = moon
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

    private func interpolate() {
        guard let art = baseArtemis, let moon = baseMoon, let base = baseTime else { return }

        let dt = Date().timeIntervalSince(base) // seconds since last API fetch

        // Extrapolate positions using velocity
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

        latestData = ArtemisData(
            timestamp: Date(),
            positionKm: (x: ax, y: ay, z: az),
            velocityKmS: (vx: art.vx, vy: art.vy, vz: art.vz),
            moonPositionKm: (x: mx, y: my, z: mz),
            moonVelocityKmS: (vx: moon.vx, vy: moon.vy, vz: moon.vz),
            distanceFromEarthKm: distEarth,
            distanceFromMoonKm: distMoon,
            speedKmS: speed
        )
    }

    func stopTracking() {
        apiTimer?.invalidate()
        apiTimer = nil
        interpolationTimer?.invalidate()
        interpolationTimer = nil
    }
}
