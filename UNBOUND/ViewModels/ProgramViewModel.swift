import SwiftUI

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var program: TrainingProgram?
    @Published var state: LoadingState<TrainingProgram> = .idle
    @Published var selectedDay: ProgramDay?
    @Published var showTrainingDayNutrition = true
    @Published var workoutLogs: [Int: WorkoutLog] = [:]  // dayNumber -> log

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    func loadProgram(programId: String) async {
        state = .loading
        do {
            let program: TrainingProgram = try await services.database.read(collection: "programs", documentId: programId)
            self.program = program
            state = .loaded(program)
            services.analytics.track(.programViewed(programId: programId))
            await loadTrackingData()
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
    }

    func loadTrackingData() async {
        guard let userId = services.auth.currentUserId, let program else { return }
        do {
            let logs = try await services.workoutLog.fetchLogs(userId: userId, programId: program.id)
            workoutLogs = Dictionary(uniqueKeysWithValues: logs.compactMap { log in
                (log.dayNumber, log)
            })
        } catch {
            // Non-critical, don't block UI
        }
    }

    func isCompleted(dayNumber: Int) -> Bool {
        workoutLogs[dayNumber] != nil
    }

    func logFor(dayNumber: Int) -> WorkoutLog? {
        workoutLogs[dayNumber]
    }

    func selectDay(_ day: ProgramDay) {
        selectedDay = day
        if let program {
            services.analytics.track(.programDayViewed(programId: program.id, dayNumber: day.dayNumber))
        }
    }

    var dailyNutrition: NutritionPlan? {
        program?.nutritionPlan
    }

    var recoveryPlan: RecoveryPlan? {
        program?.recoveryPlan
    }
}
