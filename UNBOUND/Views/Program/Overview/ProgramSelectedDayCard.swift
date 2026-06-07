import SwiftUI

struct ProgramSelectedDayCard<Content: View>: View {
    let headerLabel: String
    let title: String
    let contextLabel: String
    let badge: ProgramDayBadgeState
    let heroTint: Color
    let isToday: Bool
    let metrics: [ProgramCommandMetricModel]
    let skillNodes: [SkillNode]
    let content: Content

    init(
        headerLabel: String,
        title: String,
        contextLabel: String,
        badge: ProgramDayBadgeState,
        heroTint: Color,
        isToday: Bool,
        metrics: [ProgramCommandMetricModel],
        skillNodes: [SkillNode],
        @ViewBuilder content: () -> Content
    ) {
        self.headerLabel = headerLabel
        self.title = title
        self.contextLabel = contextLabel
        self.badge = badge
        self.heroTint = heroTint
        self.isToday = isToday
        self.metrics = metrics
        self.skillNodes = skillNodes
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 6) {
                ForEach(metrics) { metric in
                    ProgramCommandMetric(metric: metric)
                }
            }

            if !skillNodes.isEmpty {
                ProgramSessionFocusRail(nodes: skillNodes)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(heroTint.opacity(isToday ? 0.58 : 0.24), lineWidth: 1)
        )
        .shadow(color: heroTint.opacity(isToday ? 0.18 : 0.08), radius: 18, y: 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(headerLabel)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(heroTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                ProgramDayStatusBadge(state: badge)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                Text(contextLabel)
                    .font(Font.unbound.monoS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.96))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.coachCyan.opacity(isToday ? 0.25 : 0.09),
                            Color.unbound.accent.opacity(isToday ? 0.16 : 0.06),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack {
                Rectangle()
                    .fill(heroTint.opacity(isToday ? 0.86 : 0.2))
                    .frame(height: 3)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

struct ProgramCommandMetricModel: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let foreground: Color?

    init(title: String, icon: String, tint: Color, foreground: Color? = nil) {
        self.id = "\(title)-\(icon)"
        self.title = title
        self.icon = icon
        self.tint = tint
        self.foreground = foreground
    }
}

enum ProgramDayBadgeState {
    case completed
    case rest
    case calibration
    case today
    case planned

    var title: String {
        switch self {
        case .completed: return "DONE"
        case .rest: return "REST"
        case .calibration: return "CAL"
        case .today: return "READY"
        case .planned: return "PLAN"
        }
    }

    var icon: String {
        switch self {
        case .completed: return "checkmark"
        case .rest: return "moon.zzz.fill"
        case .calibration: return "target"
        case .today: return "bolt.fill"
        case .planned: return "calendar"
        }
    }

    var tint: Color {
        switch self {
        case .completed: return Color.unbound.success
        case .rest: return Color.unbound.textPrimary.opacity(0.7)
        case .calibration: return Color.unbound.accent
        case .today: return Color.unbound.coachCyan
        case .planned: return Color.unbound.textPrimary.opacity(0.7)
        }
    }
}

private struct ProgramDayStatusBadge: View {
    let state: ProgramDayBadgeState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: state.icon)
                .font(.system(size: 11, weight: .bold))
            Text(state.title)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.1)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(state.tint.opacity(0.13)))
        .overlay(Capsule().strokeBorder(state.tint.opacity(0.28), lineWidth: 1))
    }
}

private struct ProgramCommandMetric: View {
    let metric: ProgramCommandMetricModel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: metric.icon)
                .font(.system(size: 10, weight: .bold))
            Text(metric.title.uppercased())
                .font(Font.unbound.monoS.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(metric.foreground ?? Color.unbound.textPrimary)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(Capsule().fill(metric.tint.opacity(0.18)))
        .overlay(Capsule().strokeBorder(metric.tint.opacity(0.4), lineWidth: 1))
    }
}

private struct ProgramSessionFocusRail: View {
    let nodes: [SkillNode]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(nodes, id: \.id) { node in
                    ProgramSkillFocusChip(node: node)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct ProgramSkillFocusChip: View {
    let node: SkillNode

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: node.glyph)
                .font(.system(size: 11, weight: .bold))
            Text(node.title.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Capsule().fill(Color.unbound.accent.opacity(0.16)))
        .overlay(Capsule().strokeBorder(Color.unbound.accent.opacity(0.34), lineWidth: 1))
    }
}
