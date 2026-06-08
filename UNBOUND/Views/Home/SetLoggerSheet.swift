import SwiftUI

struct SetLoggerSheet: View {
    let prescription: TrainingPrescription?
    let existing: LoggedSet?
    let onSave: (LoggedSet) -> Void
    let onCancel: () -> Void

    // Inputs
    @State private var reps: Int = 0
    @State private var weightKg: Double = 0
    @State private var rpe: Int = 0    // 0 = unspecified
    @State private var holdSeconds: Int = 0
    @State private var qualityFlags: Set<PerformanceQualityFlag> = [.clean]
    @State private var setNotes: String = ""
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    // Hold timer state
    @State private var isTimerRunning: Bool = false
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                setWindowHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        setCombatHeader
                        primaryInput
                        weightInput
                        rpeInput
                        qualityInput
                        notesInput
                        Spacer().frame(height: 96)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                UnboundButton(
                    title: existing == nil ? "Log set" : "Update set",
                    icon: "checkmark"
                ) {
                    stopTimer()
                    let logged = LoggedSet(
                        reps: reps,
                        holdSeconds: isHoldTarget ? holdSeconds : nil,
                        weightKg: weightKg > 0 ? weightKg : nil,
                        rpe: rpe > 0 ? rpe : nil,
                        qualityFlags: qualityFlags,
                        notes: trimmedSetNotes
                    )
                    onSave(logged)
                }
                .accessibilityIdentifier("skillSession.logSet")

