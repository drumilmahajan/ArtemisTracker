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

struct TrackingData {
    let timestamp: Date
    let positionKm: (x: Double, y: Double, z: Double)
    let velocityKmS: (vx: Double, vy: Double, vz: Double)
    let moonPositionKm: (x: Double, y: Double, z: Double)
    let moonVelocityKmS: (vx: Double, vy: Double, vz: Double)
    let distanceFromCenterKm: Double  // distance from center body (Earth or Sun)
    let distanceFromMoonKm: Double
    let speedKmS: Double
    let lightTimeSeconds: Double
    let rangeRateKmS: Double

    var signalDelayFormatted: String {
        return String(format: "%.2fs", lightTimeSeconds)
    }
}

@MainActor
class GalileoViewModel: ObservableObject {
    @Published var latestData: TrackingData?
    @AppStorage("unitSystem") var unitSystem: String = UnitSystem.metric.rawValue
    var units: UnitSystem { UnitSystem(rawValue: unitSystem) ?? .metric }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastAPIFetch: Date?

    @Published var plannedTrajectory: [(x: Double, y: Double, z: Double)] = []
    @Published var moonOrbit: [(x: Double, y: Double, z: Double)] = []
    @Published var sunPosition: (x: Double, y: Double, z: Double)?

    @Published var upcomingEvents: [SpaceEvent] = []
    @Published var spacecraftInOrbit: [SpacecraftInOrbit] = []
    @Published var eventsError: String?

    @AppStorage("watchedEventId") var watchedEventId: String = "iss"

    /// The currently watched trackable mission (if any)
    var watchedMission: TrackableMission? {
        TrackableMission.allMissions.first { $0.id == watchedEventId }
    }

    /// The currently watched upcoming event (if not watching a mission)
    var watchedEvent: SpaceEvent? {
        if watchedMission != nil { return nil }
        return upcomingEvents.first { $0.id == watchedEventId }
    }

    func watchMission(_ mission: TrackableMission) {
        let changed = watchedEventId != mission.id
        watchedEventId = mission.id
        if changed {
            latestData = nil
            baseTarget = nil
            baseMoon = nil
            baseTime = nil
            plannedTrajectory = []
            moonOrbit = []
            restartAPITimer(interval: mission.refreshInterval)
            fetchFromAPI()
            fetchOrbitTrail(for: mission)
        }
    }

    func watchEvent(_ event: SpaceEvent) {
        watchedEventId = event.id
    }

    /// Migrate persisted watchedEventId if it references an unavailable mission
    private func migrateWatchedEventIfNeeded() {
        if watchedMission == nil && watchedEvent == nil {
            if let first = TrackableMission.allMissions.first {
                watchedEventId = first.id
            }
        }
    }

