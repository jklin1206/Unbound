import SwiftUI

// MARK: - RoutinePlayerView
//
// Full-screen workout player for side-quest routines.
// Two-stage loop: exercising → rest timer → exercising → …
//
// Active stage: exercise name, set counter, set-dot row, coaching cue,
//               rep stepper, LOG SET button, next-up preview.
// Rest stage:   full-screen rest timer with a draining circular ring,
//               skip and +30s affordances.
// Complete:     summary card with total time + sets + SP awarded.

struct SideQuestPlayerView: View {
    let routine: SideQuest
    let onComplete: (SideQuestLog?) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var services: ServiceContainer

    // Player state
    @State private var exerciseIndex = 0
    @State private var setIndex = 0
    @State private var isResting = false
    @State private var isComplete = false
    @State private var repsDone = 0
    @State private var setLogs: [SideQuestSetLog] = []
    @State private var elapsedSeconds = 0
    @State private var startedAt = Date()

    // Rest timer
    @State private var restSecondsRemaining = 0
    @State private var restTotal = 0

    // Timers
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    private var currentExercise: SideQuestExercise { routine.exercises[exerciseIndex] }
    private var currentSetNumber: Int { setIndex + 1 }

    private var nextUp: String? {
        let isLastSet = setIndex == currentExercise.sets - 1
        if isLastSet {
            let nextExIdx = exerciseIndex + 1
            guard nextExIdx < routine.exercises.count else { return nil }
            return routine.exercises[nextExIdx].name
        }
        return nil
    }

    private var categoryColor: Color {
        switch routine.category {
        case .circuit:  return Color.unbound.accent
        case .cardio:   return Color.unbound.coachCyan
        case .mobility: return Color.unbound.rankGreen
        case .activity: return Color.unbound.warnOrange
        }
    }

    private var elapsedLabel: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var restProgress: Double {
        guard restTotal > 0 else { return 1 }
        return Double(restSecondsRemaining) / Double(restTotal)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isComplete {
                completeView
            } else if isResting {
                restView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                exerciseView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isResting)
        .animation(.easeInOut(duration: 0.3), value: isComplete)
        .navigationBarHidden(true)
        .onAppear {
            startedAt = Date()
            repsDone = currentExercise.defaultRepCount
        }
        .onReceive(clock) { _ in
            elapsedSeconds += 1
            guard isResting else { return }
            if restSecondsRemaining <= 1 {
                endRest()
            } else {
                restSecondsRemaining -= 1
                if restSecondsRemaining <= 5 { UnboundHaptics.tick() }
            }
        }
    }

    // MARK: - Exercise view

