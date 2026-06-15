import SwiftUI
import UIKit

struct ProgramRoutinesTab: View {
    @Binding var selectedChallengeId: String
    @Binding var selectedRoutineIdsByCategory: [RoutineCategory: String]
    let currentTier: SkillTier
    let onBeginRoutine: (RoutineDef) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Pick a side mission when the main plan is not the move. Rewards come from the work you log.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                challengeLibrary

                ForEach(RoutineCategory.allCases.filter { $0 != .challenge }, id: \.self) { category in
                    routineSection(category: category)
                }

                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var challengeLibrary: some View {
        let challenges = RoutineLibrary.routines(category: .challenge)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: RoutineCategory.challenge.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RoutineCategory.challenge.color)
                Text("CHALLENGE LIBRARY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RoutineCategory.challenge.color)
                Spacer()
                Text("\(challenges.count) missions")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: $selectedChallengeId) {
                ForEach(challenges) { routine in
                    Button {
                        onBeginRoutine(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine, currentTier: currentTier)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: RoutineDungeonLayout.cardHeight)

            RoutineChallengeDots(challenges: challenges, selectedId: selectedChallengeId)
        }
    }

    private func routineSection(category: RoutineCategory) -> some View {
        let items = RoutineLibrary.routines(category: category)
        let selection = Binding<String>(
            get: { selectedRoutineIdsByCategory[category] ?? items.first?.id ?? "" },
            set: { selectedRoutineIdsByCategory[category] = $0 }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.label)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(category.color)
                Spacer()
                Text("\(items.count) missions")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: selection) {
                ForEach(items) { routine in
                    Button {
                        onBeginRoutine(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine, currentTier: currentTier)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: RoutineDungeonLayout.cardHeight)

            RoutineChallengeDots(challenges: items, selectedId: selection.wrappedValue)
        }
    }
}
