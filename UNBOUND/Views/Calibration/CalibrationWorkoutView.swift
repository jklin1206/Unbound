import SwiftUI

struct CalibrationWorkoutView: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    let onComplete: () -> Void

    @State private var entries: [CalibrationEntry] = []
    @State private var equipment: Set<Equipment> = [.bodyweight]
    @State private var isSaving = false
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .smoky, intensity: 0.85)
                .ignoresSafeArea()
            TechGridBackground(opacity: 0.22)
                .ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Color.unbound.accent)
            } else {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            headerCopy
                            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                                CalibrationEntryCard(
                                    index: idx,
                                    entry: Binding(
                                        get: { entries[idx] },
                                        set: { entries[idx] = $0 }
                                    )
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }

                    HUDButton(
                        title: isSaving ? "Locking..." : "Complete session",
                        icon: "checkmark",
                        isEnabled: canComplete && !isSaving,
                        isLoading: isSaving,
                        action: complete
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .task { await bootstrap() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        ChamferedRectangle(inset: 4)
                            .stroke(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text("DAY 1 · CALIBRATION")
                .font(Font.unbound.monoS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.accent)

            Spacer(minLength: 0)
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCK THE BASELINE")
                .font(Font.unbound.titleL)
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: Color.unbound.accent.opacity(0.3), radius: 14)
            Text("Warm up, then an AMRAP set per lift. Log what happened.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    private var canComplete: Bool {
        entries.allSatisfy { $0.logged }
    }

    // MARK: Bootstrap

    @MainActor
    private func bootstrap() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        if let profile = try? await services.user.fetchProfile(userId: userId) {
            equipment = Set(profile.equipment ?? [.bodyweight])
        }
        entries = buildEntries(userId: userId)
        isLoading = false
    }

    private func buildEntries(userId: String) -> [CalibrationEntry] {
        let useCalisthenic = equipment == [.bodyweight]
        if useCalisthenic {
            return [
                CalibrationEntry(userId: userId, exerciseKey: "pushup", name: "Pushup", kind: .reps),
                CalibrationEntry(userId: userId, exerciseKey: "pullup", name: "Pullup", kind: .reps),
                CalibrationEntry(userId: userId, exerciseKey: "dip", name: "Dip", kind: .reps),
                CalibrationEntry(userId: userId, exerciseKey: "pistol squat", name: "Pistol Squat", kind: .reps)
            ]
        }
        return [
            CalibrationEntry(userId: userId, exerciseKey: "back squat", name: "Barbell Squat", kind: .weight),
            CalibrationEntry(userId: userId, exerciseKey: "bench press", name: "Bench Press", kind: .weight),
            CalibrationEntry(userId: userId, exerciseKey: "deadlift", name: "Deadlift", kind: .weight),
            CalibrationEntry(userId: userId, exerciseKey: "overhead press", name: "Overhead Press", kind: .weight)
        ]
    }

    // MARK: Complete

    private func complete() {
        isSaving = true
        Task {
            let userId = services.auth.currentUserId ?? "anonymous"
            let baselines = entries.map { entry in
                CalibrationBaseline(
                    userId: userId,
                    exerciseKey: entry.exerciseKey,
                    displayName: entry.name,
                    kind: entry.kind,
                    value: entry.workValue,
                    unit: entry.kind == .weight ? "kg" : "reps",
                    isKnown: true
                )
            }
            try? await services.calibration.save(baselines, userId: userId)
            await MainActor.run {
                UnboundHaptics.success()
                isSaving = false
                onComplete()
                dismiss()
            }
        }
    }
}

struct CalibrationEntry: Identifiable {
    let id = UUID()
    let userId: String
    let exerciseKey: String
    let name: String
    let kind: CalibrationBaseline.Kind

    var warmupReps: Int = 8
    var workReps: Int = 0
    var workWeight: Double = 0
    var rpe: Int = 8
    var logged: Bool = false

    var workValue: Double {
        switch kind {
        case .weight: return workWeight
        case .reps:   return Double(workReps)
        }
    }
}

private struct CalibrationEntryCard: View {
    let index: Int
    @Binding var entry: CalibrationEntry

    var body: some View {
        HUDPanel(isActive: entry.logged, pulse: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(Font.unbound.monoS)
                        .tracking(1.4)
                        .foregroundStyle(entry.logged ? Color.unbound.accent : Color.unbound.textTertiary)
                        .frame(width: 28, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(hintText)
                            .font(Font.unbound.monoS)
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Spacer()
                }

                if entry.kind == .weight {
                    HStack(spacing: 10) {
                        stepperField(label: "WORK KG", value: $entry.workWeight, step: 2.5, min: 0, max: 400)
                        stepperField(label: "REPS", intValue: $entry.workReps, min: 0, max: 30)
                    }
                } else {
                    stepperField(label: "AMRAP REPS", intValue: $entry.workReps, min: 0, max: 60)
                }

                rpePicker

                Button {
                    UnboundHaptics.medium()
                    entry.logged.toggle()
                } label: {
                    Text(entry.logged ? "LOGGED" : "LOG THIS LIFT")
                        .font(Font.unbound.monoS)
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ChamferedRectangle(inset: 6)
                                .fill(entry.logged ? Color.unbound.accent.opacity(0.35) : Color.unbound.surface)
                        )
                        .overlay(
                            ChamferedRectangle(inset: 6)
                                .stroke(entry.logged ? Color.unbound.accent : Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hintText: String {
        entry.kind == .weight
            ? "1 WARMUP · 1 AMRAP SET"
            : "1 WARMUP · 1 MAX-EFFORT SET"
    }

    private var rpePicker: some View {
        HStack(spacing: 10) {
            Text("RPE")
                .font(Font.unbound.monoS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            ForEach([6, 7, 8, 9, 10], id: \.self) { level in
                Button {
                    UnboundHaptics.tick()
                    entry.rpe = level
                } label: {
                    Text("\(level)")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(entry.rpe == level ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                        .frame(width: 32, height: 30)
                        .background(
                            ChamferedRectangle(inset: 4)
                                .fill(entry.rpe == level ? Color.unbound.accent.opacity(0.4) : Color.clear)
                        )
                        .overlay(
                            ChamferedRectangle(inset: 4)
                                .stroke(entry.rpe == level ? Color.unbound.accent : Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stepperField(
        label: String,
        value: Binding<Double>,
        step: Double,
        min: Double,
        max: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Font.unbound.monoS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            HStack(spacing: 8) {
                stepButton(icon: "minus") {
                    value.wrappedValue = Swift.max(min, value.wrappedValue - step)
                }
                Text(String(format: "%g", value.wrappedValue))
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                stepButton(icon: "plus") {
                    value.wrappedValue = Swift.min(max, value.wrappedValue + step)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ChamferedRectangle(inset: 6)
                .fill(Color.unbound.bg.opacity(0.45))
        )
        .overlay(
            ChamferedRectangle(inset: 6)
                .stroke(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func stepperField(
        label: String,
        intValue: Binding<Int>,
        min: Int,
        max: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Font.unbound.monoS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            HStack(spacing: 8) {
                stepButton(icon: "minus") {
                    intValue.wrappedValue = Swift.max(min, intValue.wrappedValue - 1)
                }
                Text("\(intValue.wrappedValue)")
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                stepButton(icon: "plus") {
                    intValue.wrappedValue = Swift.min(max, intValue.wrappedValue + 1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ChamferedRectangle(inset: 6)
                .fill(Color.unbound.bg.opacity(0.45))
        )
        .overlay(
            ChamferedRectangle(inset: 6)
                .stroke(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.soft()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 28, height: 28)
                .background(
                    ChamferedRectangle(inset: 4)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    ChamferedRectangle(inset: 4)
                        .stroke(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
