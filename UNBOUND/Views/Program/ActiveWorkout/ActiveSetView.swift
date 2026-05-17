import SwiftUI

struct ActiveSetView: View {
    let exerciseName: String
    let setNumber: Int
    let totalSets: Int
    let ghost: SetPrefill.Ghost?
    let isWarmup: Bool
    let isFinalSet: Bool
    let exerciseCount: Int
    let currentExerciseIndex: Int
    let completedExerciseIndices: Set<Int>
    let elapsedSeconds: Int

    @Binding var weight: Double
    @Binding var reps: Double
    @State private var pressed = false
    @State private var bloom = false
    @State private var loggedThisSet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onLogSet: () -> Void
    let onPickEffort: (Effort) -> Void
    let onJumpExercise: (Int) -> Void
    let onIntent: (OverflowIntent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exerciseName)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(setLine)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer()
                ExerciseOverflowMenu(isWarmup: isWarmup, onIntent: onIntent)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            HStack(spacing: 12) {
                StepperControl(label: "Weight", value: $weight, step: 2.5,
                               unit: "kg", allowsDecimal: true)
                StepperControl(label: "Reps", value: $reps, step: 1,
                               unit: nil, allowsDecimal: false)
            }
            .padding(.horizontal, 16)

            if loggedThisSet {
                HStack(spacing: 8) {
                    ForEach(Effort.allCases, id: \.self) { e in
                        Button {
                            onPickEffort(e)
                            UnboundHaptics.soft()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                loggedThisSet = false
                            }
                        } label: {
                            Text(e.label)
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.unbound.surfaceElevated))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.unbound.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .transition(reduceMotion ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            Button {
                UnboundHaptics.success()
                bloom = true
                onLogSet()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    loggedThisSet = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bloom = false }
            } label: {
                Text(isFinalSet ? "FINISH" : "LOG SET")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.unbound.accent)
                            .shadow(color: Color.unbound.accent.opacity(bloom ? 0.6 : 0.0),
                                    radius: bloom ? 24 : 0)
                    )
            }
            .buttonStyle(.plain)
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1.0)
            .onLongPressGesture(minimumDuration: 0, pressing: { p in
                pressed = p
                if p { UnboundHaptics.soft() }
            }, perform: {})
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            ExerciseDotNavigator(
                exerciseCount: exerciseCount,
                currentIndex: currentExerciseIndex,
                completedIndices: completedExerciseIndices,
                elapsedSeconds: elapsedSeconds,
                onJump: onJumpExercise
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private var setLine: String {
        var s = "SET \(setNumber) OF \(totalSets)"
        if let g = ghost {
            let w = g.weightKg.map { $0.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int($0)) : String(format: "%.1f", $0) } ?? "—"
            let r = g.reps.map(String.init) ?? "—"
            s += "    PREV \(w)kg × \(r)"
        }
        if isWarmup { s += "    · WARMUP" }
        return s
    }
}
