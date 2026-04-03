import Foundation

struct HorizonsAPI {
    private let baseURL = "https://ssd.jpl.nasa.gov/api/horizons.api"
    private let artemisID = "-1024"  // Artemis II Orion spacecraft
    private let moonID = "301"       // Moon

    /// Fetches the current Artemis position relative to Earth and computes distance to Moon
    func fetchArtemisPosition() async throws -> ArtemisData {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let startTime = formatter.string(from: now.addingTimeInterval(-3600)) // 1 hour ago
        let stopTime = formatter.string(from: now)

        // Fetch Artemis position relative to Earth center
        let earthData = try await fetchVectors(
            target: artemisID,
            center: "500@399",  // Earth center
            start: startTime,
            stop: stopTime
        )

        // Fetch Moon position relative to Earth center (to compute Artemis-Moon distance)
        let moonData = try await fetchVectors(
            target: moonID,
            center: "500@399",
            start: startTime,
            stop: stopTime
        )

        guard let artemisState = earthData.last, let moonState = moonData.last else {
            throw TrackerError.noDataAvailable
        }

        // Distance from Earth = magnitude of position vector
        let distEarth = sqrt(
            artemisState.x * artemisState.x +
            artemisState.y * artemisState.y +
            artemisState.z * artemisState.z
        )

        // Distance from Moon = magnitude of (artemis - moon) position vector
        let dx = artemisState.x - moonState.x
        let dy = artemisState.y - moonState.y
        let dz = artemisState.z - moonState.z
        let distMoon = sqrt(dx * dx + dy * dy + dz * dz)

        // Speed
        let speed = sqrt(
            artemisState.vx * artemisState.vx +
            artemisState.vy * artemisState.vy +
            artemisState.vz * artemisState.vz
        )

        return ArtemisData(
            timestamp: now,
            positionKm: (x: artemisState.x, y: artemisState.y, z: artemisState.z),
            velocityKmS: (vx: artemisState.vx, vy: artemisState.vy, vz: artemisState.vz),
            distanceFromEarthKm: distEarth,
            distanceFromMoonKm: distMoon,
            speedKmS: speed
        )
    }

    struct StateVector {
        let x, y, z: Double       // position in km
        let vx, vy, vz: Double    // velocity in km/s
    }

    private func fetchVectors(target: String, center: String, start: String, stop: String) async throws -> [StateVector] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "text"),
            URLQueryItem(name: "COMMAND", value: "'\(target)'"),
            URLQueryItem(name: "EPHEM_TYPE", value: "'VECTORS'"),
            URLQueryItem(name: "CENTER", value: "'\(center)'"),
            URLQueryItem(name: "START_TIME", value: "'\(start)'"),
            URLQueryItem(name: "STOP_TIME", value: "'\(stop)'"),
            URLQueryItem(name: "STEP_SIZE", value: "'30 m'"),  // 30-minute steps
            URLQueryItem(name: "OUT_UNITS", value: "'KM-S'"),
            URLQueryItem(name: "REF_SYSTEM", value: "'ICRF'"),
            URLQueryItem(name: "VEC_TABLE", value: "'3'"),
            URLQueryItem(name: "CSV_FORMAT", value: "'YES'"),
        ]

        guard let url = components.url else {
            throw TrackerError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TrackerError.apiError("HTTP error")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw TrackerError.parseError("Could not decode response")
        }

        return try parseVectors(from: text)
    }

    private func parseVectors(from text: String) throws -> [StateVector] {
        // Find data between $$SOE and $$EOE markers
        guard let soeRange = text.range(of: "$$SOE"),
              let eoeRange = text.range(of: "$$EOE") else {
            // Check if there's an error message
            if text.contains("No ephemeris for target") {
                throw TrackerError.noDataAvailable
            }
            throw TrackerError.parseError("Could not find ephemeris data markers in response")
        }

        let dataSection = text[soeRange.upperBound..<eoeRange.lowerBound]
        var vectors: [StateVector] = []

        // CSV format: each data entry spans multiple lines
        // Format with VEC_TABLE=3 and CSV_FORMAT=YES:
        // JDTDB, Calendar Date, X, Y, Z, VX, VY, VZ, LT, RG, RR,
        let lines = dataSection.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            let parts = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // We need at least 8 values: JDTDB, CalDate, X, Y, Z, VX, VY, VZ
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
