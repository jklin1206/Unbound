import SwiftUI

struct ProgramSelectedDayCard<Content: View>: View {
    let headerLabel: String
    let title: String
    let contextLabel: String
    let badge: ProgramDayBadgeState
    let heroTint: Color
    let metrics: [ProgramCommandMetricModel]
    let skillNodes: [SkillNode]
    let fuelText: String?
    let content: Content

    init(
        headerLabel: String,
        title: String,
        contextLabel: String,
        badge: ProgramDayBadgeState,
        heroTint: Color,
        metrics: [ProgramCommandMetricModel],
        skillNodes: [SkillNode],
        fuelText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.headerLabel = headerLabel
        self.title = title
        self.contextLabel = contextLabel
        self.badge = badge
        self.heroTint = heroTint
        self.metrics = metrics
        self.skillNodes = skillNodes
        self.fuelText = fuelText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            MetaLine(metrics.map { $0.title } + [fuelText].compactMap { $0 })

            if !skillNodes.isEmpty {
                MetaLine(skillNodes.map { $0.title }, emphasized: false)
            }

            Divider().overlay(Color.unbound.border)

            content
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                HStack(spacing: 5) {
                    Image(systemName: badge.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(badge.title)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                }
                .foregroundStyle(badge.tint)
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

}

struct ProgramCommandMetricModel: Identifiable {
    let id: String
    let title: String

    init(title: String) {
        self.id = title
        self.title = title
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