    private var exerciseView: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    exerciseProgressBar
                    exerciseCard
                    repStepper
                    logButton
                    nextUpPreview
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(elapsedLabel)
                .font(Font.unbound.monoS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()

            Spacer()

            Text("\(routine.spReward) SP")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(categoryColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(categoryColor.opacity(0.15)))
                .overlay(Capsule().strokeBorder(categoryColor.opacity(0.35), lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: Exercise progress bar

    private var exerciseProgressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(routine.category.label) · \(routine.title.uppercased())")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(categoryColor)
                Spacer()
                Text("\(exerciseIndex + 1) OF \(routine.exercises.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.unbound.surface)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(categoryColor)
                        .frame(
                            width: geo.size.width * CGFloat(exerciseIndex + 1) / CGFloat(routine.exercises.count),
                            height: 3
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: exerciseIndex)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: Exercise card

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Name + set header
            VStack(alignment: .leading, spacing: 6) {
                Text(currentExercise.name.uppercased())
                    .font(Font.unbound.displayM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .id(currentExercise.id)

                HStack(spacing: 10) {
                    Text("SET \(currentSetNumber) OF \(currentExercise.sets)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(categoryColor)
                    Text("·")
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("\(currentExercise.reps) \(currentExercise.stepperLabel)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }

            // Set dots
            setDots

            // Coaching cue
            if let cue = currentExercise.cue {
                Text(cue)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                    .id(currentExercise.id + "-cue")
                    .contentTransition(.opacity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.10), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(categoryColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var setDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<currentExercise.sets, id: \.self) { i in
                Circle()
                    .fill(i < setIndex ? categoryColor : Color.unbound.surface)
                    .overlay(
                        Circle().strokeBorder(
                            i == setIndex ? categoryColor : Color.unbound.border.opacity(0.5),
                            lineWidth: i == setIndex ? 2 : 1
                        )
                    )
                    .frame(width: 11, height: 11)
                    .scaleEffect(i == setIndex ? 1.2 : 1.0)
                    .shadow(
                        color: i == setIndex ? categoryColor.opacity(0.6) : .clear,
                        radius: 4
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: setIndex)
            }
        }
    }

    // MARK: Rep stepper

    private var repStepper: some View {
        VStack(spacing: 10) {
            Text(currentExercise.stepperLabel)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)

            HStack(spacing: 0) {
                stepperButton(icon: "minus", action: { if repsDone > 0 { repsDone -= 1 } })

                Text(currentExercise.reps.uppercased() == "AMRAP" ? "\(repsDone)+" : "\(repsDone)")
                    .font(.system(size: 40, weight: .black, design: .default))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .frame(width: 100)
                    .contentTransition(.numericText(value: Double(repsDone)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: repsDone)

                stepperButton(icon: "plus", action: { repsDone += 1 })
            }
        }
    }

    private func stepperButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.tick()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.unbound.surface))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Log button

    private var logButton: some View {
        Button {
            UnboundHaptics.medium()
            logSet()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                Text("LOG SET")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.6)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(categoryColor)
            )
            .shadow(color: categoryColor.opacity(0.5), radius: 14, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Next-up preview

    @ViewBuilder
    private var nextUpPreview: some View {
        if let next = nextUp {
            HStack(spacing: 8) {
                Text("NEXT")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("·")
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(next.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
    }

    // MARK: - Rest view

    private var restView: some View {
        VStack(spacing: 0) {
            // Dismiss still available
            HStack {
                Button {
                    UnboundHaptics.soft()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.unbound.surface))
                        .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(elapsedLabel)
                    .font(Font.unbound.monoS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Rest timer ring
            ZStack {
                // Track
                Circle()
                    .strokeBorder(Color.unbound.surface, lineWidth: 10)
                    .frame(width: 220, height: 220)

                // Progress ring
                Circle()
                    .trim(from: 0, to: restProgress)
                    .stroke(
                        categoryColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: categoryColor.opacity(0.55), radius: 12)
                    .animation(.linear(duration: 1), value: restSecondsRemaining)

                // Center content
                VStack(spacing: 4) {
                    Text("\(restSecondsRemaining)")
                        .font(.system(size: 60, weight: .black, design: .default))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(restSecondsRemaining)))
                        .animation(.easeInOut(duration: 0.2), value: restSecondsRemaining)

                    Text("REST")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            Spacer().frame(height: 40)

            // Rest controls
            HStack(spacing: 20) {
                Button {
                    UnboundHaptics.medium()
                    restSecondsRemaining = min(restSecondsRemaining + 30, 300)
                    restTotal = max(restTotal, restSecondsRemaining)
                } label: {
                    Text("+30s")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    UnboundHaptics.heavy()
                    endRest()
                } label: {
                    HStack(spacing: 8) {
                        Text("SKIP")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(categoryColor)
                    )
                    .shadow(color: categoryColor.opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 20)

            // Next-set preview
            restNextPreview
                .padding(.horizontal, 28)

            Spacer().frame(height: 60)
        }
    }

    @ViewBuilder
    private var restNextPreview: some View {
        let isLastSet = setIndex == currentExercise.sets - 1
        let nextExIdx = exerciseIndex + (isLastSet ? 1 : 0)
        let nextSet = isLastSet ? 1 : setIndex + 2
        let nextExercise = !isLastSet
            ? currentExercise
            : (nextExIdx < routine.exercises.count ? routine.exercises[nextExIdx] : nil)

        if let ex = nextExercise {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(categoryColor)
                Text("SET \(nextSet) · \(ex.name.uppercased()) · \(ex.reps) \(ex.stepperLabel.uppercased())")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.unbound.surface)
            )
        }
    }

    // MARK: - Complete view

    private var completeView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(categoryColor)
                }
                .shadow(color: categoryColor.opacity(0.5), radius: 18)

                VStack(spacing: 6) {
                    Text("ROUTINE COMPLETE")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(2.0)
                        .foregroundStyle(categoryColor)
                    Text(routine.title.uppercased())
                        .font(Font.unbound.displayM)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                }

                // Stats row
                HStack(spacing: 0) {
                    statPill(value: elapsedLabel, label: "TIME")
                    Divider()
                        .frame(height: 32)
                        .background(Color.unbound.border)
                    statPill(value: "\(setLogs.count)", label: "SETS")
                    Divider()
                        .frame(height: 32)
                        .background(Color.unbound.border)
                    statPill(value: "+\(routine.spReward)", label: "SP")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(categoryColor.opacity(0.25), lineWidth: 1)
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                UnboundHaptics.heavy()
                onComplete(buildLog())
            } label: {
                HStack(spacing: 10) {
                    Text("RETURN HOME")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(categoryColor)
                )
                .shadow(color: categoryColor.opacity(0.5), radius: 14, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func logSet() {
        let log = SideQuestSetLog(
            id: UUID().uuidString,
            exerciseId: currentExercise.id,
            exerciseName: currentExercise.name,
            setNumber: currentSetNumber,
            completedReps: repsDone,
            completedAt: Date()
        )
        setLogs.append(log)

        let isLastExercise = exerciseIndex == routine.exercises.count - 1
        let isLastSet = setIndex == currentExercise.sets - 1

        if isLastExercise && isLastSet {
            withAnimation { isComplete = true }
            UnboundHaptics.success()
        } else if currentExercise.restSeconds > 0 {
            restTotal = currentExercise.restSeconds
            restSecondsRemaining = currentExercise.restSeconds
            withAnimation { isResting = true }
            UnboundHaptics.heavy()
        } else {
            // No rest configured — advance immediately
            advance()
        }
    }

    private func endRest() {
        withAnimation { isResting = false }
        UnboundHaptics.heavy()
        advance()
    }

    private func advance() {
        let isLastSet = setIndex == currentExercise.sets - 1
        if isLastSet {
            exerciseIndex += 1
            setIndex = 0
        } else {
            setIndex += 1
        }
        repsDone = currentExercise.defaultRepCount
    }

    private func buildLog() -> SideQuestLog {
        SideQuestLog(
            id: UUID().uuidString,
            userId: services.auth.currentUserId ?? "anonymous",
            questId: routine.id,
            startedAt: startedAt,
            completedAt: Date(),
            setLogs: setLogs,
            spAwarded: routine.spReward
        )
    }
}
