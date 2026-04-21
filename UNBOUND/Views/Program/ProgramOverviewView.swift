import SwiftUI

struct ProgramOverviewView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var viewModel: ProgramViewModel?
    @State private var selectedDay: ProgramDay?
    @State private var showPaywall = false
    @State private var showRationale = false

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            if let viewModel {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .tint(.theme.primary)

                case .error(let error):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.theme.danger)
                        Text(error.localizedDescription)
                            .font(.bodyText())
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                case .loaded(let program):
                    programContent(program)
                }
            } else {
                ProgressView()
                    .tint(.theme.primary)
            }
        }
        .navigationTitle("Your Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ExerciseLibraryView(services: services)) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.theme.primary)
                }
            }
        }
        .task {
            let vm = ProgramViewModel(services: services)
            self.viewModel = vm
            guard let userId = services.auth.currentUserId else { return }
            do {
                let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
                if let programId = profile.currentProgramId {
                    await vm.loadProgram(programId: programId)
                }
            } catch {}
        }
        .sheet(isPresented: $showPaywall) {
            PaywallPlaceholderView()
                .environmentObject(services)
        }
        .sheet(isPresented: $showRationale) {
            if let rationale = viewModel?.program?.rationale {
                WhyThisProgramView(rationale: rationale, onDismiss: { showRationale = false })
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationDestination(item: $selectedDay) { day in
            DayDetailView(day: day, nutritionPlan: viewModel?.dailyNutrition, recoveryPlan: viewModel?.recoveryPlan, workoutLog: viewModel?.logFor(dayNumber: day.dayNumber))
        }
    }

    @ViewBuilder
    private func programContent(_ program: TrainingProgram) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                programHeader(program)

                // Subscription gate — respects the dev unlock override via EntitlementService.
                if !services.entitlement.isEntitled {
                    subscriptionBanner
                }

                // Calendar
                calendarSection(program)
            }
            .padding(.bottom, 32)
        }
    }

    private func programHeader(_ program: TrainingProgram) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text(program.name)
                    .font(.headline(24))
                    .foregroundColor(.theme.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    archetypeBadge(program.archetype)

                    Text("\(program.durationDays) days")
                        .font(.caption(13))
                        .foregroundColor(.theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.theme.surface)
                        .clipShape(Capsule())
                }
            }

            Text(program.description)
                .font(.bodyText(15))
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if program.rationale != nil {
                Button {
                    showRationale = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption(12))
                        Text("Why this program?")
                            .font(.bodyMedium(14))
                    }
                    .foregroundColor(.theme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.theme.primary.opacity(0.12))
                    .overlay(
                        Capsule().stroke(Color.theme.primary.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }

    private func archetypeBadge(_ archetype: Archetype) -> some View {
        Text(archetype.displayName)
            .font(.caption(13))
            .fontWeight(.semibold)
            .foregroundColor(.theme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.theme.primary.opacity(0.15))
            .clipShape(Capsule())
    }

    private var subscriptionBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock your full program")
                        .font(.bodyMedium(15))
                        .foregroundColor(.theme.textPrimary)
                    Text("Subscribe to access workouts, nutrition & recovery")
                        .font(.caption(12))
                        .foregroundColor(.theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption())
                    .foregroundColor(.theme.textMuted)
            }
            .padding(16)
            .background(Color.theme.primary.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.primary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func calendarSection(_ program: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2-Week Plan")
                .font(.subheadline(18))
                .foregroundColor(.theme.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(program.days.prefix(14)) { day in
                        DayCalendarCard(day: day, isCompleted: viewModel?.isCompleted(dayNumber: day.dayNumber) ?? false) {
                            if services.entitlement.isEntitled {
                                selectedDay = day
                            } else {
                                showPaywall = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Day Calendar Card

private struct DayCalendarCard: View {
    let day: ProgramDay
    var isCompleted: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text("Day")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)

                Text("\(day.dayNumber)")
                    .font(.stat(20))
                    .foregroundColor(.theme.textPrimary)

                if day.isRestDay {
                    Text("Rest Day")
                        .font(.caption(11))
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    Text(day.workout?.name ?? day.label)
                        .font(.caption(11))
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                // Muscle group dots
                if let workout = day.workout, !day.isRestDay {
                    HStack(spacing: 3) {
                        ForEach(workout.targetMuscleGroups.prefix(4), id: \.self) { group in
                            Circle()
                                .fill(muscleGroupColor(group))
                                .frame(width: 6, height: 6)
                        }
                    }
                } else {
                    Spacer().frame(height: 6)
                }
            }
            .frame(width: 72, height: 110)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(day.isRestDay ? Color.theme.surface.opacity(0.6) : Color.theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.surfaceLight, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.theme.success)
                        .font(.caption())
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func muscleGroupColor(_ group: MuscleGroup) -> Color {
        switch group {
        case .chest: return .theme.primary
        case .back, .lats: return Color(hex: "5E8CFF")
        case .shoulders: return Color(hex: "FF6BDA")
        case .legs, .glutes, .calves: return Color(hex: "FFD60A")
        case .arms, .forearms: return .theme.secondary
        case .core, .traps, .neck: return Color(hex: "AF52DE")
        }
    }
}

