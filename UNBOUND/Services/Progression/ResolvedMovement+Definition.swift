import Foundation

extension ResolvedMovement {
    var definition: MovementDefinition? {
        MovementCatalog.definition(for: movementId)
    }
}
