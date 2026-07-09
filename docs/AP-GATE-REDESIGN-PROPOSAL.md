# AP · Attributes · Rank Gates — Redesign Proposal

**Status:** DRAFT for checkpoint — no code changed yet. Decisions below are locked
unless marked **[OPEN]**. Numbers in tables are *drafts for tuning*, not final.

**Why this exists:** A review of the rank-gate requirements surfaced that they are
"weirdly organized" and partly unreachable. Tracing it back exposed deeper issues
in how AP/XP is computed and how attributes are fed. This proposal simplifies the
AP economy, fixes attribute feeding, and rebuilds the gate keys so every
requirement is reachable and expresses a player's build.

---

## 0. Mental model (the thing to keep straight)

One atom, three meters:

| Meter | Fed by | Means |
|-------|--------|-------|
| **Overall level** | the **sum of all AP, ever** | how much total work / time-in-game (the grind spine) |
| **Attributes** (6) | each movement's AP **× that movement's attribute weights** | *what* you train — your build |
| **Rank** | performance vs fixed standards (NOT AP volume) | how *strong/capable* you are |

**AP** is the single per-set "you did work" score that feeds the first two. Rank is
separate (standards-based). Keeping these three jobs cleanly separated is the north
star of this redesign.

---

## 1. AP simplification  *(LOCKED)*

### Current formula (too complex)
`AP = base(10) × volume × intensity × RPE × quality × variation`, per set.

| Factor | What it really is | Decision |
|--------|-------------------|----------|
| volume | `log(reps)` / hold / distance — how much you did | **Keep** |
| intensity | est. 1RM ÷ *your own baseline* ^1.5 — per-user overload reward | **Replace** with static value (below) |
| RPE | `0.7 + rpe×0.05`, ±15% — self-reported effort | **Cut** (you grade your own homework) |
| quality | self-reported flags (clean +5%, assisted/partial −25%, pain −50%) | **Cut** as XP input; keep pain/assisted as *safety* flags only |
| variation | flat −20% if movement name contains "assisted/band/negative/eccentric" | **Cut** (brittle name-match, duplicates the quality "assisted" penalty; never had anything to do with body parts) |

### New formula
```
AP = (movement's static value) × (volume)
```
- **Static value** = a fixed number per movement, like a mob's XP drop. A deadlift
  is worth more than a curl; a muscle-up more than a push-up. No per-user math.
