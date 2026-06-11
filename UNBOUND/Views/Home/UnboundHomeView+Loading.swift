import Foundation
import SwiftUI
import UIKit

// Data loading/refresh/save logic lives in `HomeViewModel`. This extension
// keeps only the view-side pieces: cosmetic store binding, session launch,
// and bodyweight display formatting (unit comes from @AppStorage).

extension UnboundHomeView {
    /// Binds the cosmetic stores (badges, wallet, shop inventory) and reads
    /// the equipped cosmetics. Called from `.task` before the model loads.
    func bindCosmeticStores() {
        guard let userId = services.auth.currentUserId else { return }
        services.badges.bind(userId: userId)
        walletStore.bind(userId: userId)
        shopInventoryStore.bind(userId: userId)
        equippedShopProfileBorder = shopInventoryStore.equippedProfileBorder()
        equippedHomeBackdrop = shopInventoryStore.equippedBackdrop(for: .home)
    }

    // MARK: - Session flow

    func beginTodaySession() {
        guard let day = model.todayProgramDay
        else {
            NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            return
        }
        guard day.workout != nil || day.userWorkoutDraft != nil else {
            NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            return
        }
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Today session launch skipped without authenticated user",
                level: .warning
            )
            return
        }
        workoutReadyDraft = DailyWorkoutResolver.programDraft(
            from: day,
            userId: userId,
            programId: model.program?.id,
            date: Date()
        )
    }

    // MARK: - Bodyweight display

    var selectedWeightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    var bodyWeightValueText: String {
        guard let latestBodyWeightKg = model.latestBodyWeightKg else { return "--" }
        return WeightPlatePolicy.formatLoggedWeight(latestBodyWeightKg, unit: selectedWeightUnit)
    }

    var bodyWeightRecencyText: String {
        if let loggedAt = model.bodyWeightLogs.first?.loggedAt {
            return "LOGGED \(dayWord(for: loggedAt))"
        }
        if model.latestBodyWeightKg != nil {
            return "FROM PROFILE"
        }
        return "NO ENTRIES YET"
    }

    var bodyWeightStatusColor: Color {
        model.hasLoggedBodyWeightToday ? Color.unbound.success : Color.unbound.accent
    }
}