                Button {
                    stopTimer()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [Color.unbound.bg.opacity(0), Color.unbound.bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear { hydrate() }
        .onDisappear { stopTimer() }
    }

    private var setWindowHeader: some View {
        HStack(spacing: 12) {
            Button {
                stopTimer()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(existing == nil ? "LOG SET" : "EDIT SET")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Text(prescription?.exerciseName ?? "Training")
                    .font(Font.unbound.titleS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Color.unbound.bg
                .overlay(Rectangle().fill(Color.unbound.borderSubtle).frame(height: 0.5), alignment: .bottom)
        )
    }

    private var setCombatHeader: some View {
        let rest = prescription?.restSeconds ?? 90
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOG SET")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(prescription?.targetDescription.uppercased() ?? "LOG WHAT YOU HIT")
                        .font(Font.unbound.bodyLStrong)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(rest)s")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.coachCyan)
                        .monospacedDigit()
                    Text("REST")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            HStack(spacing: 8) {
                setStat(label: "TARGET", value: isHoldTarget ? "TIME" : "REPS")
                setStat(label: "LOAD", value: weightKg > 0 ? formatWeight(weightKg) : "BW")
                setStat(label: "EFFORT", value: rpe == 0 ? "OPEN" : "RPE \(rpe)")
                setStat(label: "QUALITY", value: qualityStatLabel)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.accent.opacity(0.16),
                                Color.unbound.coachCyan.opacity(0.07),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.24), lineWidth: 1)
        )
    }

    private func setStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Primary input — varies by target type

    @ViewBuilder
    private var primaryInput: some View {
        if let target = prescription?.target {
            switch target {
            case .hold:
                holdTimerInput
            case .amrap:
                repsInput(label: "REPS ACHIEVED")
            case .reps, .repsRange, .tempo:
                repsInput(label: "REPS")
            }
        } else {
            repsInput(label: "REPS")
        }
    }

    private var isHoldTarget: Bool {
        if case .hold = prescription?.target { return true }
        return false
    }

    private func repsInput(label: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 24) {
                roundIconButton(icon: "minus") {
                    if reps > 0 { reps -= 1; UnboundHaptics.soft() }
                }
                Text("\(reps)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(minWidth: 96)
                roundIconButton(icon: "plus") {
                    reps += 1; UnboundHaptics.soft()
                }
            }

            if case .tempo(let r, let e, let h, let c) = prescription?.target {
                Text("Tempo \(e)-\(h)-\(c) for \(r) reps")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private var holdTimerInput: some View {
        let targetSeconds: Int = {
            if case .hold(let s) = prescription?.target { return s }
            return 30
        }()
        let progress: Double = targetSeconds > 0
            ? min(1.0, Double(holdSeconds) / Double(targetSeconds))
            : 0
        let met = holdSeconds >= targetSeconds && targetSeconds > 0

        return VStack(spacing: 16) {
            Text("HOLD")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            ZStack {
                Circle()
                    .stroke(Color.unbound.surfaceElevated, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        met ? Color.unbound.impact : Color.unbound.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
                    .shadow(
                        color: (met ? Color.unbound.impact : Color.unbound.accent).opacity(0.45),
                        radius: 8
                    )

                VStack(spacing: 2) {
                    Text(formatTime(holdSeconds))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("/ \(targetSeconds)s")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }
            }
            .frame(width: 180, height: 180)

            HStack(spacing: 12) {
                Button(action: toggleTimer) {
                    HStack(spacing: 8) {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Start")
                    }
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                    .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(.headline).weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                        .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private var weightInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEIGHT (\(weightUnit.shortLabel.uppercased()))")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(weightKg > 0 ? formatWeight(weightKg) : "Bodyweight")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(weightKg > 0 ? Color.unbound.textPrimary : Color.unbound.textTertiary)
            }

            HStack(spacing: 8) {
                ForEach(weightChipValues, id: \.self) { value in
                    let chipWeightKg = kilograms(fromDisplayValue: value)
                    let isSelected = isSelectedWeightChip(chipWeightKg)
                    Button {
                        weightKg = chipWeightKg
                        UnboundHaptics.soft()
                    } label: {
                        Text(value == 0 ? "BW" : WeightPlatePolicy.formatLoggedWeightWithUnit(chipWeightKg, unit: weightUnit))
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.unbound.bg : Color.unbound.textSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isSelected ? Color.unbound.accent : Color.unbound.surfaceElevated)
                            )
                            .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var rpeInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RPE (EFFORT)")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(rpe == 0 ? "Optional" : "\(rpe) / 10")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(rpe == 0 ? Color.unbound.textTertiary : Color.unbound.textPrimary)
            }

            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { v in
                    Button {
                        rpe = (rpe == v) ? 0 : v
                        UnboundHaptics.soft()
                    } label: {
                        Text("\(v)")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .foregroundStyle(rpe == v ? Color.unbound.bg : Color.unbound.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(rpe == v ? Color.unbound.accent : Color.unbound.surfaceElevated))
                            .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var qualityInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("QUALITY")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(qualityStatLabel)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(qualityHasWarning ? Color.unbound.alert : Color.unbound.textPrimary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                qualityChip(.clean, label: "Clean", icon: "checkmark.seal.fill")
                qualityChip(.assisted, label: "Assisted", icon: "lifepreserver.fill")
                qualityChip(.formBreak, label: "Form", icon: "exclamationmark.triangle.fill")
                qualityChip(.partialRange, label: "Partial", icon: "arrow.left.and.right")
                qualityChip(.pain, label: "Pain", icon: "heart.slash.fill")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var notesInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            TextField("Band, wall, finger assist...", text: $setNotes, axis: .vertical)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2...4)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.bg.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private func qualityChip(
        _ flag: PerformanceQualityFlag,
        label: String,
        icon: String
    ) -> some View {
        let isOn = qualityFlags.contains(flag)
        let color = qualityWarningFlags.contains(flag) ? Color.unbound.alert : Color.unbound.accent
        return Button {
            toggleQuality(flag)
            UnboundHaptics.soft()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isOn ? Color.unbound.bg : Color.unbound.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(isOn ? color : Color.unbound.surfaceElevated)
            )
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hydration

    private func hydrate() {
        if let existing {
            reps = existing.reps
            weightKg = existing.weightKg ?? 0
            rpe = existing.rpe ?? 0
            holdSeconds = existing.holdSeconds ?? 0
            qualityFlags = existing.effectiveQualityFlags.isEmpty ? [.clean] : existing.effectiveQualityFlags
            setNotes = existing.notes ?? ""
            return
        }
        // Defaults from prescription target
        guard let target = prescription?.target else { return }
        switch target {
        case .reps(let n):
            reps = n
        case .repsRange(let lo, let hi):
            reps = (lo + hi) / 2
        case .amrap:
            reps = 0
        case .hold:
            holdSeconds = 0
        case .tempo(let r, _, _, _):
            reps = r
        }
    }

    // MARK: - Hold timer

    private func toggleTimer() {
        if isTimerRunning { stopTimer() } else { startTimer() }
    }

    private func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        UnboundHaptics.medium()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                holdSeconds += 1
            }
        }
    }

    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func resetTimer() {
        stopTimer()
        holdSeconds = 0
    }

    // MARK: - Quality

    private var qualityProofBlockingFlags: Set<PerformanceQualityFlag> {
        [.assisted, .formBreak, .partialRange, .pain]
    }

    private var qualityWarningFlags: Set<PerformanceQualityFlag> {
        [.formBreak, .partialRange, .pain]
    }

    private var qualityHasWarning: Bool {
        !qualityFlags.intersection(qualityWarningFlags).isEmpty
    }

    private var qualityStatLabel: String {
        if qualityHasWarning { return "REVIEW" }
        if qualityFlags.contains(.assisted) { return "ASSIST" }
        return "CLEAN"
    }

    private var trimmedSetNotes: String? {
        setNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func toggleQuality(_ flag: PerformanceQualityFlag) {
        if qualityFlags.contains(flag) {
            qualityFlags.remove(flag)
            if qualityFlags.isEmpty {
                qualityFlags.insert(.clean)
            }
            return
        }

        qualityFlags.insert(flag)
        if flag == .clean {
            qualityFlags.subtract(qualityProofBlockingFlags)
        } else if qualityProofBlockingFlags.contains(flag) {
            qualityFlags.remove(.clean)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private var weightChipValues: [Double] {
        switch weightUnit {
        case .kilograms:
            return [0.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0]
        case .pounds:
            return [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 35.0, 45.0]
        }
    }

    private func kilograms(fromDisplayValue value: Double) -> Double {
        value > 0 ? WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: weightUnit) : 0
    }

    private func isSelectedWeightChip(_ kilograms: Double) -> Bool {
        abs(weightKg - kilograms) < 0.01
    }

    private func formatWeight(_ kg: Double) -> String {
        WeightPlatePolicy.formatLoggedWeightWithUnit(kg, unit: weightUnit)
    }

    private func roundIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.unbound.surfaceElevated))
                .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var roundedCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }
}