- **volume** = log-compressed reps / hold-seconds / distance (keeps "more reps =
  more, but with diminishing returns" so junk volume can't be farmed).
- Predictable, ungameable, no self-reports.
- Getting literally stronger is still rewarded — through **rank**, the meter built
  for it. Level stays a pure "how much have you done" measure.

### Draft movement value buckets *(for tuning)*
Movements are grouped into a few buckets so we set ~5 numbers instead of
hand-pricing 200 movements. No tier-letter jargon — just "bigger/harder = more."
Relative multipliers on a base unit; final numbers TBD at checkpoint.

| Bucket | Examples | Draft value |
|--------|----------|-------------|
| Big lifts & skills | muscle-up, weighted pull-up, planche/lever work, deadlift, back squat, bench | 2.0 |
| Compounds | pull-up, dip, row, overhead press, RDL, lunge, goblet squat | 1.4 |
| Accessories | curl, lateral raise, leg curl, calf raise, face pull | 1.0 |
| Light isolation / mobility | band work, stretch holds, easy isolation | 0.6 |
| Cardio / carry / hold | run, row, bike, carry, plank | by duration/distance, ~compound pace |

### Attributes use the same atom
`attribute XP (axis A) = AP × movement's weight for A`. Simpler AP ⇒ simpler,
predictable attribute gains.

---

## 2. Attribute feeding fixes  *(LOCKED intent, draft weights)*

Curve (unchanged): `attribute XP = 16 × level²`, max L100.
Rank floors (attribute level → XP): Novice 3→144 · Apprentice 6→576 · Forged
10→1,600 · Veteran 15→3,600 · **Master 25→10,000** · Vessel 40→25,600.

### Today's imbalance (measured)
| Attribute | Feeders | Avg weight | Status |
|-----------|---------|-----------|--------|
| power | 169 | 0.44 | healthy |
| control | 165 | 0.41 | healthy |
| endurance | 125 | 0.34 | healthy |
| explosiveness | 63 | **0.18** | fed but diffuse/weak |
| mobility | 12 | 0.21 | thin |
| vitality | **0 movements** | — | fed only by recovery check-ins (slow, 12 XP/day cap) |

### Explosiveness — concentrate, don't smear
- **Heavy (0.7–1.0):** jump squat, kettlebell swing, box jump, broad jump,
  muscle-up, banded muscle-up, chest-to-bar pull-up, power clean, clapping/plyo
  push-up. *Doing explosive work moves the bar.*
- **Light secondary (~0.1–0.15):** heavy low-rep compounds (deadlift, squat,
  bench) get a small slice — not everything, not zero.

### Vitality — finish the abandoned "recovery + conditioning" axis
Vitality already has copy ("Easy walks, deloads, recovery"), a `VitalityCheckIn`
model, a `VowLane.recovery`, and a **live `VitalityRewardPolicy`** (rest-day 6,
deload 8, easy-walk 4, sleep 3, hydration 2; 12/day cap + 15/wk consistency bonus).
It was half-built. Make it a real, *trainable* axis:
- **Add movement feeders:** cardio / conditioning (run, row, bike, intervals) →
  primary vitality (0.6–0.8), with endurance overlap; endurance/high-rep movements
  → small vitality slice (~0.1–0.15). A conditioning build now feeds vitality
  through actual training.
- **Keep the recovery path** (`VitalityRewardPolicy`) as the topping-up bonus.
- **Vow completion → vitality: IMPLEMENTED (guardrail overridden for vitality).**
  All three vow lanes (REST / FUEL / CARDIO) are vitality-flavored, so sealing a vow
  feeds vitality (50 XP, tunable) in `sealVow` — alongside the existing flat win-token
  XP it already grants. The §7 "no attributes" guardrail is overridden **for vitality
  only** (never strength XP/rank) and **only at the seal**, never per self-report tap,
  so the per-tap guardrail stays intact.
- Identity: vitality = the *support / off-the-platform* axis (conditioning,
  work-capacity, recovery, consistency). Distinct from endurance (output under
  load) — keeps both axes meaningful.
- **Retuned check-in values (a bit more generous):** rest-day 6→8, deload 8→12,
  easy-walk 4→6, sleep 3→4, hydration 2→3; daily cap 12→18, weekly bonus 15→25.

### Mobility
Thin (12 feeders). Lower priority, but if any gate key can land on mobility it
needs a few more honest feeders (deep-squat hold, cossack, controlled ROM work).

### Skill attribution (2026-06-18 follow-up — `skillAttributeWeights`)
The skill clusters bucketed *every* calisthenics skill into power/control/endurance
with **zero mobility/explosiveness** (and skill weights override the per-exercise
catalog, so even muscle-ups lost their explosiveness). Fixed:
- **Dynamic skills → explosiveness 0.4** (id contains muscle-up / explosive / clap /
  jump / plyo): muscle-ups, explosive & clapping pulls/pushups, box/jump squats.
- **Extreme-range skills → mobility**: planche 0.25, handstands 0.2, levers/german-hang
  0.25, pistols 0.3. So a calisthenics build now accrues the mobility + explosiveness
  its signature work physically demands. (All sets still sum to 1.0.)
### Endurance concentration (DONE)
Endurance was a passenger on 63% of the catalog → universally Master. **Concentrated
onto conditioning/core/carries/cardio only** (feeders 125 → 40, stripped off strength
lifts), re-normalized. Measured result: **Veteran for low-conditioning builds
(calisthenics/beginner/travel ~L24), Master only for high-cardio builds (gym/strength/cut
L28–32)** — it now tracks how much conditioning you do, not total volume.

### Calisthenics mobility/explosiveness — full 3-path fix (DONE)
All three resolution paths now feed mobility/explosiveness consistently:
1. **Skill nodes + skill-drills** — a shared `skillMovementAttributeWeights(forId:)`
   token helper (dynamic → explosiveness 0.4; lever/planche/pistol/shrimp/german-hang →
   mobility 0.3), used by both `skillAttributeWeights(for:)` and `skillDrill(...)`, robust
   to off-theme clusters (levers filed under `.pullingPower`).
2. **Catalogued JSON exercises** — mobility added to pistols/shrimps/levers/planche/pike.
- **Measured result: advanced-calisthenics mobility L8 (Apprentice) → L22 (Veteran).**
  Mobility is now build-differentiated (calisthenics Veteran, strength builds Forged,
  raw beginner Initiate). Explosiveness stays Forged for static-skill calisthenics
  (correct — muscle-ups/explosive pulls would raise it).

**Measurement harness:** `SimAttributeProfileMeasurement` replays the year-sim export
through the real `AttributeCatalog` (skip without `UNBOUND_SIM_EXPORT_JSON`). Caveat:
the export has only strength `mainExercises`, so vitality (cardio-fed) reads 0 there.

---

## 3. Rank-gate keys — rebuild  *(LOCKED shape, draft numbers)*

### Out: keystone exercises
No more "3 / 10 / 15 pull-ups." They over-indexed on pull-ups and pinned the gate
to a single movement.

### In: "any K of your 6 attributes at rank R"
Expresses **builds** — a power/explosiveness specialist clears via their axes, a
conditioning person via endurance/vitality/mobility. K capped at **3** (nobody
needs all six; that's what made the old "every attribute at Master" key
impossible). Reachable floors — never Unbound/maxed.

### Strawman ladder *(react to the K + rank curve)*
| # | Gate | Target rank | **Attribute key** | Level floor |
|---|------|-------------|-------------------|-------------|
| I | First Light | Novice | — (level only) | retune (§4) |
| II | The Count | Apprentice | any **1** @ Novice | retune |
| III | The Forging | Forged | any **1** @ Apprentice | retune |
| IV | Deck of Proof | Veteran | any **2** @ Forged | retune |
| V | The Ascent | Master | any **2** @ Veteran | retune |
| VI | Seven Seals | Vessel | any **3** @ Veteran | retune |
| VII | The Threshold | Ascendant | any **3** @ Master | retune |
| VIII | The Last Gate | Unbound | any **3** @ Master | retune |

- Every gate II→VIII has a real attribute requirement (Deck of Proof included).
- The final gate still structurally requires the **prior 7 gates cleared** (a
  meta-progression check, not an exercise — this is fine to keep).

---

## 4. Overall level floor — KEEP, retuned to an ~18-month arc  *(LOCKED)*

Overall level stays as a gate. **Target: an average 4×/week player reaches the
final gate (L90) in ~18 months**, staying **very cumulative** (later levels cost
progressively more).

**Fix = the curve, not the floors.** The problem was never the floors; it was the
base. Keep the per-gate level floors (1/8/15/22/40/55/72/90) and the quadratic
(cumulative) shape, but drop the base so the ladder is reachable:

> `overall XP = base × level²`, **base 250 → 16**
> **Calibrated by the year-sim (2026-06-18):** average **~416 AP/session** across the
> 7 personas (270 bodyweight-beginner → 548 cut-mode) under the new value × volume AP.

Resulting arc at 4 sessions/week (avg persona):

| Gate | Level | Cumulative XP | ≈ Sessions | ≈ Time |
|------|-------|---------------|-----------|--------|
| II The Count | 8 | 1,025 | 2 | ~first week |
| III The Forging | 15 | 3,600 | 9 | ~2 weeks |
| IV Deck of Proof | 22 | 7,750 | 19 | ~1 month |
| V The Ascent | 40 | 25,600 | 62 | ~3.6 months |
| VI Seven Seals | 55 | 48,400 | 116 | ~6.7 months |
| VII The Threshold | 72 | 83,000 | 200 | ~11.5 months |
| VIII The Last Gate | 90 | 129,700 | 312 | **~18 months** |

Cumulative throughout (each gap bigger than the last). Pace scales with build: a
bodyweight-only beginner (~270 AP/session) reaches the peak in ~28 months; an
advanced/cut trainee (~440–548) in ~14 months; the average lands on 18.

---

## 5. Final gate-requirement stack  *(LOCKED)*

Per gate: **overall-level floor (retuned)** + **"any K attributes at rank R."**

**Accumulated rank is folded out** of the gate. It overlapped with the attribute
key (both = "are you strong enough"), so the attribute key is now the sole strength
check. Accumulated rank **stays as a profile stat** — we just stop gating on it.
`TrialReadinessService.requirementLines` drops the `accumulated-rank` line.

---

## 6. Decisions

**Resolved**
- ✅ **Level pace** — ~18 months to the final gate, very cumulative (§4); fix is the
  curve base (250 → ~3.85), floors unchanged.
- ✅ **Vitality check-in XP** — retuned a bit more generous (§2).
- ✅ **Value buckets** — plain names, not S/A/B/C tier letters (§1).

- ✅ **Accumulated rank** — folded out of the gate; attribute key is the sole
  strength check (§5).

**Still open (tuning, non-blocking — eyeball off the doc anytime)**
1. **Static value bucket numbers** (§1) — tune the 2.0 / 1.4 / 1.0 / 0.6.
2. **K + attribute-rank ladder** (§3) — confirm the strawman (any 1→3 at Novice→Master).

## Implementation status (2026-06-18)

- ✅ **Phase 1–4 implemented; app builds green on sim AND device-arch.**
  - AP = value × volume (`MovementAPCalculator`); classification buckets.
  - Attributes rebalanced (`AttributeContributions.json` + cardio/carry vitality in
    `MovementCatalog+Definitions`); vitality check-ins retuned.
  - Gate keys = any-K-attributes (`GateKeys.swift`); accumulated-rank line dropped
    from `TrialReadinessService`.
  - Level base 250 → 16, **year-sim-calibrated** (~416 AP/session) to the 18mo arc.
- ✅ **Phase 5 (tests) DONE.** Full suite: 1234 tests. Every redesign-touched test
  is green — `GateKeysTests` rewritten to the any-K model; readiness tests updated
  (accumulated-rank line gone, attribute keys cleared); vitality values; explosiveness
  coverage test rewritten for the concentrated design; AttributeContributions
  **re-normalized to sum-to-1** (vitality kept out of strength vectors — fed by
  cardio/carry/recovery/vows); cardio/carry defs re-normalized to sum-to-1.
  - **3 pre-existing failures remain, NOT from this redesign** (verified: I touched
    none of the tested code): `GateCrossingCatalogTests.test_investitureTitleIsDestinationRank`
    ("FORGED." vs displayName), `MovementResolverTests.testProgressionVariantVisualsAreNotExactDuplicateAssets`
    (asset dedup), `ReadmeFreshnessTests.testReadmeTablesMatchDirectoryContents` (scans
    UNBOUND/, my only new file is in docs/). Left for whoever owns the branch/Codex WIP.
- ⚠️ **Dead code to clean (follow-up):** the `GateKeySetRecord` / `matchingRecords`
  set-proof machinery in `WorkoutLogGateKeyHistory` is now unused (no key consults it);
  and `aggregateRank` plumbing into readiness is now unused. Left in place to keep
  Phase 3 contained — remove in a cleanup pass.
- ❓ **Vows → vitality** still blocked on the §7 guardrail (your call).

## 7. Implementation order (post-signoff)

1. AP formula → `MovementAPCalculator` (collapse to value × volume; movement static
   values into `MovementCatalog`). Update tests anchored to the old factors.
2. Attribute weights → `AttributeContributions.json` (explosiveness concentrate,
   vitality movement feeders, mobility top-up). Wire vow → vitality grant.
3. Gate keys → `GateKeys.swift` (remove keystone-exercise keys; add "any-K-attrs"
   metric). Update `TrialReadinessService.requirementLines`.
4. Level curve/floors → `OverallLevelCurve` + `OverallRankTrialDefinitions`
   (`minOverallLevel` per gate).
5. Verify: sim reach-times + `SkillRankConsistencyTests` + full suite green.

## 8. Risks / not-decided

- Pure-volume AP could over-reward junk high-rep work — mitigated by log-compression
  + static values (heavy movements still pay more). Watch in the sim.
- Removing per-user intensity means load progression shows up only in **rank**, not
  level — intended, but a visible behavior change.
- Vitality movement feeders must not just duplicate endurance — keep the weights
  distinct so the two axes stay separate.
- Reach-time numbers (§4) are unverified until the new AP value lands and the sim is
  re-run with attribute/level tracking instrumented.

## Addendum - movement-key retune (2026-07-09)

The gate-key pacing harness (`GateKeyPacingSimulationTests`) showed the `movementsAtRank` keys were non-binding at the top gates: a gym intermediate's experience head start turned "4 @ Master" months before The Threshold's L72 level floor.
Retune: Seven Seals `movements(3, veteran)` → `movements(4, master)`; The Threshold `movements(4, master)` → `movements(5, vessel)`; The Last Gate `movements(4, master)` → `movements(6, vessel)`; every attribute key, the earlier gates' movement keys, and `gatesAnswered(7)` are unchanged.
Requiring Ascendant was rejected as too elite (the harness puts Ascendant-tier lifts at year 4-6 for a dedicated trainee); Vessel keeps the top keys binding but reachable, so the old "capped at Master" rule becomes "capped at Vessel."
The counts only rise because the counted pool widened with them: `gateKeyMovementTiers` now spans all skills plus every loaded movement StrengthStandards ranks (the 6 compounds incl. barbell row, weighted pull-up, and the accessory families - counted one per FAMILY and deduped by canonical identity, tiered by the same `movement_progress` / `MovementProgressTierResolver` computation the rank library shows) instead of skills + the big-4 only.
The cosmetic aggregate (`LiftTierService`, `RankService.aggregateTier`) is untouched - this retune moves trial gating only.
