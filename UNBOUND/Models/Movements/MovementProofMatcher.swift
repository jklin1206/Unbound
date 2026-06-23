import Foundation

/// Matching used for skill proof and tier criteria.
///
/// This is intentionally stricter than AP/rank-standard roll-up. A loggable
/// variant can feed a parent movement's AP, but an assisted or eccentric
/// variant should not prove a strict skill unless the criterion names that
/// variant explicitly.
enum MovementProofMatcher {
    static func entry(_ entry: ExerciseLogEntry, satisfies exerciseName: String) -> Bool {
        movementMatches(
            loggedName: entry.exerciseName,
            loggedMovementId: entry.movementId,
            requiredName: exerciseName
        )
    }

    static func namesMatch(logged: String, required: String) -> Bool {
        movementMatches(
            loggedName: logged,
            loggedMovementId: nil,
            requiredName: required
        )
    }

    static func hasRegressionMismatch(loggedName: String, requiredName: String) -> Bool {
        let logged = MovementCatalog.normalized(loggedName)
        let required = MovementCatalog.normalized(requiredName)
        return MovementResolution.regressionTerms.contains { term in
            logged.contains(term) && !required.contains(term)
        }
    }

    private static func movementMatches(
        loggedName: String,
        loggedMovementId: String?,
        requiredName: String
    ) -> Bool {
        let loggedNormalized = MovementCatalog.normalized(loggedName)
        let requiredNormalized = MovementCatalog.normalized(requiredName)

        if loggedNormalized == requiredNormalized {
            return true
        }

        if hasRegressionMismatch(loggedName: loggedName, requiredName: requiredName) {
            return false
        }

        let required = MovementResolver.resolve(requiredName)
        if let loggedMovementId, loggedMovementId == required.movementId {
            return true
        }

        let logged = MovementResolver.resolve(loggedName)
        if logged.movementId == required.movementId {
            return true
        }

        // Same owning skill: the logged movement and the criterion's movement
        // are both the SAME skill's own movement (its drill/target or curated
        // exercise twin), so logging any of them is evidence for that skill.
        // This lets the library exercise, the drill, and the skill block (all
        // now named "Hollow Body Hold") advance the one Hollow Body Hold rank,
        // while "Hollow Rock" (a distinct movement) does not.
        if let owningSkill = MovementCatalog.owningSkillId(forMovementId: loggedMovementId ?? logged.movementId),
           owningSkill == MovementCatalog.owningSkillId(forMovementId: required.movementId) {
            return true
        }

        return false
    }
}
