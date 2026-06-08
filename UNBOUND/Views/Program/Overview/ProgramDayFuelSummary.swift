import Foundation

/// Builds the plain-text fuel fragment folded into the Today's-Plan meta line
/// (replaces the boxed ProgramFuelTargetBand on that surface).
enum ProgramDayFuelSummary {
    static func text(kcal: Int, proteinGrams: Int, isRestDay: Bool) -> String {
        if isRestDay { return "rest day" }
        return "\(kcal) kcal · \(proteinGrams)g protein"
    }
}
