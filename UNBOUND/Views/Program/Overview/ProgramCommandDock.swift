import SwiftUI

struct ProgramCommandDock: View {
    struct SetupTile {
        let title: String
        let icon: String
        let tint: Color
        let badge: String?
        let isLoading: Bool

        static func resolve(
            style: TrainingStyle,
            equipment: [Equipment],
            activeContext: ProgramTrainingContextOverride?,
            pendingContext: ProgramTrainingContextOverride?,
            isLoading: Bool
        ) -> SetupTile {
            // Setup/navigation tier reads cyan (paired with Plan); the icon still
            // hints the active style, the label stays a fixed "Setup".
            return SetupTile(
                title: "Setup",
                icon: trainingStyleIcon(style),
                tint: Color.unbound.coachCyan,
                badge: contextDockBadge(
                    activeContext: activeContext,
                    pendingContext: pendingContext
                ),
                isLoading: isLoading
            )
        }

        private static func trainingStyleIcon(_ style: TrainingStyle) -> String {
            switch style {
            case .bodyweight: return "figure.strengthtraining.functional"
            case .freeWeights: return "dumbbell.fill"
            case .hybrid: return "arrow.triangle.2.circlepath"
            case .machines: return "cable.connector"
            }
        }

        private static func contextDockBadge(
            activeContext: ProgramTrainingContextOverride?,
            pendingContext: ProgramTrainingContextOverride?
        ) -> String {
            let active: String? = activeContext.map { context in
                context.selection.scope == .thisWeek ? "WEEK" : "TODAY"
            }
            if let active, pendingContext != nil { return "\(active)+NEXT" }
            if let active { return active }
            if pendingContext != nil { return "NEXT" }
            return "BASE"
        }

    }

    let setupTile: SetupTile
    let onPlan: () -> Void
    let onChangeSetup: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            commandTile(
                title: "Plan",
                icon: "calendar",
                tint: Color.unbound.coachCyan,
                action: onPlan
            )
                .accessibilityLabel("Plan calendar")
                .accessibilityIdentifier("program.monthPlanner.open")

            commandTile(
                title: setupTile.title,
                icon: setupTile.isLoading ? "arrow.triangle.2.circlepath" : setupTile.icon,
                tint: setupTile.tint,
                accessory: setupTile.badge == "BASE" ? nil : setupTile.badge,
                action: onChangeSetup
            )
                .disabled(setupTile.isLoading)
                .accessibilityLabel("Training setup")
                .accessibilityIdentifier("program.focusSwitch")
        }
        .accessibilityIdentifier("program.controls")
    }

    private func commandTile(
        title: String,
        icon: String,
        tint: Color,
        accessory: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)

                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let accessory {
                    Text(accessory)
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
