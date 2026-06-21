import SwiftUI
import UIKit

extension ProgramOverviewView {
    #if DEBUG
    var devDaySimulatorCard: some View {
        ProgramDevDaySimulatorCard(
            offsetLabel: devDayOffsetLabel,
            dateLabel: devDayDateLabel,
            onPrevious: { moveSimulatedDay(by: -1) },
            onReset: resetSimulatedDay,
            onNext: { moveSimulatedDay(by: 1) },
            onPlus7: { moveSimulatedDay(by: 7) },
            onPlus14: { moveSimulatedDay(by: 14) },
            onPlus28: { moveSimulatedDay(by: 28) },
            onEnd: jumpToBlockCompleteInspectionDay
        )
    }

    var devDynamicScenarioRail: some View {
        ProgramDevDynamicScenarioRail(
            scenarios: orderedDevDynamicScenarios,
            activeRawValue: activeDevDynamicScenarioRawValue,
            isFreshMode: UserDefaults.standard.string(forKey: DevBuildBootstrapper.devAccountModeKey)
                == DevBuildBootstrapper.freshLoginDevAccountMode,
            isSeeding: isSeedingDevDynamicScenario,
            onSelect: applyDevDynamicScenario
        )
    }

    var orderedDevDynamicScenarios: [DevDynamicProgramScenario] {
        guard let active = DevDynamicProgramScenario(rawValue: activeDevDynamicScenarioRawValue) else {
            return DevDynamicProgramScenario.allCases
        }
        return [active] + DevDynamicProgramScenario.allCases.filter { $0 != active }
    }

    var devDayOffsetLabel: String {
        if devDayOffset == 0 { return "REAL TODAY" }
        return devDayOffset > 0 ? "D+\(devDayOffset)" : "D\(devDayOffset)"
    }

    var devDayDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: programToday).uppercased()
    }

    func moveSimulatedDay(by days: Int) {
        UnboundHaptics.soft()
        let offset = DevProgramClock.advance(days: days)
        devDayOffset = offset
        syncSelectedDayToSimulatedToday(offset: offset)
    }

    func resetSimulatedDay() {
        UnboundHaptics.soft()
        let offset = DevProgramClock.reset()
        devDayOffset = offset
        syncSelectedDayToSimulatedToday(offset: offset)
    }

    func jumpToBlockCompleteInspectionDay() {
        UnboundHaptics.soft()
        guard let program = viewModel.program else {
            moveSimulatedDay(by: 28)
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: BlockRolloverScheduler.activeStartDate(for: program))
        let target = calendar.date(byAdding: .day, value: program.durationDays, to: start) ?? start
        let realToday = calendar.startOfDay(for: Date())
        let offset = calendar.dateComponents([.day], from: realToday, to: target).day ?? devDayOffset
        devDayOffset = DevProgramClock.setDayOffset(offset)
        syncSelectedDayToSimulatedToday(offset: offset)
    }

    func syncSelectedDayToSimulatedToday(offset: Int? = nil) {
        let today = DevProgramClock.today(offset: offset ?? devDayOffset)
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedDayDate = today
            weekOffset = 0
        }
        Task {
            await viewModel.refreshHistory()
            await viewModel.refreshTravelOverride()
        }
    }

    func applyDevDynamicScenario(_ scenario: DevDynamicProgramScenario) {
        guard !isSeedingDevDynamicScenario else { return }
        UnboundHaptics.soft()
        isSeedingDevDynamicScenario = true
        Task {
            await DevBuildBootstrapper.seedDynamicProgramScenario(
                services: services,
                scenario: scenario
            )
            await MainActor.run {
                activeDevDynamicScenarioRawValue = scenario.rawValue
                devDayOffset = DevProgramClock.dayOffset
                selectedDayDate = DevProgramClock.today(offset: devDayOffset)
                weekOffset = 0
            }
            await loadProgramSurface()
            await MainActor.run {
                isSeedingDevDynamicScenario = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
    #endif
}
