import SwiftUI

typealias RankTrialExercisePair = (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)

struct RankTrialActiveStageLayout<Header: View, ActiveContent: View, CompletedContent: View>: View {
    let pair: RankTrialExercisePair?
    private let header: () -> Header
    private let activeContent: (RankTrialExercisePair) -> ActiveContent
    private let completedContent: () -> CompletedContent

    init(
        pair: RankTrialExercisePair?,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder activeContent: @escaping (RankTrialExercisePair) -> ActiveContent,
        @ViewBuilder completedContent: @escaping () -> CompletedContent
    ) {
        self.pair = pair
        self.header = header
        self.activeContent = activeContent
        self.completedContent = completedContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header()

            if let pair {
                activeContent(pair)
            } else {
                completedContent()
            }
        }
        .padding(.top, 28)
    }
}

struct RankTrialInfoChip: View {
    let text: String
    let icon: String
    let tint: Color
    var background: Color = Color.unbound.surfaceElevated
    var strokeOpacity: Double = 0.34

    var body: some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Capsule().fill(background))
            .overlay(Capsule().strokeBorder(tint.opacity(strokeOpacity), lineWidth: 1))
    }
}

extension ActiveWorkoutSession {
    var rankTrialCurrentExercisePair: RankTrialExercisePair? {
        guard exercises.indices.contains(currentExerciseIndex) else { return nil }
        let exercise = exercises[currentExerciseIndex]
        guard !exercise.skipped else { return nil }
        return (currentExerciseIndex, exercise)
    }

    var rankTrialStationCount: Int {
        max(1, exercises.filter { !$0.skipped }.count)
    }

    func rankTrialLoggedStationCount(where isLogged: (ActiveExercise) -> Bool) -> Int {
        exercises.filter(isLogged).count
    }

    func rankTrialProgress(loggedStations: Int) -> CGFloat {
        CGFloat(loggedStations) / CGFloat(rankTrialStationCount)
    }
}

extension ActiveWorkoutSession.ActiveExercise {
    var hasLoggedRankTrialWorkingSet: Bool {
        sets.contains { $0.logged && !$0.isWarmup }
    }

    var hasCompletedRankTrialWorkingSets: Bool {
        let workingSets = sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return false }
        return workingSets.allSatisfy(\.logged)
    }
}
