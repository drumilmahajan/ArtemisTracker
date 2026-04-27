import Foundation

/// A spacecraft currently in orbit, fetched live from Launch Library 2.
struct SpacecraftInOrbit: Identifiable, Hashable {
    let id: Int
    let name: String
    let status: String          // "Active", "Single Use", etc.
    let description: String
    let configName: String      // e.g. "Crew Dragon 2", "Soyuz MS"
    let agencyName: String      // e.g. "SpaceX", "ROSCOSMOS"
    let timeInSpace: String?    // ISO 8601 duration e.g. "P146DT16H13M49S"
    let imageURL: String?

    /// Formatted time in space: "146d 16h"
    var timeInSpaceFormatted: String {
        guard let dur = timeInSpace else { return "" }
        // Parse ISO 8601 duration: P146DT16H13M49S
        var days = 0, hours = 0
        var numStr = ""
        var inTime = false
        for c in dur {
            if c == "P" { continue }
            if c == "T" { inTime = true; continue }
            if c.isNumber { numStr += String(c); continue }
            let val = Int(numStr) ?? 0
            numStr = ""
            if c == "D" { days = val }
            else if c == "H" && inTime { hours = val }
        }
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return ""
    }
}
