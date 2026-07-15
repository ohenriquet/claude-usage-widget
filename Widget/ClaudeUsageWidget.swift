import SwiftUI
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
}

/// Snapshot de exemplo para o preview da galeria de widgets.
private let sampleSnapshot: UsageSnapshot = {
    var s = UsageSnapshot()
    s.fiveHour = UsageBucket(utilization: 63, resetsAt: Date().addingTimeInterval(107 * 60))
    s.sevenDay = UsageBucket(utilization: 31, resetsAt: Date().addingTimeInterval(4 * 24 * 3600))
    var today = TodayStats()
    today.inputTokens = 180_000
    today.outputTokens = 95_000
    today.cacheCreationTokens = 400_000
    today.cacheReadTokens = 1_700_000
    today.costUSD = 12.80
    s.today = today
    s.fetchedAt = Date()
    s.planFetchSucceeded = true
    return s
}()

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let snapshot = context.isPreview ? (SnapshotStore.load() ?? sampleSnapshot) : SnapshotStore.load()
        completion(UsageEntry(date: Date(), snapshot: snapshot))
    }

    /// Provider autossuficiente: relê o snapshot do App Group a cada timeline.
    /// O app pede reload quando os dados mudam; este .after é só o fallback
    /// caso o reload seja descartado pelo throttling do WidgetKit.
    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = UsageEntry(date: Date(), snapshot: SnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeUsageWidget()
    }
}

struct ClaudeUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeUsageWidget", provider: Provider()) { entry in
            UsageWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Claude Usage")
        .description("Uso do plano claude.ai e tokens de hoje")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
