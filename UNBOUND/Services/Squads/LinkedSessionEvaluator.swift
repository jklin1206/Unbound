// UNBOUND/Services/Squads/LinkedSessionEvaluator.swift
import Foundation

// MARK: - LinkedSessionEvaluator
//
// Applies the +20% XP bonus when a squad partner's session overlaps the user's
// own session (a "linked session"). Called from the push notification handler
// when `.linkedSessionDetected` fires.
//
// Non-stacking rule: the linked bonus is intended to supersede the affinity
// bonus (+10%). If the affinity bonus was already applied this session, the
// linked bonus is reduced by the affinity amount so the net result is exactly
// +20% of base XP (not +30% stacked).
//
// Dependency injection: pass a `SessionXPServiceProtocol` for tests. Production
// code uses `SessionXPService.shared` via the default parameter.

@MainActor
enum LinkedSessionEvaluator {

    /// Apply the +20% XP bonus for a linked session.
    ///
    /// - Parameters:
    ///   - userId: The user receiving the bonus.
    ///   - sessionXPDelta: The **base** session XP (pre-affinity) from the push payload.
    ///   - service: The XP service to write into. Defaults to `SessionXPService.shared`.
    static func applyLinkedXPBonus(
        userId: String,
        sessionXPDelta: Int
    ) async {
        await applyLinkedXPBonus(
            userId: userId,
            sessionXPDelta: sessionXPDelta,
            service: SessionXPService.shared
        )
    }

    static func applyLinkedXPBonus(
        userId: String,
        sessionXPDelta: Int,
        service: SessionXPServiceProtocol
    ) async {
        let linkedBonus = Int(Double(sessionXPDelta) * 0.20)

        // Non-stacking: subtract any affinity bonus already applied this session
        // so the combined effect is capped at +20% from base.
        let affinityAlreadyApplied = await service.affinityBonusForLatestSession(userId: userId)
        let netBonus = linkedBonus - affinityAlreadyApplied

        await service.addBonus(userId: userId, amount: netBonus, reason: "linkedSession")
    }
}
