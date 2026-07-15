import SwiftUI

// Componentes visuais compartilhados entre o widget e o painel da barra de menu.
// Regras de design (dataviz): valor sempre em texto com cor de texto; a cor de
// status só preenche o medidor e nunca carrega significado sozinha; estado
// desatualizado usa ícone + rótulo, não só cor.

let claudeCoral = Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)

func statusColor(_ percent: Double) -> Color {
    switch percent {
    case ..<70: return .green
    case ..<90: return .orange
    default: return .red
    }
}

func formatTokens(_ count: Int) -> String {
    switch count {
    case 1_000_000...: return String(format: "%.1fM", locale: .current, Double(count) / 1_000_000)
    case 1_000...: return String(format: "%.0fK", locale: .current, Double(count) / 1_000)
    default: return "\(count)"
    }
}

func formatCost(_ stats: TodayStats) -> String {
    let prefix = stats.costIsPartial ? "~" : ""
    return prefix + String(format: "US$ %.2f", stats.costUSD)
}

/// Glifo do tacômetro (a "logo" do app) desenhado nativo — adapta a light/dark.
struct TachGlyph: View {
    var size: CGFloat = 15

    var body: some View {
        ZStack {
            ForEach(0..<9, id: \.self) { i in
                Capsule()
                    .fill(i >= 7 ? claudeCoral : Color.secondary.opacity(0.75))
                    .frame(width: size * 0.09, height: size * 0.24)
                    .offset(y: -size * 0.38)
                    .rotationEffect(.degrees(-135 + Double(i) * 270 / 8))
            }
            Capsule()
                .fill(claudeCoral)
                .frame(width: size * 0.1, height: size * 0.46)
                .offset(y: -size * 0.18)
                .rotationEffect(.degrees(54))
            Circle()
                .fill(claudeCoral)
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
            Text("stale")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

struct BucketGaugeView: View {
    let title: LocalizedStringKey
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
                (Text("resets in") + Text(" ") + Text(resetsAt, style: .relative))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}
