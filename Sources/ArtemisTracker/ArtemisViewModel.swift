import Foundation
import SwiftUI

struct ArtemisData {
    let timestamp: Date
    let positionKm: (x: Double, y: Double, z: Double)     // Earth-centered J2000
    let velocityKmS: (vx: Double, vy: Double, vz: Double)
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
        let earthMoonDistance = 384_400.0  // average km
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
    @Published var lastUpdated: Date?

    private var timer: Timer?
    private let horizonsAPI = HorizonsAPI()

    func startTracking() {
        fetchData()
        // Refresh every 3 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchData()
            }
        }
    }

    func fetchData() {
        // Only show loading spinner on first fetch
        if latestData == nil {
            isLoading = true
        }
        errorMessage = nil

        Task {
            do {
                let data = try await horizonsAPI.fetchArtemisPosition()
                self.latestData = data
                self.lastUpdated = Date()
                self.isLoading = false
            } catch {
                // Don't overwrite existing data on refresh failures
                if self.latestData == nil {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
}
