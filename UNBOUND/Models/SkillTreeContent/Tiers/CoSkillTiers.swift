// UNBOUND/Models/SkillTreeContent/Tiers/CoSkillTiers.swift
//
// Tier criteria for every skill with prefix `co.` (10 skills).
// Conditioning cluster — carries, holds, sprints. See CalSkillTiers.swift
// for the established pattern.
//
// Hold-type skill (dead-hang-60):
//   exercise-scoped .exerciseSeconds("dead hang") ladder — honest grip-hold
//   time (F2). One node ranks the whole endurance spectrum (30→150s).
//
// Farmer carry ladder (bw → 1.5x → 2x):
//   Each rank steps up .exerciseBodyweightRatio for "farmer carry" so a
//   heavy unrelated lift cannot satisfy the ratio check.
//
// Sled push:
//   Same exercise-scoped bodyweight-ratio pattern as farmer carries.
//   The sled push node uses .carry in SkillTreeContent; we proxy via
//   .exerciseBodyweightRatio here because sled load scales exactly like carry load.
//
// Cardio sprints (row, runs, assault bike):
//   .variant(name) for entry tiers proves activity. Upper tiers compound with
//   pull-up volume (general engine marker). These are imperfect proxies —
//   we can't evaluate time/distance from logs today — but they create a
//   believable conditioning ladder that rewards combined effort.

import Foundation

#if DEBUG
private let _coCountCheck: Int = {
    assert(
        CoSkillTiers.table.count == 9,
        "co cluster should have 9 entries, has \(CoSkillTiers.table.count)"
    )
    for (id, tiers) in CoSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return CoSkillTiers.table.count
}()
#endif

