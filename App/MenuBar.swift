import SwiftUI

/// Estado observável que alimenta o label e o painel da barra de menu.
@MainActor
final class UsageModel: ObservableObject {
    static let shared = UsageModel()
    @Published var snapshot: UsageSnapshot? = SnapshotStore.load()
}

struct MenuBarLabel: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "speedometer")
            if let pct = model.snapshot?.fiveHour?.utilization {
                Text("\(Int(pct.rounded()))%")
            }
        }
    }
}

struct MenuBarPanel: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                if model.snapshot?.isStale ?? false { StaleBadge() }
                TachGlyph(size: 18)
            }

            if let snapshot = model.snapshot {
                BucketGaugeView(title: "Session (5h)", bucket: snapshot.fiveHour)
                BucketGaugeView(title: "Week", bucket: snapshot.sevenDay)
                if let today = snapshot.today {
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatTokens(today.totalTokens)) tokens · \(formatCost(today))")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                }
            } else {
                Text("No data yet — waiting for the first refresh…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Button("Refresh") { Task { await Refresher.refresh() } }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(14)
        .frame(width: 260)
        .onAppear { Task { await Refresher.refresh() } }
    }
}
