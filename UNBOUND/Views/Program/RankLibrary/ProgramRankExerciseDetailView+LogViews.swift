import SwiftUI
import UIKit

extension ProgramRankExerciseDetailView {

    func singleLogCard(_ definition: MovementDefinition) -> some View {
        detailSection(title: "LOG A SET") {
            VStack(alignment: .leading, spacing: 14) {
                switch logMode {
                case .oneRepMax:
                    oneRepMaxRail(definition)
                    proofHistoryGraph
                case .reps:
                    repsRail(limit: 80)
                    proofHistoryGraph
                case .hold:
                    secondsRail(title: "Hold Time")
                    proofHistoryGraph
                }

                rankLogActionButton
            }
        }
    }

    var rankLogActionButton: some View {
        let isEnabled = canSubmit && !isSubmitting

        return Button {
            guard isEnabled else { return }
            UnboundHaptics.medium()
            Task { await submitLog() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSubmitting ? "hourglass" : "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text(isSubmitting ? "Saving Attempt" : "Reveal Rank")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isEnabled ? tint.opacity(0.72) : Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isEnabled ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("program.rankExerciseDetail.logResult")
    }

    var proofHistoryGraph: some View {
        ProgramRankProofHistoryLineGraph(
            entries: history,
            currentValue: currentProofGraphValue,
            historyValue: proofGraphValue(for:),
            valueFormatter: proofGraphValueText(_:),
            selectedRange: $selectedRepGraphRange,
            tint: tint,
            accessibilityUnit: logMode.accessibilityUnit
        )
    }

    var currentProofGraphValue: Double {
        switch logMode {
        case .oneRepMax:
            return max(selectedWeightDisplay, 0)
        case .reps:
            return Double(max(selectedReps, 1))
        case .hold:
            return Double(max(selectedSeconds, 1))
        }
    }

    func proofGraphValue(for entry: ProgramRankExerciseHistoryEntry) -> Double? {
        switch logMode {
        case .oneRepMax:
            guard let oneRepMaxKg = entry.oneRepMaxKg else { return nil }
            return weightUnit.displayValue(fromKilograms: oneRepMaxKg)
        case .reps:
            return entry.reps.map(Double.init)
        case .hold:
            return entry.holdSeconds.map(Double.init)
        }
    }

    func proofGraphValueText(_ value: Double) -> String {
        switch logMode {
        case .oneRepMax:
            return "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
        case .reps:
            return "\(Int(value.rounded()))"
        case .hold:
            return ProgramRankExerciseFormatter.seconds(Int(value.rounded()))
        }
    }

    @ViewBuilder
    func guideLayer(_ definition: MovementDefinition) -> some View {
        if let skillForm = skillFormGuide(for: definition) {
            detailSection(title: "SKILL FORM") {
                FormPhaseSlideshow(
                    phases: skillForm.phases,
                    skillTitle: skillForm.title
                )
            }
        } else {
            SkillGuideLayerView(
                layer: .rankExercise(definition: definition),
                tint: tint,
                isProminent: true
            )
        }
    }

    func skillFormGuide(for definition: MovementDefinition) -> (title: String, phases: [FormPhase])? {
        guard let skillId = definition.skillId else { return nil }
        let node = SkillGraph.shared.node(id: skillId)
        let phases = FormPhaseLibrary.phases(
            for: skillId,
            fallbackTitle: node?.title ?? definition.displayName,
            formCues: node?.formCues ?? []
        )
        guard !phases.isEmpty else { return nil }
        return (node?.title ?? definition.displayName, phases)
    }

    var historyCard: some View {
        detailSection(title: "PAST HISTORY", subtitle: "Recent attempts for this rank standard") {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.unbound.accent)
                    Text("Loading history")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if history.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("No attempts yet. Reveal one result and it will appear here.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(history) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
    }

    var missingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Movement not found")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("This rank standard no longer maps to a catalog exercise.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    func summaryTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(cardBackground(cornerRadius: 12, tint: tint.opacity(0.16)))
    }

    func oneRepMaxRail(_ definition: MovementDefinition) -> some View {
        let config = weightRulerConfig(allowsBodyweight: definition.rankTemplate == .weightedBodyweight)
        let tick = Binding<Int>(
            get: { config.tick(for: selectedWeightDisplay) },
            set: { selectedWeightDisplay = config.value(for: $0) }
        )
        let isAddedLoad = definition.rankTemplate == .weightedBodyweight
        let title = isAddedLoad ? "Added 1RM" : "1RM"
        let value = isAddedLoad ? addedLoadSummary : formatDisplayWeight(selectedWeightDisplay)

        return ProgramRankMetricRuler(
            title: title,
            valueText: value,
            range: config.range,
            value: tick,
            format: { config.formatValue($0, using: weightUnit, isAddedLoad: isAddedLoad) },
            tickLabel: { config.tickLabel($0) },
            majorEvery: config.majorEvery,
            tickSpacing: 13
        )
    }

    func repsRail(limit: Int) -> some View {
        ProgramRankMetricRuler(
            title: "Reps",
            valueText: "\(selectedReps)",
            range: 1...limit,
            value: $selectedReps,
            unitLabel: "REPS",
            format: { "\($0)" },
            tickLabel: { "\($0)" },
            majorEvery: limit > 40 ? 10 : 5,
            tickSpacing: 15
        )
    }

    func secondsRail(title: String) -> some View {
        let step = 5
        let maxTick = 1_200 / step
        let tick = Binding<Int>(
            get: { min(max(Int((Double(selectedSeconds) / Double(step)).rounded()), 1), maxTick) },
            set: { selectedSeconds = max(1, min($0, maxTick)) * step }
        )
        let majorEvery = title == "Hold Time" ? 6 : 12

        return ProgramRankMetricRuler(
            title: title,
            valueText: ProgramRankExerciseFormatter.seconds(selectedSeconds),
            range: 1...maxTick,
            value: tick,
            format: { ProgramRankExerciseFormatter.seconds($0 * step) },
            tickLabel: { ProgramRankExerciseFormatter.seconds($0 * step) },
            majorEvery: majorEvery,
            tickSpacing: 12
        )
    }

    var addedLoadSummary: String {
        selectedWeightDisplay > 0 ? "+\(formatDisplayWeight(selectedWeightDisplay))" : "Bodyweight only"
    }

    func detailSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Font.unbound.bodyS.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func cardBackground(cornerRadius: CGFloat, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tint, lineWidth: 1)
        }
    }

    func historyRow(_ entry: ProgramRankExerciseHistoryEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.dateText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}