enum CoSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - Loaded Carry: Farmer Carry Ladder

        // co.bw-farmer-carry — Farmer Carry at bodyweight total load for 60 s.
        // Lower tiers: variant confirms any carry log.
        // Mid tiers: compound with sub-bw ratio to confirm heavier carry work.
        // Upper tiers: compound with meaningful bodyweight fractions.
        // Forged = the node target (bw load = ratio 1.0 combined across two handles,
        // so each handle is 0.5x bw; we gate the criterion at the combined load).
        "co.bw-farmer-carry": [
            .initiate:   .variant("farmer carry"),
            .novice:     .variant("farmer carry"),
            .apprentice: .exerciseBodyweightRatio(0.25, exerciseName: "farmer carry"),
            .forged:     .exerciseBodyweightRatio(0.50, exerciseName: "farmer carry"),
            .veteran:    .exerciseBodyweightRatio(0.65, exerciseName: "farmer carry"),
            .master:      .exerciseBodyweightRatio(0.75, exerciseName: "farmer carry"),
            .vessel:     .exerciseBodyweightRatio(0.85, exerciseName: "farmer carry"),
            .unbound:    .exerciseBodyweightRatio(0.90, exerciseName: "farmer carry"),
            .ascendant:  .exerciseBodyweightRatio(1.00, exerciseName: "farmer carry"),
        ],

        // co.1.5x-farmer-carry — Heavy Farmer Carry at 1.5× bodyweight for 60 s.
        // Prereq: co.bw-farmer-carry. Lower tiers start from bw carry compound
        // to confirm the prerequisite base; upper tiers push toward the 1.5x mark.
        "co.1.5x-farmer-carry": [
            .initiate:   .exerciseBodyweightRatio(0.75, exerciseName: "farmer carry"),
            .novice:     .exerciseBodyweightRatio(0.85, exerciseName: "farmer carry"),
            .apprentice: .exerciseBodyweightRatio(1.00, exerciseName: "farmer carry"),
            .forged:     .exerciseBodyweightRatio(1.10, exerciseName: "farmer carry"),
            .veteran:    .exerciseBodyweightRatio(1.20, exerciseName: "farmer carry"),
            .master:      .exerciseBodyweightRatio(1.30, exerciseName: "farmer carry"),
            .vessel:     .exerciseBodyweightRatio(1.35, exerciseName: "farmer carry"),
            .unbound:    .exerciseBodyweightRatio(1.40, exerciseName: "farmer carry"),
            .ascendant:  .exerciseBodyweightRatio(1.50, exerciseName: "farmer carry"),
        ],

        // co.2x-farmer-carry — Elite Farmer Carry at 2× bodyweight for 60 s.
        // Keystone node. Cascade through the 1.5x tier and push to 2x.
        "co.2x-farmer-carry": [
            .initiate:   .exerciseBodyweightRatio(1.00, exerciseName: "farmer carry"),
            .novice:     .exerciseBodyweightRatio(1.20, exerciseName: "farmer carry"),
            .apprentice: .exerciseBodyweightRatio(1.40, exerciseName: "farmer carry"),
            .forged:     .exerciseBodyweightRatio(1.50, exerciseName: "farmer carry"),
            .veteran:    .exerciseBodyweightRatio(1.60, exerciseName: "farmer carry"),
            .master:      .exerciseBodyweightRatio(1.70, exerciseName: "farmer carry"),
            .vessel:     .exerciseBodyweightRatio(1.80, exerciseName: "farmer carry"),
            .unbound:    .exerciseBodyweightRatio(1.90, exerciseName: "farmer carry"),
            .ascendant:  .exerciseBodyweightRatio(2.00, exerciseName: "farmer carry"),
        ],

        // MARK: - Loaded Carry: Sled Push

        // co.sled-push — Sled Push at 2× bodyweight for 30 s.
        // Sled load scales like a carry; use .exerciseBodyweightRatio("sled push")
        // compound. Entry tiers confirm sled work exists; upper tiers push toward
        // the 2x node target.
        "co.sled-push": [
            .initiate:   .variant("sled push"),
            .novice:     .variant("sled push"),
            .apprentice: .exerciseBodyweightRatio(0.50, exerciseName: "sled push"),
            .forged:     .exerciseBodyweightRatio(0.75, exerciseName: "sled push"),
            .veteran:    .exerciseBodyweightRatio(1.00, exerciseName: "sled push"),
            .master:      .exerciseBodyweightRatio(1.25, exerciseName: "sled push"),
            .vessel:     .exerciseBodyweightRatio(1.50, exerciseName: "sled push"),
            .unbound:    .exerciseBodyweightRatio(1.75, exerciseName: "sled push"),
            .ascendant:  .exerciseBodyweightRatio(2.00, exerciseName: "sled push"),
        ],

        // MARK: - Grip Engine: Dead Hang

        // co.dead-hang-60 — the single Dead Hang endurance node (prereq
        // pp.dead-hang). Honest exercise-scoped seconds, 30→150s, Forged = 60s.
        // (Collapsed the old 45s/60s split: one node now ranks the whole grip-
        // endurance spectrum by hold-time — F2 made the separate -45 node dead
        // weight.)
        "co.dead-hang-60": [
            .initiate:   .exerciseSeconds(30, exerciseName: "dead hang"),
            .novice:     .exerciseSeconds(40, exerciseName: "dead hang"),
            .apprentice: .exerciseSeconds(50, exerciseName: "dead hang"),
            .forged:     .exerciseSeconds(60, exerciseName: "dead hang"),
            .veteran:    .exerciseSeconds(75, exerciseName: "dead hang"),
            .master:      .exerciseSeconds(90, exerciseName: "dead hang"),
            .vessel:     .exerciseSeconds(105, exerciseName: "dead hang"),
            .unbound:    .exerciseSeconds(120, exerciseName: "dead hang"),
            .ascendant:  .exerciseSeconds(150, exerciseName: "dead hang"),
        ],

        // MARK: - Engine: Rower Sprint

        // co.400m-row — Rower Sprint (400 m, time-capped). Steps-type target;
        // duration and distance not auto-evaluable. Lower tiers: variant confirms
        // any rowing session. Upper tiers compound with pull-up volume as a
        // general pulling-engine marker (rowing and pull-ups share lat + arm
        // recruitment patterns).
        "co.400m-row": [
            .initiate:   .variant("row 400m"),
            .novice:     .variant("row 400m"),
            .apprentice: .variant("row 400m"),
            .forged:     .compound([.variant("row 400m"), .reps(3, exerciseName: "pullup")]),
            .veteran:    .compound([.variant("row 400m"), .reps(5, exerciseName: "pullup")]),
            .master:      .compound([.variant("row 400m"), .reps(8, exerciseName: "pullup")]),
            .vessel:     .compound([.variant("row 400m"), .reps(10, exerciseName: "pullup")]),
            .unbound:    .compound([.variant("row 400m"), .reps(12, exerciseName: "pullup")]),
            .ascendant:  .compound([.variant("row 400m"), .reps(15, exerciseName: "pullup")]),
        ],

        // MARK: - Distance Run: Sub-7 Mile & Sub-22 5K

        // co.mile-sub-7 — Fast Mile (sub-7 min). Steps-type target; pace not
        // auto-evaluable. Lower tiers: variant confirms running. Upper tiers
        // compound with pushup volume — a general aerobic conditioning marker
        // that correlates with sustained output capacity.
        "co.mile-sub-7": [
            .initiate:   .variant("run 1 mile"),
            .novice:     .variant("run 1 mile"),
            .apprentice: .variant("run 1 mile"),
            .forged:     .compound([.variant("run 1 mile"), .reps(10, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("run 1 mile"), .reps(20, exerciseName: "pushup")]),
            .master:      .compound([.variant("run 1 mile"), .reps(30, exerciseName: "pushup")]),
            .vessel:     .compound([.variant("run 1 mile"), .reps(40, exerciseName: "pushup")]),
            .unbound:    .compound([.variant("run 1 mile"), .reps(50, exerciseName: "pushup")]),
            .ascendant:  .compound([.variant("run 1 mile"), .reps(60, exerciseName: "pushup")]),
        ],

        // co.5k-sub-22 — Fast 5K (sub-22 min). Prereq: co.mile-sub-7. Starts
        // from a compound entry confirming both run logging and a minimum pushup
        // base. Upper tiers escalate the pushup count as a sustained-output proxy.
        "co.5k-sub-22": [
            .initiate:   .compound([.variant("run 5k"), .reps(10, exerciseName: "pushup")]),
            .novice:     .compound([.variant("run 5k"), .reps(15, exerciseName: "pushup")]),
            .apprentice: .compound([.variant("run 5k"), .reps(20, exerciseName: "pushup")]),
            .forged:     .compound([.variant("run 5k"), .reps(25, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("run 5k"), .reps(35, exerciseName: "pushup")]),
            .master:      .compound([.variant("run 5k"), .reps(45, exerciseName: "pushup")]),
            .vessel:     .compound([.variant("run 5k"), .reps(55, exerciseName: "pushup")]),
            .unbound:    .compound([.variant("run 5k"), .reps(65, exerciseName: "pushup")]),
            .ascendant:  .compound([.variant("run 5k"), .reps(75, exerciseName: "pushup")]),
        ],

        // MARK: - Engine: Assault Bike Sprint

        // co.assault-bike-30 — Assault Bike Sprint (30 cal sub-60 s). Steps-type
        // target; calorie count not auto-evaluable. Lower tiers: variant confirms
        // any bike session. Upper tiers compound with pushup volume (anaerobic
        // engine proxy — bike and pushup share shoulder + full-body demand) and
        // then pull-up volume at the elite tiers for combined engine confirmation.
        "co.assault-bike-30": [
            .initiate:   .variant("assault bike 30 cal"),
            .novice:     .variant("assault bike 30 cal"),
            .apprentice: .variant("assault bike 30 cal"),
            .forged:     .compound([.variant("assault bike 30 cal"), .reps(10, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("assault bike 30 cal"), .reps(20, exerciseName: "pushup")]),
            .master:      .compound([.variant("assault bike 30 cal"), .reps(30, exerciseName: "pushup")]),
            .vessel:     .compound([.variant("assault bike 30 cal"), .reps(5, exerciseName: "pullup")]),
            .unbound:    .compound([.variant("assault bike 30 cal"), .reps(8, exerciseName: "pullup")]),
            .ascendant:  .compound([.variant("assault bike 30 cal"), .reps(12, exerciseName: "pullup")]),
        ],
    ]
}
