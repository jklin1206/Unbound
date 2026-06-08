import SwiftUI

#if DEBUG
struct ProgramDevDaySimulatorCard: View {
    let offsetLabel: String
    let dateLabel: String
    let onPrevious: () -> Void
    let onReset: () -> Void
    let onNext: () -> Void
    let onPlus7: () -> Void
    let onPlus14: () -> Void
    let onPlus28: () -> Void
    let onEnd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Text("SIM")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.accent)

                Text(offsetLabel)
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)

                Text(dateLabel)
                    .font(Font.unbound.captionS)
                    .tracking(0.5)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.58))

                devDayButton(systemName: "chevron.left", identifier: "program.devDaySim.previous", action: onPrevious)
                Button(action: onReset) {
                    Text("RESET")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.9)
                        .foregroundStyle(Color.unbound.textPrimary.opacity(0.72))
                        .frame(height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("program.devDaySim.reset")
                devDayButton(systemName: "chevron.right", identifier: "program.devDaySim.next", action: onNext)

                devJumpButton("+7", identifier: "program.devDaySim.plus7", action: onPlus7)
                devJumpButton("+14", identifier: "program.devDaySim.plus14", action: onPlus14)
                devJumpButton("+28", identifier: "program.devDaySim.plus28", action: onPlus28)
                devJumpButton("END", identifier: "program.devDaySim.end", action: onEnd)
            }
            .padding(.horizontal, 1)
        }
        .frame(height: 34)
        .accessibilityIdentifier("program.devDaySim")
    }

    private func devDayButton(
        systemName: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 28, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func devJumpButton(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.82))
                .frame(width: 42, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

struct ProgramDevDynamicScenarioRail: View {
    let scenarios: [DevDynamicProgramScenario]
    let activeRawValue: String
    let isFreshMode: Bool
    let isSeeding: Bool
    let onSelect: (DevDynamicProgramScenario) -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("SIM CASE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.coachCyan)
                if isSeeding {
                    ProgressView()
                        .tint(Color.unbound.coachCyan)
                        .scaleEffect(0.72)
                }
            }

            if isFreshMode {
                freshModeChip
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(scenarios) { scenario in
                        scenarioChip(scenario)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .frame(height: 36)
        .accessibilityIdentifier("program.devDynamicScenarioRail")
    }

    private var freshModeChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 10, weight: .bold))
            Text("FRESH")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.7)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            Capsule()
                .fill(Color.unbound.coachCyan.opacity(0.18))
        )
        .contentShape(Capsule())
    }

    private func scenarioChip(_ scenario: DevDynamicProgramScenario) -> some View {
        let isActive = activeRawValue == scenario.rawValue
        return Button {
            onSelect(scenario)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: scenario.systemImage)
                    .font(.system(size: 10, weight: .bold))
                Text(scenario.shortTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textPrimary.opacity(0.68))
            .padding(.horizontal, isActive ? 10 : 4)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(isActive ? Color.unbound.coachCyan.opacity(0.18) : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isSeeding)
        .accessibilityIdentifier("program.devDynamicScenario.\(scenario.rawValue)")
    }
}
#endif
