import Foundation

struct SpaceEvent: Identifiable, Hashable {
    let id: String
    let name: String
    let net: Date  // "No Earlier Than" launch time
    let status: String
    let provider: String        // e.g. "SpaceX", "NASA"
    let rocketName: String      // e.g. "Falcon 9"
    let missionName: String?
    let missionDescription: String?

    /// Seconds until launch. Negative if already past.
    var timeUntilLaunch: TimeInterval {
        net.timeIntervalSince(Date())
    }

    /// Formatted countdown string: "T-02d 14h 22m" or "T-00h 05m 12s"
    var countdownFormatted: String {
        let secs = Int(timeUntilLaunch)
        if secs < 0 {
            return "LIVE"
        }
        let days = secs / 86400
        let hours = (secs % 86400) / 3600
        let mins = (secs % 3600) / 60
        let s = secs % 60
        if days > 0 {
            return String(format: "T-%dd %02dh %02dm", days, hours, mins)
        } else if hours > 0 {
            return String(format: "T-%02dh %02dm %02ds", hours, mins, s)
        } else {
            return String(format: "T-%02dm %02ds", mins, s)
        }
    }
}
