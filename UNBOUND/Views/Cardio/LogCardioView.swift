import SwiftUI

struct LogCardioView: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    var onLogged: ((CardioSession) -> Void)? = nil

    @State private var type: CardioType = .run
    @State private var durationMinutes: Int = 30
    @State private var distanceKm: String = ""
    @State private var avgHR: String = ""
    @State private var perceivedEffort: Int = 6
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var rewardSequence: WorkoutRewardSequenceSummary?
    @State private var showError = false
    @State private var errorMessage = ""

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        typeCard
                        durationCard
                        effortCard
                        optionalMetricsCard
                        notesCard
                        Spacer().frame(height: 96)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .safeAreaInset(edge: .bottom) {
                    logSessionButton
                }
            }
            .navigationTitle("Log cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .fullScreenCover(item: $rewardSequence) { reward in
            WorkoutRewardSequenceView(summary: reward) {
                rewardSequence = nil
                dismiss()
            }
            .interactiveDismissDisabled(true)
        }
        .alert("Cardio was not saved", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var logSessionButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.unbound.bg.opacity(0), Color.unbound.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 18)
            UnboundButton(
                title: isSaving ? "Saving..." : "Log session",
                icon: "checkmark",
                action: save
            )
            .disabled(isSaving)
            .accessibilityIdentifier("cardio.logSession")
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(Color.unbound.bg)
        }
    }

    private var typeCard: some View {
        card(title: "TYPE") {
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(CardioType.allCases) { kind in
                    typeCell(kind)
                }
            }
        }
    }

    private func typeCell(_ kind: CardioType) -> some View {
        let isSelected = kind == type
        return Button {
            UnboundHaptics.soft()
            type = kind
        } label: {
            VStack(spacing: 8) {
                Image(systemName: kind.sfSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textSecondary)
                Text(kind.displayName)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.unbound.accent.opacity(0.12) : Color.unbound.bg.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.unbound.accent.opacity(0.6) : Color.unbound.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cardio.type.\(kind.rawValue)")
    }

    private var durationCard: some View {
        card(title: "DURATION") {
            HStack(spacing: 14) {
                Button {
                    UnboundHaptics.soft()
                    durationMinutes = max(1, durationMinutes - 5)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.unbound.surface))
                        .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .accessibilityIdentifier("cardio.duration.decrease")
                VStack {
                    Text("\(durationMinutes)")
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                    Text("minutes")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .frame(maxWidth: .infinity)
                Button {
                    UnboundHaptics.soft()
                    durationMinutes = min(480, durationMinutes + 5)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.unbound.surface))
                        .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .accessibilityIdentifier("cardio.duration.increase")
            }
        }
    }

    private var effortCard: some View {
        card(title: "PERCEIVED EFFORT · \(perceivedEffort)/10") {
            Slider(
                value: Binding(
                    get: { Double(perceivedEffort) },
                    set: { perceivedEffort = Int($0.rounded()) }
                ),
                in: 1...10,
                step: 1
            )
            .tint(Color.unbound.accent)
            HStack {
                Text("Easy")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("Max")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var optionalMetricsCard: some View {
        card(title: "OPTIONAL") {
            VStack(spacing: 10) {
                HStack {
                    Text("Distance (km)")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                    TextField("—", text: $distanceKm)
                        .font(Font.unbound.monoL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 90)
                }
                Divider().background(Color.unbound.border)
                HStack {
                    Text("Avg HR")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                    TextField("—", text: $avgHR)
                        .font(Font.unbound.monoL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                }
            }
        }
    }

    private var notesCard: some View {
        card(title: "NOTES") {
            TextField("Optional — how it felt...", text: $notes, axis: .vertical)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private func save() {
        let userId = services.auth.currentUserId ?? "anonymous"
        let distance = Double(distanceKm.trimmingCharacters(in: .whitespaces))
        let hr = Int(avgHR.trimmingCharacters(in: .whitespaces))

        let session = CardioSession(
            userId: userId,
            type: type,
            durationMinutes: durationMinutes,
            distanceKm: distance,
            avgHR: hr,
            perceivedEffort: perceivedEffort,
            notes: notes.isEmpty ? nil : notes
        )

        isSaving = true
        Task {
            do {
                try await services.cardioLog.log(session: session)
                let performanceLog = TrainingSessionAdapters.performanceLogForCardioSession(session)
                let completionResult: TrainingCompletionResult
                do {
                    completionResult = try await TrainingCompletionService.shared.complete(
                        performanceLog,
                        services: services
                    )
                } catch {
                    LoggingService.shared.log(
                        "Cardio unified completion failed; using progression preview: \(error)",
                        level: .warning,
                        context: ["cardioSessionId": session.id.uuidString]
                    )
                    completionResult = TrainingCompletionService.shared.previewProgression(
                        for: performanceLog,
                        services: services
                    )
                }
                UnboundHaptics.success()
                await MainActor.run {
                    isSaving = false
                    onLogged?(session)
                    rewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
                        performanceLog: performanceLog,
                        completionResult: completionResult,
                        fallbackXP: cardioXP,
                        sourceName: "Cardio"
                    )
                }
            } catch {
                LoggingService.shared.log(
                    "Cardio save failed: \(error)",
                    level: .error,
                    context: ["cardioType": session.type.rawValue]
                )
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Try again in a moment. Nothing was awarded."
                    showError = true
                }
            }
        }
    }

    private var cardioXP: Int {
        let effortFactor = Double(perceivedEffort) / 6.0
        return max(5, Int((Double(durationMinutes) * type.intensityFactor * effortFactor).rounded()))
    }
}
