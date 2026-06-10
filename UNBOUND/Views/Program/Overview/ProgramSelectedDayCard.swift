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

            if !metrics.isEmpty {
                MetaLine(metrics.map(\.title))
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
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
                Spacer(minLength: 0)
                ProgramDayStatusBadge(state: badge)
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
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(spacing: 5) {
            Image(systemName: state.icon)
                .font(.system(size: 10, weight: .bold))
            Text(state.title)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.1)
        }
        .foregroundStyle(state.tint)
    }
}
