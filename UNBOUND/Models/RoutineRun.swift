import Foundation

/// One step the player actually walks. Never `.circuit` (expanded) or
/// `.note` (filtered into `notes`). `roundLabel` is set for steps that came
/// from inside a circuit ("ROUND 2 / 3").
struct RoutineRunStep: Identifiable, Hashable {
    let id: Int
    let kind: RoutineStep
    let roundLabel: String?
}

enum RoutineRun {
    /// Flattens authored steps into the ordered run list + collected notes.
    /// Circuits expand to `rounds` copies of their inner steps with a
    /// `.timed(.rest, restBetweenSeconds)` inserted *between* rounds (not
    /// after the last round). `.note` is removed from the walk list.
    static func build(_ steps: [RoutineStep]) -> (run: [RoutineRunStep], notes: [String]) {
        var run: [RoutineRunStep] = []
        var notes: [String] = []
        var nextId = 0

        func append(_ kind: RoutineStep, roundLabel: String?) {
            run.append(RoutineRunStep(id: nextId, kind: kind, roundLabel: roundLabel))
            nextId += 1
        }

        for step in steps {
            switch step {
            case .note(let text):
                notes.append(text)

            case .circuit(let rounds, let restBetween, let inner):
                guard rounds > 0 else { continue }
                for round in 1...rounds {
                    let label = "ROUND \(round) / \(rounds)"
                    for innerStep in inner {
                        if case .note(let t) = innerStep {
                            notes.append(t)
                        } else {
                            append(innerStep, roundLabel: label)
                        }
                    }
                    if round < rounds {
                        append(.timed(label: "Rest",
                                      seconds: restBetween,
                                      style: .rest),
                               roundLabel: label)
                    }
                }

            default:
                append(step, roundLabel: nil)
            }
        }
        return (run, notes)
    }
}