    private var baseTarget: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double)?
    private var baseMoon: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double)?
    private var baseLightTime: Double = 0
    private var baseRangeRate: Double = 0
    private var baseTime: Date?

    private var apiTimer: Timer?
    private var interpolationTimer: Timer?
    private var eventsTimer: Timer?
    private let horizonsAPI = HorizonsAPI()
    private let launchLibraryAPI = LaunchLibraryAPI()

    func startTracking() {
        migrateWatchedEventIfNeeded()
        fetchFromAPI()
        if let mission = watchedMission {
            fetchOrbitTrail(for: mission)
        }
        fetchUpcomingEvents()

        let interval = watchedMission?.refreshInterval ?? 30
        apiTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchFromAPI()
            }
        }
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.interpolate()
            }
        }
        eventsTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchUpcomingEvents()
            }
        }
    }

    private func restartAPITimer(interval: TimeInterval) {
        apiTimer?.invalidate()
        apiTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchFromAPI()
            }
        }
    }

    func fetchFromAPI() {
        guard let mission = watchedMission else { return }

        if latestData == nil { isLoading = true }
        errorMessage = nil

        Task {
            do {
                let target = try await horizonsAPI.fetchTargetVectors(
                    targetId: mission.horizonsId, center: mission.centerBody.rawValue)
                self.baseTarget = (x: target.x, y: target.y, z: target.z,
                                   vx: target.vx, vy: target.vy, vz: target.vz)
                self.baseLightTime = target.lt
                self.baseRangeRate = target.rr

                if let secondaryId = mission.secondaryBodyId {
                    let moon = try await horizonsAPI.fetchTargetVectors(
                        targetId: secondaryId, center: mission.centerBody.rawValue)
                    self.baseMoon = (x: moon.x, y: moon.y, z: moon.z,
                                    vx: moon.vx, vy: moon.vy, vz: moon.vz)
                }

                if mission.centerBody == .earth {
                    let sun = try await horizonsAPI.fetchSunPosition(center: mission.centerBody.rawValue)
                    self.sunPosition = sun
                }

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

    private func fetchOrbitTrail(for mission: TrackableMission) {
        Task {
            do {
                let trail = try await horizonsAPI.fetchOrbitTrail(mission: mission)
                self.plannedTrajectory = trail
            } catch {
                print("Could not fetch orbit trail for \(mission.name): \(error)")
            }
        }
        if mission.showMoon {
            Task {
                do {
                    let orb = try await horizonsAPI.fetchMoonOrbit()
                    self.moonOrbit = orb
                } catch {
                    print("Could not fetch moon orbit: \(error)")
                }
            }
        }
    }

    func fetchUpcomingEvents() {
        Task {
            do {
                let events = try await launchLibraryAPI.fetchUpcoming(limit: 20)
                self.upcomingEvents = events
                self.eventsError = nil
            } catch {
                self.eventsError = error.localizedDescription
                print("Could not fetch upcoming events: \(error)")
            }
        }
        Task {
            do {
                let spacecraft = try await launchLibraryAPI.fetchInSpace()
                self.spacecraftInOrbit = spacecraft
            } catch {
                print("Could not fetch spacecraft in orbit: \(error)")
            }
        }
    }

    private func interpolate() {
        guard let tgt = baseTarget, let base = baseTime else { return }

        let dt = Date().timeIntervalSince(base)

        let tx = tgt.x + tgt.vx * dt
        let ty = tgt.y + tgt.vy * dt
        let tz = tgt.z + tgt.vz * dt

        var mx = 0.0, my = 0.0, mz = 0.0
        if let moon = baseMoon {
            mx = moon.x + moon.vx * dt
            my = moon.y + moon.vy * dt
            mz = moon.z + moon.vz * dt
        }

        let distCenter = sqrt(tx * tx + ty * ty + tz * tz)
        let dx = tx - mx, dy = ty - my, dz = tz - mz
        let distMoon = baseMoon != nil ? sqrt(dx * dx + dy * dy + dz * dz) : 0
        let speed = sqrt(tgt.vx * tgt.vx + tgt.vy * tgt.vy + tgt.vz * tgt.vz)

        let lt = distCenter / 299_792.458

        latestData = TrackingData(
            timestamp: Date(),
            positionKm: (x: tx, y: ty, z: tz),
            velocityKmS: (vx: tgt.vx, vy: tgt.vy, vz: tgt.vz),
            moonPositionKm: (x: mx, y: my, z: mz),
            moonVelocityKmS: baseMoon.map { (vx: $0.vx, vy: $0.vy, vz: $0.vz) } ?? (vx: 0, vy: 0, vz: 0),
            distanceFromCenterKm: distCenter,
            distanceFromMoonKm: distMoon,
            speedKmS: speed,
            lightTimeSeconds: lt,
            rangeRateKmS: baseRangeRate
        )
    }

    func stopTracking() {
        apiTimer?.invalidate(); apiTimer = nil
        interpolationTimer?.invalidate(); interpolationTimer = nil
        eventsTimer?.invalidate(); eventsTimer = nil
    }
}
