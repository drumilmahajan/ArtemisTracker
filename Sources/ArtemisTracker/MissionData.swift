import Foundation

/// Static mission data for Artemis II
enum MissionData {
    // Launch: April 1, 2026 22:35:12 UTC
    static let launchDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(
            year: 2026, month: 4, day: 1, hour: 22, minute: 35, second: 12
        ))!
    }()

    // Splashdown: ~April 11, 2026 00:06 UTC
    static let splashdownDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(
            year: 2026, month: 4, day: 11, hour: 0, minute: 6, second: 0
        ))!
    }()

    static let totalMissionSeconds: TimeInterval = {
        splashdownDate.timeIntervalSince(launchDate)
    }()

    // MARK: - Crew

    struct CrewMember {
        let name: String
        let role: String
        let agency: String
        let flag: String  // emoji flag
    }

    static let crew: [CrewMember] = [
        CrewMember(name: "Reid Wiseman", role: "Commander", agency: "NASA", flag: "🇺🇸"),
        CrewMember(name: "Victor Glover", role: "Pilot", agency: "NASA", flag: "🇺🇸"),
        CrewMember(name: "Christina Koch", role: "Mission Specialist", agency: "NASA", flag: "🇺🇸"),
        CrewMember(name: "Jeremy Hansen", role: "Mission Specialist", agency: "CSA", flag: "🇨🇦"),
    ]

    // MARK: - Mission Timeline

    struct MissionEvent {
        let date: Date
        let title: String
        let detail: String

        var isPast: Bool { Date() > date }

    }

    private static func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    static let timeline: [MissionEvent] = [
        MissionEvent(date: utc(2026, 4, 1, 22, 35), title: "Liftoff",
                     detail: "SLS launches from LC-39B, Kennedy Space Center"),
        MissionEvent(date: utc(2026, 4, 1, 22, 37), title: "SRB Separation",
                     detail: "Solid rocket boosters separate at ~48 km altitude"),
        MissionEvent(date: utc(2026, 4, 1, 22, 43), title: "Main Engine Cutoff",
                     detail: "Core stage separates, ICPS takes over"),
        MissionEvent(date: utc(2026, 4, 1, 22, 55), title: "Solar Arrays Deployed",
                     detail: "Orion deploys 4 solar array wings"),
        MissionEvent(date: utc(2026, 4, 2, 0, 23), title: "Apogee Raise Burn",
                     detail: "ICPS raises orbit to high elliptical"),
        MissionEvent(date: utc(2026, 4, 2, 1, 59), title: "Orion/ICPS Separation",
                     detail: "Orion separates from upper stage"),
        MissionEvent(date: utc(2026, 4, 2, 12, 19), title: "Perigee Raise Burn",
                     detail: "Orion main engine, 43 seconds"),
        MissionEvent(date: utc(2026, 4, 2, 23, 49), title: "Translunar Injection",
                     detail: "5m 50s burn, delta-V ~388 m/s — on course to Moon"),
        MissionEvent(date: utc(2026, 4, 3, 22, 43), title: "Trajectory Correction #1",
                     detail: "First outbound course correction"),
        MissionEvent(date: utc(2026, 4, 4, 23, 43), title: "Trajectory Correction #2",
                     detail: "Second outbound course correction"),
        MissionEvent(date: utc(2026, 4, 6, 3, 4), title: "Trajectory Correction #3",
                     detail: "Final correction before lunar flyby"),
        MissionEvent(date: utc(2026, 4, 6, 4, 43), title: "Enter Lunar SOI",
                     detail: "Orion enters Moon's sphere of influence"),
        MissionEvent(date: utc(2026, 4, 6, 23, 6), title: "Closest Lunar Approach",
                     detail: "~8,900 km from Moon's far side — closest to Moon"),
        MissionEvent(date: utc(2026, 4, 6, 23, 9), title: "Max Distance from Earth",
                     detail: "~407,000 km — farthest humans have ever traveled"),
        MissionEvent(date: utc(2026, 4, 7, 17, 27), title: "Exit Lunar SOI",
                     detail: "Orion leaves Moon's gravitational influence"),
        MissionEvent(date: utc(2026, 4, 8, 0, 4), title: "Return Correction #1",
                     detail: "First return trajectory correction"),
        MissionEvent(date: utc(2026, 4, 10, 0, 0), title: "Final Correction Burn",
                     detail: "Last trajectory adjustment before reentry"),
        MissionEvent(date: utc(2026, 4, 11, 0, 0), title: "Service Module Separation",
                     detail: "Crew module separates for reentry"),
        MissionEvent(date: utc(2026, 4, 11, 0, 6), title: "Splashdown",
                     detail: "Pacific Ocean, off San Diego coast"),
    ]

    // MARK: - Speed Context

    static func speedContext(kmPerSec: Double) -> String {
        let kmPerHour = kmPerSec * 3600
        let mach = kmPerSec / 0.343 // speed of sound ~343 m/s
        if mach > 1 {
            return String(format: "Mach %.0f (%.0f km/h)", mach, kmPerHour)
        }
        return String(format: "%.0f km/h", kmPerHour)
    }

    static func speedComparison(kmPerSec: Double) -> String {
        let issSpeed = 7.66 // km/s
        let bulletSpeed = 1.0 // km/s (rifle bullet ~1 km/s)
        if kmPerSec > issSpeed {
            return String(format: "%.1fx speed of ISS", kmPerSec / issSpeed)
        } else if kmPerSec > bulletSpeed {
            return String(format: "%.0fx speed of a bullet", kmPerSec / bulletSpeed)
        }
        return String(format: "%.0f km/h", kmPerSec * 3600)
    }

    // MARK: - MET Formatting

    static func metString(from date: Date = Date()) -> String {
        let elapsed = date.timeIntervalSince(launchDate)
        if elapsed < 0 {
            return "T-\(formatDuration(-elapsed))"
        }
        return "T+\(formatDuration(elapsed))"
    }

    static func missionProgress(from date: Date = Date()) -> Double {
        let elapsed = date.timeIntervalSince(launchDate)
        return max(0, min(1, elapsed / totalMissionSeconds))
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSec = Int(seconds)
        let days = totalSec / 86400
        let hours = (totalSec % 86400) / 3600
        let mins = (totalSec % 3600) / 60
        let secs = totalSec % 60
        if days > 0 {
            return String(format: "%dd %02dh %02dm %02ds", days, hours, mins, secs)
        }
        return String(format: "%02dh %02dm %02ds", hours, mins, secs)
    }

    /// Returns the next upcoming event and time until it
    static func nextEvent(from date: Date = Date()) -> (event: MissionEvent, timeUntil: TimeInterval)? {
        for event in timeline {
            let timeUntil = event.date.timeIntervalSince(date)
            if timeUntil > 0 {
                return (event, timeUntil)
            }
        }
        return nil
    }
}
