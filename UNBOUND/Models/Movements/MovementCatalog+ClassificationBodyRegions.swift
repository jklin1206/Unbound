import Foundation

// Body-region tagging: which regions an exercise (or muscle group) trains.
extension MovementCatalog {
    static func bodyRegions(for exercise: CatalogExercise) -> [BodyRegion] {
        let name = normalized(exercise.name)
        var regions = Set(bodyRegions(for: exercise.muscleGroups))

        let isChestIsolation = name.contains("chest fly")
            || name.contains("cable fly")
            || name.contains("dumbbell fly")
            || name.contains("pec dec")
            || name.contains("pec deck")
        let isUpperChestBias = name.contains("incline")
            || name.contains("low to high")
            || name.contains("low high")
        let isChestPress = name.contains("bench")
            || name.contains("chest press")
            || name.contains("pushup")
            || name.contains("dip")
            || isChestIsolation
        if isChestPress {
            regions.insert(isUpperChestBias ? .upperChest : .midLowerChest)
            if !isChestIsolation {
                regions.insert(.triceps)
                regions.insert(.frontSideDelts)
            }
        }

        if name.contains("overhead press") || name.contains("arnold press") || name.contains("handstand") || name.contains("pike") {
            regions.insert(.frontSideDelts)
            regions.insert(.triceps)
        }
        if name.contains("lateral raise") || name.contains("front raise") || name.contains("y raise") {
            regions.insert(.frontSideDelts)
        }
        if name.contains("upright row") {
            regions.insert(.frontSideDelts)
            regions.insert(.traps)
        }

        let isRearDeltIsolation = name.contains("rear delt")
            || name.contains("reverse pec")
            || name.contains("reverse fly")
            || name.contains("band pull apart")
            || name.contains("prone shoulder raise")
        if name.contains("face pull") || isRearDeltIsolation {
            regions.insert(.rearDelts)
            regions.insert(.rhomboids)
            regions.insert(.traps)
        }

        let isBackRow = name.contains("row") && !name.contains("upright row")
        if isBackRow {
            regions.insert(.lats)
            regions.insert(.rhomboids)
            regions.insert(.traps)
            regions.insert(.biceps)
            regions.insert(.forearms)
            if (name.contains("barbell") || name.contains("bent over") || name.contains("pendlay") || name.contains("meadows") || name.contains("landmine") || name.contains("t bar"))
                && !name.contains("chest supported")
                && !name.contains("machine") {
                regions.insert(.lowerBack)
            }
            if name.contains("high row") || name.contains("wide grip row") {
                regions.insert(.rearDelts)
            }
        }
        if name.contains("pullup") || name.contains("chin up") || name.contains("pulldown") || name.contains("pullover") {
            regions.insert(.lats)
            if !name.contains("straight arm") && !name.contains("pullover") {
                regions.insert(.biceps)
                regions.insert(.forearms)
            }
        }
        if name.contains("curl") {
            regions.insert(.biceps)
            if name.contains("hammer") || name.contains("rope") || name.contains("reverse") {
                regions.insert(.forearms)
            }
        }
        if name.contains("tricep") || name.contains("skull") || name.contains("close grip bench") {
            regions.insert(.triceps)
        }

        if name.contains("adductor") || name.contains("adduction") {
            regions.insert(.adductors)
        }
        if name.contains("abductor") || name.contains("abduction") || name.contains("lateral band walk") || name.contains("monster walk") || name.contains("clamshell") || name.contains("side lying leg raise") {
            regions.insert(.abductors)
            regions.insert(.glutes)
        }
        if name.contains("leg extension") {
            regions.insert(.quads)
        }
        if name.contains("squat") || name.contains("leg press") || name.contains("lunge") || name.contains("step up") {
            regions.insert(.quads)
            regions.insert(.glutes)
            if name.contains("sumo") || name.contains("cossack") || name.contains("lateral") {
                regions.insert(.adductors)
            }
        }
        if name.contains("leg curl") || name.contains("nordic") {
            regions.insert(.hamstrings)
        }
        if name.contains("deadlift") || name.contains("rdl") || name.contains("good morning") || name.contains("glute ham") {
            regions.insert(.hamstrings)
            regions.insert(.glutes)
            regions.insert(.lowerBack)
            if name.contains("sumo") {
                regions.insert(.adductors)
            }
        }
        if name.contains("hip thrust") || name.contains("glute bridge") || name.contains("kickback") || name.contains("pull through") || name.contains("kettlebell swing") {
            regions.insert(.glutes)
            regions.insert(.hamstrings)
        }
        if name.contains("plank") || name.contains("hollow") || name.contains("l sit") || name.contains("front lever") || name.contains("dragon flag") || name.contains("crunch") || name.contains("leg raise") || name.contains("knee raise") || name.contains("situp") || name.contains("ab wheel") {
            regions.insert(.abs)
        }
        if name.contains("pallof") || name.contains("rotation") || name.contains("cossack") {
            regions.insert(.obliques)
        }
        if name.contains("calf") || name.contains("tibialis") {
            regions.insert(.calves)
        }

        if isChestIsolation {
            regions = isUpperChestBias ? [.upperChest] : [.midLowerChest]
        } else if isChestPress {
            regions = isUpperChestBias
                ? [.upperChest, .triceps, .frontSideDelts]
                : [.midLowerChest, .triceps, .frontSideDelts]
        } else if name.contains("face pull") || isRearDeltIsolation {
            regions = [.rearDelts, .rhomboids, .traps]
        } else if name.contains("lateral raise") || name.contains("front raise") || name.contains("y raise") {
            regions = [.frontSideDelts]
        } else if name.contains("leg extension") {
            regions = [.quads]
        } else if name.contains("adductor") || name.contains("adduction") {
            regions = [.adductors]
        } else if name.contains("abductor") || name.contains("abduction") || name.contains("lateral band walk") || name.contains("monster walk") || name.contains("clamshell") || name.contains("side lying leg raise") {
            regions = [.abductors, .glutes]
        } else if name.contains("leg curl") || name.contains("nordic") {
            regions = [.hamstrings]
        } else if name.contains("curl") {
            regions = name.contains("hammer") || name.contains("rope") || name.contains("reverse")
                ? [.biceps, .forearms]
                : [.biceps]
        } else if (name.contains("tricep") || name.contains("skull") || name.contains("pushdown"))
                    && !name.contains("close grip bench") {
            regions = [.triceps]
        }

        return regions.sorted { $0.rawValue < $1.rawValue }
    }

    static func bodyRegions(for muscleGroups: [MuscleGroup]) -> [BodyRegion] {
        let regions = muscleGroups.flatMap { group -> [BodyRegion] in
            switch group {
            case .chest:
                return [.upperChest, .midLowerChest]
            case .back:
                return [.lats, .traps]
            case .shoulders:
                return [.frontSideDelts]
            case .arms:
                return [.biceps, .triceps]
            case .forearms:
                return [.forearms]
            case .legs:
                return [.quads, .hamstrings]
            case .glutes:
                return [.glutes]
            case .core:
                return [.abs, .obliques, .lowerBack]
            case .traps:
                return [.traps]
            case .lats:
                return [.lats]
            case .calves:
                return [.calves]
            case .neck:
                return []
            }
        }
        return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
    }
}
