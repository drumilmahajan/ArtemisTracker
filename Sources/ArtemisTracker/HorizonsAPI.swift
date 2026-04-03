import Foundation

struct HorizonsAPI {
    private let baseURL = "https://ssd.jpl.nasa.gov/api/horizons.api"
    private let artemisID = "-1024"  // Artemis II spacecraft
    private let moonID = "301"       // Moon

    /// Returns raw state vectors for Artemis and Moon (Earth-centered)
    func fetchRawVectors() async throws -> (
        artemis: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double),
        moon: (x: Double, y: Double, z: Double, vx: Double, vy: Double, vz: Double)
    ) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let startTime = formatter.string(from: now.addingTimeInterval(-3600))
        let stopTime = formatter.string(from: now)

        async let artemisVectors = fetchVectors(target: artemisID, center: "500@399", start: startTime, stop: stopTime, step: "30 m")
        async let moonVectors = fetchVectors(target: moonID, center: "500@399", start: startTime, stop: stopTime, step: "30 m")

        let (artResult, moonResult) = try await (artemisVectors, moonVectors)

        guard let art = artResult.last, let moon = moonResult.last else {
            throw TrackerError.noDataAvailable
        }

        return (
            artemis: (x: art.x, y: art.y, z: art.z, vx: art.vx, vy: art.vy, vz: art.vz),
            moon: (x: moon.x, y: moon.y, z: moon.z, vx: moon.vx, vy: moon.vy, vz: moon.vz)
        )
    }

    /// Fetches the full planned trajectory for Artemis II (positions only)
    // Artemis II launched April 1, 2026 22:35 UTC. Horizons data starts ~3.5h after.
    // Mission is ~10 days.
    private let missionStart = "2026-04-02 03:00"
    private let missionEnd = "2026-04-10 23:00"

    /// Fetches full planned trajectory for Artemis II
    func fetchFullTrajectory() async throws -> [(x: Double, y: Double, z: Double)] {
        let vectors = try await fetchVectors(
            target: artemisID,
            center: "500@399",
            start: missionStart,
            stop: missionEnd,
            step: "1 h"
        )
        return vectors.map { (x: $0.x, y: $0.y, z: $0.z) }
    }

    /// Fetches Moon positions over the mission window
    func fetchMoonOrbit() async throws -> [(x: Double, y: Double, z: Double)] {
        let vectors = try await fetchVectors(
            target: moonID,
            center: "500@399",
            start: missionStart,
            stop: missionEnd,
            step: "2 h"
        )
        return vectors.map { (x: $0.x, y: $0.y, z: $0.z) }
    }

    struct StateVector {
        let x, y, z: Double
        let vx, vy, vz: Double
    }

    private func fetchVectors(target: String, center: String, start: String, stop: String, step: String) async throws -> [StateVector] {
        // Build URL string manually to avoid encoding issues
        let startEnc = start.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? start
        let stopEnc = stop.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stop
        let stepEnc = step.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? step

        let urlString = "\(baseURL)?format=text"
            + "&COMMAND='\(target)'"
            + "&EPHEM_TYPE='VECTORS'"
            + "&CENTER='\(center)'"
            + "&START_TIME='\(startEnc)'"
            + "&STOP_TIME='\(stopEnc)'"
            + "&STEP_SIZE='\(stepEnc)'"
            + "&OUT_UNITS='KM-S'"
            + "&REF_SYSTEM='ICRF'"
            + "&VEC_TABLE='3'"
            + "&CSV_FORMAT='YES'"

        guard let url = URL(string: urlString) else {
            throw TrackerError.invalidURL
        }

        // Retry up to 3 times with backoff for transient errors (503, timeouts)
        var lastError: Error?
        for attempt in 0..<3 {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(attempt) * 3_000_000_000) // 3s, 6s
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        guard let text = String(data: data, encoding: .utf8) else {
                            throw TrackerError.parseError("Could not decode response")
                        }
                        return try parseVectors(from: text)
                    }
                    // Retry on 503/429/5xx
                    if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
                        lastError = TrackerError.apiError("Server busy (HTTP \(httpResponse.statusCode)), retrying...")
                        continue
                    }
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw TrackerError.apiError("HTTP \(httpResponse.statusCode): \(body.prefix(200))")
                }
            } catch let error as TrackerError {
                throw error // Don't retry our own parse errors
            } catch {
                lastError = error
                continue // Retry network errors
            }
        }
        throw lastError ?? TrackerError.apiError("Failed after 3 retries")
    }

    private func parseVectors(from text: String) throws -> [StateVector] {
        guard let soeRange = text.range(of: "$$SOE"),
              let eoeRange = text.range(of: "$$EOE") else {
            if text.contains("No ephemeris for target") {
                throw TrackerError.noDataAvailable
            }
            throw TrackerError.parseError("Could not find ephemeris data markers in response")
        }

        let dataSection = text[soeRange.upperBound..<eoeRange.lowerBound]
        var vectors: [StateVector] = []

        let lines = dataSection.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            let parts = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            if parts.count >= 8,
               let x = Double(parts[2]),
               let y = Double(parts[3]),
               let z = Double(parts[4]),
               let vx = Double(parts[5]),
               let vy = Double(parts[6]),
               let vz = Double(parts[7]) {
                vectors.append(StateVector(x: x, y: y, z: z, vx: vx, vy: vy, vz: vz))
            }
        }

        if vectors.isEmpty {
            throw TrackerError.noDataAvailable
        }

        return vectors
    }
}

enum TrackerError: LocalizedError {
    case invalidURL
    case apiError(String)
    case parseError(String)
    case noDataAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .apiError(let msg): return "API error: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .noDataAvailable: return "No position data available yet. The spacecraft may not have launched or data may not be published."
        }
    }
}
