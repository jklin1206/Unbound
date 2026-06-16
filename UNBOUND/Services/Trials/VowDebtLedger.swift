// UNBOUND/Services/Trials/VowDebtLedger.swift
import Foundation

/// Reads and pays down a user's broken-vow XP debt. Consulted by
/// OverallLevelService when crediting earned training XP (spec §5).
@MainActor
protocol VowDebtLedger: AnyObject {
    func outstandingDebtXP(userId: String) -> Int
    /// Consume up to `amount` of outstanding debt; returns the amount actually
    /// consumed (clamped to outstanding) and persists the reduced debt.
    @discardableResult
    func consumeDebt(upTo amount: Int, userId: String) -> Int
}

@MainActor
final class LiveVowDebtLedger: VowDebtLedger {
    private let store: WeeklyVowsStore

    init(store: WeeklyVowsStore = .shared) {
        self.store = store
    }

    func outstandingDebtXP(userId: String) -> Int {
        max(0, store.load(userId: userId).pendingVowDebtXP)
    }

    @discardableResult
    func consumeDebt(upTo amount: Int, userId: String) -> Int {
        guard amount > 0 else { return 0 }
        var state = store.load(userId: userId)
        let consumed = min(max(0, state.pendingVowDebtXP), amount)
        guard consumed > 0 else { return 0 }
        state.pendingVowDebtXP = max(0, state.pendingVowDebtXP - consumed)
        store.save(state, userId: userId)
        return consumed
    }
}
