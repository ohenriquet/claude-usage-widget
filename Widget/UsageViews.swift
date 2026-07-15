import SwiftUI
import WidgetKit

// Componentes (TachGlyph, BucketGaugeView, StaleBadge, formatters) em Shared/UsageComponents.swift.

struct UsageWidgetView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Open the Claude Usage app to get started")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private func content(_ snapshot: UsageSnapshot) -> some View {
        switch family {
        case .systemMedium: medium(snapshot)
        default: small(snapshot)
        }
    }

    private func header(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 6) {
            Text("Claude")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Spacer()
            if snapshot.isStale { StaleBadge() }
            TachGlyph()
        }
    }

    private func small(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(snapshot)
            BucketGaugeView(title: "Session (5h)", bucket: snapshot.fiveHour)
            BucketGaugeView(title: "Week", bucket: snapshot.sevenDay, showsReset: false)
            if let today = snapshot.today {
                Text("\(formatTokens(today.totalTokens)) tok · \(formatCost(today))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func medium(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(snapshot)
            HStack(alignment: .top, spacing: 16) {
                BucketGaugeView(title: "Session (5h)", bucket: snapshot.fiveHour)
                    .frame(maxWidth: .infinity)
                BucketGaugeView(title: "Week", bucket: snapshot.sevenDay)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            if let today = snapshot.today {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatTokens(today.totalTokens)) tokens")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                    Text(formatCost(today))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                }
            }
        }
    }
}
