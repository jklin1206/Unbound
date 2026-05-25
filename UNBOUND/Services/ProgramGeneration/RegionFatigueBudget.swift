import Foundation

struct RegionFatigueSource: Sendable {
    enum SourceKind: String, Codable, Sendable {
        case plannedWorkout
        case skillBlock
        case weeklyVow
        case savedWorkout
        case custom
    }

    var id: String
    var kind: SourceKind
    var regionLoad: RegionLoad
    var protected: Bool

    init(
        id: String = UUID().uuidString,
        kind: SourceKind,
        regionLoad: RegionLoad,
        protected: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.regionLoad = regionLoad
        self.protected = protected
    }
}

struct RegionTrimRecommendation: Sendable {
    var region: ProgramBodyRegion
    var excessLoad: Double
    var protectedLoad: Double
    var reason: ProgramRationale.Decision
}

enum RegionFatigueBudget {
    static func load(from sources: [RegionFatigueSource]) -> RegionLoad {
        sources.reduce(into: RegionLoad()) { total, source in
            for (region, amount) in source.regionLoad.loads {
                total.add(amount, to: region)
            }
        }
    }

    static func protectedLoad(from sources: [RegionFatigueSource]) -> RegionLoad {
        sources
            .filter(\.protected)
            .reduce(into: RegionLoad()) { total, source in
                for (region, amount) in source.regionLoad.loads {
                    total.add(amount, to: region)
                }
            }
    }

    static func trimRecommendations(
        sources: [RegionFatigueSource],
        budget: RegionLoad
    ) -> [RegionTrimRecommendation] {
        let total = load(from: sources)
        let protected = protectedLoad(from: sources)

        return total.loads.compactMap { region, amount in
            let excess = amount - budget[region]
            guard excess > 0 else { return nil }
            return RegionTrimRecommendation(
                region: region,
                excessLoad: excess,
                protectedLoad: protected[region],
                reason: ProgramRationale.Decision(
                    category: .accessoryRemoved,
                    regionScope: region,
                    inputSummary: "\(region.displayName) load is \(format(amount)) over a \(format(budget[region])) budget.",
                    revertible: true
                )
            )
        }
        .sorted { $0.region.displayName < $1.region.displayName }
    }

    static func regionLoad(for workout: Workout) -> RegionLoad {
        let exercises = workout.warmup + workout.mainExercises + workout.cooldown
        return exercises.reduce(into: RegionLoad()) { total, exercise in
            let setLoad = max(1, exercise.sets)
            for muscle in exercise.muscleGroups {
                total.add(Double(setLoad), to: ProgramBodyRegion.from(muscleGroup: muscle))
            }
        }
    }

    static func regionLoad(for draft: TrainingSessionDraft) -> RegionLoad {
        draft.blocks.reduce(into: RegionLoad()) { total, block in
            for prescription in block.prescriptions {
                let setLoad = max(1, prescription.sets)
                for muscle in prescription.muscleGroups {
                    total.add(Double(setLoad), to: ProgramBodyRegion.from(muscleGroup: muscle))
                }
            }
        }
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
