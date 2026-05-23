// UNBOUND/Models/LiftTierCriteria.swift
//
// Tier criteria for the 4 barbell main lifts. These do NOT live on the
// skill tree — they're queried directly by lift-specific UI surfaces
// and the same RankService.computeTier method. Spec-locked weight
// thresholds, metric, 10kg increments.
import Foundation

enum LiftTierCriteria {

    /// All 4 lifts keyed by exercise name (space-lowercase per
    /// CatalogExercise.name convention).
    static let table: [String: [SkillTier: TierCriterion]] = [
        "bench press": [
            .initiate:   .weightKg(20),
            .novice:     .weightKg(40),
            .apprentice: .weightKg(60),
            .forged:     .weightKg(80),
            .veteran:    .weightKg(100),
            .honed:      .weightKg(120),
            .vessel:     .weightKg(140),
            .unbound:    .weightKg(160),
            .ascendant:  .weightKg(180)
        ],
        "back squat": [
            .initiate:   .weightKg(40),
            .novice:     .weightKg(60),
            .apprentice: .weightKg(80),
            .forged:     .weightKg(100),
            .veteran:    .weightKg(130),
            .honed:      .weightKg(160),
            .vessel:     .weightKg(180),
            .unbound:    .weightKg(200),
            .ascendant:  .weightKg(220)
        ],
        "deadlift": [
            .initiate:   .weightKg(60),
            .novice:     .weightKg(80),
            .apprentice: .weightKg(100),
            .forged:     .weightKg(130),
            .veteran:    .weightKg(160),
            .honed:      .weightKg(180),
            .vessel:     .weightKg(200),
            .unbound:    .weightKg(220),
            .ascendant:  .weightKg(240)
        ],
        "overhead press": [
            .initiate:   .weightKg(20),
            .novice:     .weightKg(30),
            .apprentice: .weightKg(40),
            .forged:     .weightKg(50),
            .veteran:    .weightKg(60),
            .honed:      .weightKg(70),
            .vessel:     .weightKg(80),
            .unbound:    .weightKg(90),
            .ascendant:  .weightKg(100)
        ]
    ]
}
