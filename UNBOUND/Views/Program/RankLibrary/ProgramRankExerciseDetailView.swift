import SwiftUI
import UIKit

struct ProgramRankExerciseDetailView: View {
    let row: ProgramRankLibraryRow
    let onLogged: () async -> Void

    @EnvironmentObject var services: ServiceContainer

    @State var progress: MovementProgressState?
    @State var userProfile: UserProfile?
    @State var history: [ProgramRankExerciseHistoryEntry] = []
    @State var isLoading = true
    @State var isSubmitting = false
    @State var errorMessage: String?
    @State var hasSeededDefaults = false

    @State var selectedWeightDisplay: Double = 0
    @State var selectedReps: Int = 1
    @State var selectedSeconds: Int = 30
    @State var selectedRepGraphRange: ProgramRankRepGraphRange = .thirtyDays
    @State var rankReveal: ProgramRankAttemptReveal?

    var definition: MovementDefinition? {
        MovementCatalog.definition(for: row.sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: row.title)?.standard
    }

    var logMode: ProgramRankExerciseLogMode {
        definition.map(ProgramRankExerciseLogMode.mode(for:)) ?? .oneRepMax
    }

    var tint: Color {
        displayedTier.rewardTextTint
    }

    var displayedTier: SkillTier {
        resolvedTier(for: progress) ?? row.tier
    }

    var weightUnit: TrainingWeightUnit {
        WeightPlatePolicy.currentUnit
    }

    var selectedWeightKg: Double? {
        guard selectedWeightDisplay > 0 else { return nil }
        return weightUnit.kilograms(fromDisplayValue: selectedWeightDisplay)
    }

    var canSubmit: Bool {
        switch logMode {
        case .oneRepMax:
            return selectedWeightDisplay > 0
        case .reps:
            return selectedReps > 0
        case .hold:
            return selectedSeconds > 0
        }
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if let definition {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hero(definition)
                        progressSummary
                        targetMapSection(definition)
                        guideLayer(definition)
                        singleLogCard(definition)
                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
            } else {
                missingState
            }
        }
        .navigationTitle(definition?.displayName ?? row.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .alert("Couldn't save rank attempt", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Retry") { Task { await submitLog() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Your selections are still here.")
        }
        .toolbar(rankReveal == nil ? .visible : .hidden, for: .navigationBar)
        .overlay {
            if let rankReveal {
                ProgramRankAttemptRevealOverlay(reveal: rankReveal) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        self.rankReveal = nil
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}
