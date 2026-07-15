import SwiftUI
import WidgetKit

// Regras de design (dataviz): valor sempre em texto com cor de texto; a cor de
// status só preenche o medidor e nunca carrega significado sozinha; estado
// desatualizado usa ícone + rótulo, não só cor.

func statusColor(_ percent: Double) -> Color {
    switch percent {
    case ..<70: return .green
    case ..<90: return .orange
    default: return .red
    }
}

func formatTokens(_ count: Int) -> String {
    switch count {
    case 1_000_000...: return String(format: "%.1fM", Double(count) / 1_000_000)
    case 1_000...: return String(format: "%.0fK", Double(count) / 1_000)
    default: return "\(count)"
    }
}

func formatCost(_ stats: TodayStats) -> String {
    let prefix = stats.costIsPartial ? "~" : ""
    return prefix + String(format: "US$ %.2f", stats.costUSD)
}

struct BucketGaugeView: View {
    let title: String
    let bucket: UsageBucket?
    var showsReset: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let pct = bucket?.utilization {
                    Text("\(Int(pct.rounded()))%")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: min(max((bucket?.utilization ?? 0) / 100, 0), 1))
                .progressViewStyle(.linear)
                .tint(statusColor(bucket?.utilization ?? 0))
            if showsReset, let resetsAt = bucket?.resetsAt, resetsAt > Date() {
                (Text("reseta em ") + Text(resetsAt, style: .relative))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

/// Glifo do tacômetro (a "logo" do app) desenhado nativo — adapta a light/dark.
struct TachGlyph: View {
    var size: CGFloat = 15
    private let coral = Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)

    var body: some View {
        ZStack {
            ForEach(0..<9, id: \.self) { i in
                Capsule()
                    .fill(i >= 7 ? coral : Color.secondary.opacity(0.75))
                    .frame(width: size * 0.09, height: size * 0.24)
                    .offset(y: -size * 0.38)
                    .rotationEffect(.degrees(-135 + Double(i) * 270 / 8))
            }
            Capsule()
                .fill(coral)
                .frame(width: size * 0.1, height: size * 0.46)
                .offset(y: -size * 0.18)
                .rotationEffect(.degrees(54))
            Circle()
                .fill(coral)
                .frame(width: size * 0.22, height: size * 0.22)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct StaleBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text("desatualizado")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

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
                Text("Abra o app Claude Usage para começar")
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
            BucketGaugeView(title: "Sessão 5h", bucket: snapshot.fiveHour)
            BucketGaugeView(title: "Semana", bucket: snapshot.sevenDay, showsReset: false)
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
                BucketGaugeView(title: "Sessão 5h", bucket: snapshot.fiveHour)
                    .frame(maxWidth: .infinity)
                BucketGaugeView(title: "Semana", bucket: snapshot.sevenDay)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            if let today = snapshot.today {
                HStack(alignment: .firstTextBaseline) {
                    Text("Hoje")
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
