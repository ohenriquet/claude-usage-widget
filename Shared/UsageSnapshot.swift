import Foundation

/// Um bucket de limite do plano (sessão de 5h, semanal, etc.)
struct UsageBucket: Codable, Equatable {
    /// 0–100
    var utilization: Double?
    var resetsAt: Date?
}

/// Totais de hoje calculados dos transcripts JSONL locais do Claude Code.
struct TodayStats: Codable, Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var costUSD: Double = 0
    /// true quando alguma entrada tinha modelo desconhecido (custo subestimado → exibir "~")
    var costIsPartial: Bool = false

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

/// O que o app grava no App Group e o widget renderiza.
struct UsageSnapshot: Codable, Equatable {
    var fiveHour: UsageBucket?
    var sevenDay: UsageBucket?
    var sevenDayOpus: UsageBucket?
    var sevenDaySonnet: UsageBucket?
    var today: TodayStats?
    var fetchedAt: Date = .distantPast
    /// false quando o último fetch do endpoint falhou (token ausente/expirado, rede, 4xx/5xx)
    var planFetchSucceeded: Bool = false

    /// Compara só o que muda pixels no widget — usado para poupar o budget de reload do WidgetKit.
    func materiallyEquals(_ other: UsageSnapshot) -> Bool {
        func rounded(_ b: UsageBucket?) -> [Double?] {
            [b?.utilization.map { ($0 * 10).rounded() / 10 },
             b?.resetsAt?.timeIntervalSinceReferenceDate.rounded()]
        }
        return rounded(fiveHour) == rounded(other.fiveHour)
            && rounded(sevenDay) == rounded(other.sevenDay)
            && rounded(sevenDayOpus) == rounded(other.sevenDayOpus)
            && rounded(sevenDaySonnet) == rounded(other.sevenDaySonnet)
            && today?.totalTokens == other.today?.totalTokens
            && ((today?.costUSD ?? 0) * 100).rounded() == (((other.today?.costUSD ?? 0) * 100).rounded())
            && planFetchSucceeded == other.planFetchSucceeded
    }

    /// Snapshot considerado velho demais (app parado, erro persistente).
    var isStale: Bool {
        !planFetchSucceeded || Date().timeIntervalSince(fetchedAt) > 20 * 60
    }
}
