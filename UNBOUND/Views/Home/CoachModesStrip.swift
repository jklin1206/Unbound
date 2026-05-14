import SwiftUI

// MARK: - CoachModesStrip
//
// Three contextual mode buttons on the home page. No open chat.
// Each button opens a dedicated sheet that calls one AI service and
// returns a structured result. Plateau button only appears when a
// stall is detected by ProgressionEngine.

struct CoachModesStrip: View {
    let plateaus: [PlateauedExercise]
    let userId: String
    let onTravelActivated: (TravelOverride) -> Void

    @State private var showTravel = false
    @State private var showDeload = false
    @State private var showPlateauFix = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODES")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)

            HStack(spacing: 8) {
                modeButton(
                    icon: "airplane",
                    label: "TRAVEL",
                    color: Color.unbound.coachCyan
                ) { showTravel = true }

                modeButton(
                    icon: "arrow.down.circle",
                    label: "DELOAD",
                    color: Color.unbound.rankGreen
                ) { showDeload = true }

                if !plateaus.isEmpty {
                    modeButton(
                        icon: "exclamationmark.triangle",
                        label: "PLATEAU",
                        color: Color.unbound.warnOrange,
                        badge: plateaus.count > 1 ? "\(plateaus.count)" : nil
                    ) { showPlateauFix = true }
                }
            }
        }
        .sheet(isPresented: $showTravel) {
            TravelModeSheet(userId: userId) { override in
                onTravelActivated(override)
                showTravel = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDeload) {
            DeloadSheet(userId: userId)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPlateauFix) {
            PlateauFixSheet(plateaus: plateaus, userId: userId)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func modeButton(
        icon: String,
        label: String,
        color: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UnboundHaptics.medium()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(color))
                }
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TravelModeSheet

struct TravelModeSheet: View {
    let userId: String
    let onConfirm: (TravelOverride) -> Void

    @State private var selectedDays = 5
    @State private var phase: Phase = .pick
    @State private var result: TravelPlanService.TravelPlanResult?
    @State private var error: String?

    private enum Phase { case pick, loading, result, failed }
    private let dayOptions = [3, 5, 7, 10, 14]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                switch phase {
                case .pick:   pickView
                case .loading: loadingView
                case .result:  resultView
                case .failed:  failedView
                }
            }
            .navigationTitle("TRAVEL MODE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.unbound.bg, for: .navigationBar)
        }
    }

    // MARK: Pick duration

    private var pickView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Image(systemName: "airplane")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.unbound.coachCyan)
                Text("How long are you away?")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Bodyweight plan. Hotel room safe.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            .padding(.top, 24)

            HStack(spacing: 8) {
                ForEach(dayOptions, id: \.self) { d in
                    Button {
                        UnboundHaptics.tick()
                        selectedDays = d
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(d)")
                                .font(.system(size: 20, weight: .black))
                            Text(d == 1 ? "DAY" : "DAYS")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                        }
                        .foregroundStyle(selectedDays == d ? Color.unbound.bg : Color.unbound.coachCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedDays == d ? Color.unbound.coachCyan : Color.unbound.coachCyan.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                UnboundHaptics.heavy()
                generate()
            } label: {
                Text("BUILD PLAN")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.coachCyan)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(Color.unbound.coachCyan)
            Text("Building your travel plan…")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    // MARK: Result

    private var resultView: some View {
        guard let r = result else { return AnyView(EmptyView()) }
        return AnyView(
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    Text(r.summary)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.coachCyan.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.unbound.coachCyan.opacity(0.25), lineWidth: 1)
                                )
                        )

                    // Days
                    ForEach(Array(r.override.days.enumerated()), id: \.offset) { _, day in
                        travelDayRow(day)
                    }

                    // Confirm
                    Button {
                        UnboundHaptics.heavy()
                        onConfirm(r.override)
                    } label: {
                        Text("ACTIVATE TRAVEL MODE")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.bg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.unbound.coachCyan)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        )
    }

    @ViewBuilder
    private func travelDayRow(_ day: TravelDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(day.title)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(day.isRest ? Color.unbound.textTertiary : Color.unbound.coachCyan)
                Spacer()
                Text(day.duration)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            if !day.isRest {
                ForEach(day.exercises, id: \.self) { ex in
                    Text("· \(ex)")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    // MARK: Failed

    private var failedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.unbound.warnOrange)
            Text(error ?? "Something went wrong.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                UnboundHaptics.medium()
                generate()
            } label: {
                Text("RETRY")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Generate

    private func generate() {
        phase = .loading
        Task {
            do {
                let r = try await TravelPlanService.shared.generate(
                    userId: userId,
                    days: selectedDays
                )
                result = r
                phase = .result
            } catch {
                self.error = error.localizedDescription
                phase = .failed
            }
        }
    }
}

// MARK: - DeloadSheet

struct DeloadSheet: View {
    let userId: String

    @State private var phase: Phase = .preview
    @State private var states: [ProgressionState] = []
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case preview, applied }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                switch phase {
                case .preview: previewView
                case .applied: appliedView
                }
            }
            .navigationTitle("DELOAD WEEK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.unbound.bg, for: .navigationBar)
            .task { await loadStates() }
        }
    }

    private var previewView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.unbound.rankGreen)
                Text("Deload Week")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Same exercises. RPE drops to 6. Volume cut 40%.\nOne week, then back to full intensity.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)

            VStack(spacing: 8) {
                deloadStat(label: "TARGET RPE", value: "6")
                deloadStat(label: "VOLUME", value: "−40%")
                deloadStat(label: "DURATION", value: "1 WEEK")
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                UnboundHaptics.heavy()
                applyDeload()
            } label: {
                Text("APPLY DELOAD")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.rankGreen)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private var appliedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.unbound.rankGreen)
            Text("Deload active.")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Your program will run at recovery intensity this week.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                UnboundHaptics.medium()
                dismiss()
            } label: {
                Text("GOT IT")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)
        }
    }

    private func deloadStat(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.unbound.rankGreen)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private func loadStates() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        states = (try? await DatabaseService.shared.query(
            collection: "progression_states",
            field: "userId",
            isEqualTo: uid,
            orderBy: "updatedAt",
            descending: true,
            limit: 30
        )) ?? []
    }

    private func applyDeload() {
        let deloaded = DeloadPlanner.shared.planDeload(for: states)
        Task {
            for s in deloaded {
                try? await DatabaseService.shared.create(
                    s, collection: "progression_states", documentId: s.id
                )
            }
            await MainActor.run { phase = .applied }
        }
    }
}

