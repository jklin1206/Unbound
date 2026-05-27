import SwiftUI

struct CheckpointFlowSheet: View {
    let nutritionContext: NutritionContext
    let missedSessionSignal: MissedSessionSignal
    let onCaptureBodyScan: () -> Void
    let onCommit: (CheckpointOutcome) -> Void
    let onDismiss: () -> Void

    @State private var flow = CheckpointFlow()
    @State private var attemptedStandards = 0
    @State private var clearedStandards = 0
    @State private var painFlagged = false
    @State private var formBreakdownFlagged = false
    @State private var freeText = ""
    @State private var isSummarizing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        stepHeader
                        stepBody
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Checkpoint")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(stepEyebrow)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.7)
                .foregroundStyle(Color.unbound.coachCyan)
            Text(stepTitle)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(stepCopy)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch flow.step {
        case .entry:
            entryStep
        case .bodyCapture:
            bodyCaptureStep
        case .standardsCheck:
            standardsStep
        case .freeText:
            freeTextStep
        case .nutritionCheck:
            nutritionStep
        case .summarizing:
            summarizingStep
        case .review(let signals):
            reviewStep(signals)
        case .commit:
            committedStep
        case .cancelled:
            cancelledStep
        }
    }

    private var entryStep: some View {
        VStack(spacing: 10) {
            primaryButton("START CHECKPOINT", systemImage: "flag.checkered") {
                flow.begin()
            }
            secondaryButton("SKIP AND CONTINUE ARC", systemImage: "arrow.forward.circle") {
                flow.skip()
                onCommit(.skipped)
            }
        }
    }

    private var bodyCaptureStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoCard(
                icon: "camera.viewfinder",
                title: "Body Scan",
                detail: "Capture a fresh scan if you want visual progress included. You can keep going without one."
            )
            primaryButton("CAPTURE BODY SCAN", systemImage: "camera.fill") {
                onCaptureBodyScan()
                flow.advance()
            }
            secondaryButton("USE LATEST / SKIP PHOTO", systemImage: "checkmark.circle") {
                flow.advance()
            }
        }
    }

    private var standardsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            counterRow(
                title: "Standards attempted",
                value: $attemptedStandards,
                range: 0...12
            )
            counterRow(
                title: "Standards cleared",
                value: $clearedStandards,
                range: 0...attemptedStandards
            )
            toggleRow(title: "Pain showed up", isOn: $painFlagged)
            toggleRow(title: "Form broke down", isOn: $formBreakdownFlagged)
            primaryButton("CONTINUE", systemImage: "arrow.right") {
                let check = CheckpointStandardsCheck(
                    attemptedCount: attemptedStandards,
                    clearedCount: clearedStandards,
                    painFlagged: painFlagged,
                    formBreakdownFlagged: formBreakdownFlagged
                )
                flow.setStandardsCheck(check)
                flow.advance()
            }
        }
    }

    private var freeTextStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $freeText)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
                .accessibilityIdentifier("checkpoint.freeText")

            quickNoteGrid

            primaryButton("CONTINUE", systemImage: "arrow.right") {
                flow.setFreeText(freeText)
                flow.advance()
            }
        }
    }

    private var quickNoteGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
            ForEach(["Fresh", "Sore", "Pull felt weak", "Legs improved", "Shoulder pain", "Want handstand"], id: \.self) { note in
                Button {
                    appendNote(note)
                } label: {
                    Text(note.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.unbound.surface))
                        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nutritionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoCard(
                icon: "fork.knife",
                title: "Protein",
                detail: nutritionContext.protein.displayText
            )
            infoCard(
                icon: "drop.fill",
                title: "Hydration",
                detail: nutritionContext.hydration.displayText
            )
            if let fuel = nutritionContext.trainingFuel {
                infoCard(
                    icon: "bolt.fill",
                    title: "Training fuel",
                    detail: fuel.displayText
                )
            }
            primaryButton("REVIEW CHECKPOINT", systemImage: "doc.text.magnifyingglass") {
                flow.setNutrition(nutritionContext)
                flow.advance()
                summarize()
            }
        }
    }

    private var summarizingStep: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.unbound.accent)
            Text(isSummarizing ? "Building your Arc recap..." : "Checkpoint ready.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func reviewStep(_ signals: CheckpointSignals) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            infoCard(
                icon: "quote.bubble.fill",
                title: "Arc recap",
                detail: signals.freeTextSummary ?? "Checkpoint saved. Next Arc will stay conservative."
            )

            VStack(alignment: .leading, spacing: 10) {
                signalRow("Load pressure", loadBiasText(signals.loadAdjustmentBias))
                signalRow("Recovery", recoveryText(signals.recoveryStateHint))
                signalRow("Weak regions", regionText(signals.weakRegions))
                signalRow("Skill focus", skillText(signals.skillFocusHints))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )

            primaryButton("APPLY NEXT ARC", systemImage: "checkmark.seal.fill") {
                flow.commitReviewedSignals()
                onCommit(.completed(signals))
            }
            secondaryButton("SKIP INSTEAD", systemImage: "arrow.forward.circle") {
                flow.skip()
                onCommit(.skipped)
            }
        }
    }

    private var committedStep: some View {
        infoCard(
            icon: "checkmark.seal.fill",
            title: "Checkpoint saved",
            detail: "Your next Arc has the validated checkpoint signals attached."
        )
    }

    private var cancelledStep: some View {
        infoCard(
            icon: "xmark.circle",
            title: "Checkpoint cancelled",
            detail: "Nothing changed."
        )
    }

    private func counterRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("\(value.wrappedValue)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            Spacer()
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .tint(Color.unbound.accent)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private func infoCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.coachCyan)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.coachCyan.opacity(0.13)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func signalRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            Text(value)
                .font(Font.unbound.captionS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.soft()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(Font.unbound.bodyMStrong)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.soft()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func summarize() {
        guard !isSummarizing else { return }
        isSummarizing = true
        Task {
            let result = await CheckpointSummarizer().summarize(
                CheckpointSummaryInput(
                    freeText: flow.freeText,
                    standardsCheck: flow.standardsCheck,
                    nutrition: flow.nutrition,
                    missedSessionSignal: missedSessionSignal
                )
            )
            await MainActor.run {
                isSummarizing = false
                flow.presentReview(signals: result.signals)
            }
        }
    }

    private func appendNote(_ note: String) {
        if freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            freeText = note
        } else {
            freeText += "\n\(note)"
        }
    }

    private var stepEyebrow: String {
        switch flow.step {
        case .entry: return "END OF ARC"
        case .bodyCapture: return "BODY CAPTURE"
        case .standardsCheck: return "STANDARD CHECK"
        case .freeText: return "RECAP NOTE"
        case .nutritionCheck: return "TRAINING SUPPORT"
        case .summarizing: return "RECAP"
        case .review: return "REVIEW"
        case .commit: return "SAVED"
        case .cancelled: return "CANCELLED"
        }
    }

    private var stepTitle: String {
        switch flow.step {
        case .entry: return "Checkpoint before the next Arc."
        case .bodyCapture: return "Add a scan if you want visual proof."
        case .standardsCheck: return "Log what standards were tested."
        case .freeText: return "Add a note for your recap."
        case .nutritionCheck: return "Keep training fuel simple."
        case .summarizing: return "Writing your Arc recap."
        case .review: return "Review before anything applies."
        case .commit: return "Checkpoint saved."
        case .cancelled: return "Checkpoint cancelled."
        }
    }

    private var stepCopy: String {
        switch flow.step {
        case .entry:
            return "This is optional, but it gives the next Arc better context. Training decisions still run through deterministic rules."
        case .bodyCapture:
            return "The photo is evidence, not the coach. You can skip it and continue from workout logs."
        case .standardsCheck:
            return "This helps decide whether the next Arc should push, hold, or soften pressure."
        case .freeText:
            return "Use plain language if you want color in the recap. Training changes come from the checked inputs and validated logs."
        case .nutritionCheck:
            return "No calories or meal policing. Just protein, hydration, and light fuel context."
        case .summarizing:
            return "The recap can use your note, but next-Arc signals stay deterministic."
        case .review:
            return "Nothing changes silently. Apply this review or skip and keep the current structure."
        case .commit:
            return "Done."
        case .cancelled:
            return "Nothing changed."
        }
    }

    private func loadBiasText(_ bias: Double?) -> String {
        guard let bias else { return "Neutral" }
        if bias > 0.05 { return "Slight push" }
        if bias < -0.05 { return "Softer" }
        return "Neutral"
    }

    private func recoveryText(_ state: RecoveryState?) -> String {
        switch state {
        case .wellRecovered: return "Fresh"
        case .normal: return "Normal"
        case .accumulated: return "Accumulated fatigue"
        case .flagged: return "Flagged"
        case .none: return "No signal"
        }
    }

    private func regionText(_ regions: [BodyRegion]) -> String {
        regions.isEmpty ? "None" : regions.map(\.displayName).joined(separator: ", ")
    }

    private func skillText(_ ids: [String]) -> String {
        guard !ids.isEmpty else { return "None" }
        return ids.map { id in
            SkillGraph.shared.node(id: id)?.title ?? id
        }
        .joined(separator: ", ")
    }
}
