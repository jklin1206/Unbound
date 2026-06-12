import SwiftUI
import UIKit

// MARK: - Routine step preview helper

func routineStepPreview(_ step: RoutineStep) -> String {
    switch step {
    case .instruction(let t, _):            return t
    case .timed(let l, let s, _):           return "\(l) — \(s)s"
    case .interval(let l, let r, _):        return "\(l) — \(r) rounds"
    case .repTarget(let n, let t, _):       return t.map { "\(n) — \($0)" } ?? "\(n) — AMRAP"
    case .circuit(let r, _, let steps):
        let moves = steps.compactMap(routineStepShortLabel).prefix(4).joined(separator: " + ")
        return moves.isEmpty ? "Circuit × \(r) rounds" : "Circuit × \(r): \(moves)"
    case .note(let t):                      return t
    }
}

private func routineStepShortLabel(_ step: RoutineStep) -> String? {
    switch step {
    case .instruction(let text, _):
        return text.components(separatedBy: "—").first?
            .components(separatedBy: "×").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    case .timed(let label, _, let style):
        return style == .work ? label : nil
    case .repTarget(let name, _, _):
        return name
    case .interval(let label, _, _):
        return label
    case .circuit, .note:
        return nil
    }
}

extension RoutineDef {
    var coverAssetName: String { "routine_challenge_\(id)" }
}