// MARK: - PlateauFixSheet

struct PlateauFixSheet: View {
    let plateaus: [PlateauedExercise]
    let userId: String

    @State private var selectedIndex = 0
    @State private var phase: Phase = .loading
    @State private var fix: PlateauFixService.PlateauFix?
    @State private var error: String?

    private enum Phase { case loading, result, failed }

    var selectedPlateau: PlateauedExercise? { plateaus[safe: selectedIndex] }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                switch phase {
                case .loading: loadingView
                case .result:  resultView
                case .failed:  failedView
                }
            }
            .navigationTitle("PLATEAU FIX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.unbound.bg, for: .navigationBar)
            .task { await generate() }
        }
    }

    // MARK: Lift picker (if multiple stalls)

    @ViewBuilder
    private var liftPicker: some View {
        if plateaus.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(plateaus.enumerated()), id: \.offset) { i, p in
                        Button {
                            UnboundHaptics.tick()
                            selectedIndex = i
                            Task { await generate() }
                        } label: {
                            Text(p.displayName.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(i == selectedIndex ? Color.unbound.bg : Color.unbound.warnOrange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(i == selectedIndex ? Color.unbound.warnOrange : Color.unbound.warnOrange.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            liftPicker
            Spacer()
            ProgressView().tint(Color.unbound.warnOrange)
            Text("Diagnosing the stall…")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
    }

    private var resultView: some View {
        guard let f = fix else { return AnyView(EmptyView()) }
        return AnyView(
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    liftPicker

                    // Diagnosis card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.unbound.warnOrange)
                            Text("DIAGNOSIS")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(Color.unbound.warnOrange)
                        }
                        Text(f.diagnosis)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.warnOrange.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.unbound.warnOrange.opacity(0.22), lineWidth: 1)
                            )
                    )

                    // 3-week plan
                    Text("3-WEEK FIX")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.top, 4)

                    ForEach(Array(f.weeks.enumerated()), id: \.offset) { i, week in
                        HStack(alignment: .top, spacing: 14) {
                            Text(week.label)
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(Color.unbound.warnOrange)
                                .frame(width: 52, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(week.focus.uppercased())
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.unbound.textSecondary)
                                Text(week.instruction)
                                    .font(Font.unbound.bodyS)
                                    .foregroundStyle(Color.unbound.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        )
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.unbound.warnOrange)
            Text(error ?? "Couldn't reach the coach.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                UnboundHaptics.medium()
                Task { await generate() }
            } label: {
                Text("RETRY")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)
        }
    }

    private func generate() async {
        guard let plateau = selectedPlateau else { return }
        phase = .loading
        do {
            fix = try await PlateauFixService.shared.generate(for: plateau, userId: userId)
            phase = .result
        } catch {
            self.error = error.localizedDescription
            phase = .failed
        }
    }
}

// MARK: - Safe subscript helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
