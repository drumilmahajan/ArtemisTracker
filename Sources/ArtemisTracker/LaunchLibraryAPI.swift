import Foundation

/// Client for The Space Devs' Launch Library 2 API.
/// Free tier: 15 requests/hour. https://thespacedevs.com/llapi
struct LaunchLibraryAPI {
    private let baseURL = "https://ll.thespacedevs.com/2.3.0/launches/upcoming/"

    func fetchUpcoming(limit: Int = 20) async throws -> [SpaceEvent] {
        guard var components = URLComponents(string: baseURL) else {
            throw TrackerError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "mode", value: "normal"),
        ]
        guard let url = components.url else {
            throw TrackerError.invalidURL
        }

        // Retry up to 3 times with backoff for transient errors
        var lastError: Error?
        for attempt in 0..<3 {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(attempt) * 3_000_000_000)
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        return try parseResponse(data)
                    }
                    if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
                        lastError = TrackerError.apiError("Server busy (HTTP \(httpResponse.statusCode))")
                        continue
                    }
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw TrackerError.apiError("HTTP \(httpResponse.statusCode): \(body.prefix(200))")
                }
            } catch let error as TrackerError {
                throw error
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? TrackerError.apiError("Failed after 3 retries")
    }

    private func parseResponse(_ data: Data) throws -> [SpaceEvent] {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = formatter.date(from: str) { return d }
            if let d = fallback.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }

        let raw = try decoder.decode(LLResponse.self, from: data)
        return raw.results.compactMap { $0.toSpaceEvent() }
    }

    // MARK: - Raw API models (only fields we need)

    private struct LLResponse: Decodable {
        let results: [LLLaunch]
    }

    private struct LLLaunch: Decodable {
        let id: String
        let name: String
        let net: Date
        let status: LLStatus?
        let launch_service_provider: LLProvider?
        let rocket: LLRocket?
        let mission: LLMission?

        func toSpaceEvent() -> SpaceEvent {
            SpaceEvent(
                id: id,
                name: name,
                net: net,
                status: status?.name ?? "Unknown",
                provider: launch_service_provider?.name ?? "Unknown",
                rocketName: rocket?.configuration?.name ?? "Unknown Rocket",
                missionName: mission?.name,
                missionDescription: mission?.description
            )
        }
    }

    private struct LLStatus: Decodable {
        let name: String
    }

    private struct LLProvider: Decodable {
        let name: String
    }

    private struct LLRocket: Decodable {
        let configuration: LLRocketConfig?
    }

    private struct LLRocketConfig: Decodable {
        let name: String
    }

    private struct LLMission: Decodable {
        let name: String?
        let description: String?
    }
}
