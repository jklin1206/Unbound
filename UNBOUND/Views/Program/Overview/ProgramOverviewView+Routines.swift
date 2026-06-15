import SwiftUI

extension ProgramOverviewView {
    // MARK: - DUNGEONS tab

    var routinesTab: some View {
        ProgramRoutinesTab(
            selectedChallengeId: $selectedChallengeId,
            selectedRoutineIdsByCategory: $selectedRoutineIdsByCategory,
            currentTier: routineAccessTier,
            onBeginRoutine: beginRoutineTravel
        )
        .task {
            await refreshRoutineAccessTier()
        }
    }

    func beginRoutineTravel(_ routine: RoutineDef) {
        guard RoutineUnlockPolicy.state(for: routine, currentTier: routineAccessTier).isUnlocked else {
            UnboundHaptics.soft()
            return
        }

        UnboundHaptics.medium()
        travelingRoutine = routine
        routineTravelProgress = 0
        withAnimation(.easeInOut(duration: 0.58)) {
            routineTravelProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            activeRoutinePlayer = routine
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeOut(duration: 0.18)) {
                travelingRoutine = nil
                routineTravelProgress = 0
            }
        }
    }

    func refreshRoutineAccessTier() async {
        guard let userId = services.auth.currentUserId else {
            routineAccessTier = .initiate
            return
        }
        routineAccessTier = await services.rank.aggregateTier(userId: userId)
    }

    #if DEBUG
    func openWorkoutsTabIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--unbound-open-workouts") else { return }
        selectedTab = .myWorkouts
    }

    func openRoutineForProofIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--unbound-open-routine"),
              !debugOpenedRoutine
        else { return }

        debugOpenedRoutine = true
        selectedTab = .routines

        let requestedId = Self.launchArgumentValue(for: "--unbound-open-routine")
        let routine = requestedId
            .flatMap { id in RoutineLibrary.placeholderRoutines.first { $0.id == id } }
            ?? RoutineLibrary.routines(category: .challenge).first
            ?? RoutineLibrary.routinesSortedByDifficulty.first

        guard let routine else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            beginRoutineTravel(routine)
        }
    }

    static func launchArgumentValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        for (index, argument) in arguments.enumerated() {
            if argument == key, arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
            if argument.hasPrefix("\(key)=") {
                return String(argument.dropFirst(key.count + 1))
            }
        }
        return nil
    }
    #endif
}
