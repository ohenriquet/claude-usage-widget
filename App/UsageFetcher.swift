import Foundation

/// Busca os limites do plano no endpoint que o /usage do Claude Code usa.
enum UsageFetcher {
    struct PlanUsage {
        var fiveHour: UsageBucket?
        var sevenDay: UsageBucket?
        var sevenDayOpus: UsageBucket?
        var sevenDaySonnet: UsageBucket?
    }

    private struct Response: Decodable {
        struct Bucket: Decodable {
            let utilization: Double?
            let resetsAt: String?
            enum CodingKeys: String, CodingKey {
                case utilization
                case resetsAt = "resets_at"
            }
        }
        let fiveHour: Bucket?
        let sevenDay: Bucket?
        let sevenDayOpus: Bucket?
        let sevenDaySonnet: Bucket?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
            case sevenDayOpus = "seven_day_opus"
            case sevenDaySonnet = "seven_day_sonnet"
        }
    }

    enum FetchError: Error {
        case noToken
        case badStatus(Int)
        case badPayload
    }

    static func fetch(accessToken: String) async throws -> PlanUsage {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Sem este User-Agent a request cai num bucket anônimo com 429 persistente.
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.badPayload }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.badStatus(http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw FetchError.badPayload
        }

        func bucket(_ b: Response.Bucket?) -> UsageBucket? {
            guard let b else { return nil }
            return UsageBucket(utilization: b.utilization, resetsAt: b.resetsAt.flatMap(parseISO8601))
        }
        return PlanUsage(
            fiveHour: bucket(decoded.fiveHour),
            sevenDay: bucket(decoded.sevenDay),
            sevenDayOpus: bucket(decoded.sevenDayOpus),
            sevenDaySonnet: bucket(decoded.sevenDaySonnet)
        )
    }

    /// resets_at vem como ISO-8601 com frações de segundo; aceita também sem frações.
    static func parseISO8601(_ string: String) -> Date? {
        let withFractions = ISO8601DateFormatter()
        withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractions.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
