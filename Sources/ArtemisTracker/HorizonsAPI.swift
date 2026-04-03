import Foundation

struct HorizonsAPI {
    private let baseURL = "https://ssd.jpl.nasa.gov/api/horizons.api"
    private let artemisID = "-1024"  // Artemis II Orion spacecraft
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

        async let artemisVectors = fetchVectors(target: artemisID, center: "500@399", start: startTime, stop: stopTime)
        async let moonVectors = fetchVectors(target: moonID, center: "500@399", start: startTime, stop: stopTime)

        let (artResult, moonResult) = try await (artemisVectors, moonVectors)

        guard let art = artResult.last, let moon = moonResult.last else {
            throw TrackerError.noDataAvailable
        }

        return (
            artemis: (x: art.x, y: art.y, z: art.z, vx: art.vx, vy: art.vy, vz: art.vz),
            moon: (x: moon.x, y: moon.y, z: moon.z, vx: moon.vx, vy: moon.vy, vz: moon.vz)
        )
    }

    struct StateVector {
        let x, y, z: Double
        let vx, vy, vz: Double
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
            URLQueryItem(name: "STEP_SIZE", value: "'30 m'"),
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
