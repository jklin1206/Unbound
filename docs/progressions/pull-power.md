# PULL POWER — Graduated 9-Tier Progression Proposal

**Family:** the hard `pp.*` pulling nodes + `cl.three-sixty-pulls` (pull-related).
**Goal:** every hard skill ranks across its *real* progression — assisted/band/negative lead-ups at the bottom, the first clean strict rep at **Forged**, reps / harder variant at the top — mapped onto the canonical 9 `RankTier`s:

| Ord | RankTier (case) | Display | Band |
|----:|-----------------|---------|------|
| 0 | `.initiate`  | Initiate   | trainee |
| 1 | `.novice`    | Novice     | trainee |
| 2 | `.apprentice`| Apprentice | trainee |
| 3 | `.forged`    | Forged     | trainee — **first clean strict rep anchors here** |
| 4 | `.veteran`   | Veteran    | named |
| 5 | `.master`    | Master     | named |
| 6 | `.vessel`    | Vessel     | crown |
| 7 | `.unbound`   | **Ascendant** | crown (displayName flip — see SkillTier.swift) |
| 8 | `.ascendant` | **Unbound** | crown — peak |

> Display flip is load-bearing: case `.unbound` renders "Ascendant", case `.ascendant` renders "Unbound" (peak). Tables below label by **display name** for human readability; the case-name maps by ordinal.

This is a **proposal only** — no Swift was modified. Criteria shapes reference the live `TierCriterion` enum (`.reps(n, exerciseName:)`, `.variant(name)`, `.exerciseBodyweightRatio(r, exerciseName:)`, `.compound([...])`) so any adopted ladder is drop-in for `PpSkillTiers.table`.

---

## STEP 1 — In-tree inventory (the hard `pp.*` nodes + 360 pulls)

Pulled from `UNBOUND/Models/SkillTreeContent.swift` (node defs) and `UNBOUND/Models/SkillTreeContent/Tiers/PpSkillTiers.swift` (current tier criteria). Node `tier` = the old graph-depth Int (1–8), **not** a RankTier. `rank` = the legacy E…S letter grade.

| Node id | Title | tier | rank | target | prereqs | Mythic/Keystone |
|---|---|---|---|---|---|---|
| `pp.muscle-up` | Muscle-Up | 6 | A | reps "muscle-up" ×1 | `pp.explosive-pullup` | Keystone |
| `pp.ring-muscle-up` | Ring Muscle-Up | 7 | A | reps "ring muscle-up" ×1 | `pp.muscle-up` | — |
| `pp.strict-muscle-up` | Strict Muscle-Up | 8 | S | reps "strict muscle-up" ×1 | `pp.ring-muscle-up` | **Mythic** |
| `pp.one-arm-pullup` | One-Arm Pull-Up | 8 | S | reps "one-arm pullup" ×1 | `pp.oap-negative` | **Mythic** |
| `pp.oap-negative` | One-Arm Pull-Up Negative | 7 | A | reps "one-arm pullup negative" ×3 | `pp.archer-pullup` | — |
| `pp.one-arm-chin-up` | One-Arm Chin-Up | 8 | S | reps "one-arm chin-up" ×1 | `pp.heighted-chin-up` | **Mythic** |
| `pp.archer-pullup` | Archer Pull-Up | 6 | B | reps "archer pullup" ×3 | `pp.weighted-pullup` | parallel |
| `pp.clapping-pullup` | Clapping Pull-Up | 6 | A | reps "clapping pullup" ×1 | `pp.explosive-pullup` | — |
| `pp.weighted-chin-up` | Weighted Chin-Up | 5 | B | weightMult "weighted chin-up" ×0.5 | `pp.strict-chin-up` | — |
| `pp.heighted-chin-up` | Heighted Chin-Up | 7 | A | reps "heighted chin-up" ×3 | `pp.weighted-chin-up` | — |
| `cl.three-sixty-pulls` | 360-Degree Pulls | 6 | A | reps "360-degree pulls" ×1 | `cl.skin-the-cat` | — |

**Supporting / lead-up nodes already in the tree** (these become the *low-tier rungs* of the ladders above):

| Node id | Title | Role as a bridge |
|---|---|---|
| `pp.dead-hang` / `pp.dead-hang-30` | Dead Hang | grip gate (MU & OAP readiness) |
| `pp.pullup`, `pp.strict-pullup` (Keystone) | Pull-Up / Strict Pull-Up | base volume gate |
| `pp.chin-up`, `pp.strict-chin-up` | Chin-Up | supinated base for OAC |
| `pp.weighted-pullup` | Weighted Pull-Up | the OAP strength on-ramp (sweeps 0.1→1.0× bw) |
| `pp.explosive-pullup` | Explosive Pull-Up | hands-leave-bar power — MU bridge |
| `pp.chest-to-bar` | Chest-to-Bar Pull-Up | the MU height bridge (pull above chin) |
| `pp.archer-pullup`, `pp.typewriter-pullup` | Archer / Typewriter | unilateral-bias OAP bridges |
| `cal.5-dips` (cal cluster) | Dip | the press half of the muscle-up |

### What intermediate progression already exists vs. what's missing

- **`pp.muscle-up` is the one node that already ships a graduated form-bridge ladder** in `PpSkillTiers`: Initiate = 5 pullups + 5 straight-bar dips, Novice = 3 C2B + dip, Apprentice = 3 banded MU + low-bar transition, Forged = first rep. This is the pattern jlin wants every hard node to follow.
- Every **other** hard node uses a flat single-exercise rep ramp (`reps 1→N` of the *target* exercise). That means the bottom tiers are unreachable until you already own the skill — there is no assisted/band/negative on-ramp inside the ladder. Those are the build-outs below.
- Bridge *exercises* mostly exist as their own nodes (`explosive-pullup`, `chest-to-bar`, `archer-pullup`, `typewriter-pullup`, `weighted-pullup`, `oap-negative`) — but they are **not referenced as low-tier criteria** of the hard skills they feed. The proposal wires them in via `.compound`/`.variant`.

---

## STEP 2 — Canonical progressions (cited)

**Muscle-up — the form/technique bridge holds even at 10+ pull-ups.** Raw pulling volume is not the gate; explosive *height* + transition technique + false grip are. Canonical bridge: pull-up strength + negatives → 5–10 **strict chest-to-bar** (pull above the sternum, not the chin) → **false grip** drills → **explosive/high pull-ups** → **transition drills** (low-bar / box-assisted / feet-assisted "snap to support") → **band-assisted muscle-up** → **negative muscle-up** (support → slow lower) → first strict rep → reps. A strict bar MU also wants ~5 full-ROM dips for the press-out. [TrainHeroic 10-step]; [Bodyweight Training Arena — strict bar MU]; [Rubberbanditz — false grip]; [Maximum Potential — slow MU needs 10 strict C2B].

**One-arm pull-up — 16 graded levels (Hooper's Beta).** standard → narrow → wide → **archer** → **typewriter** → **weighted narrow-grip** → **towel-assisted** (first real one-arm mechanics) → **2-arm-up / 1-arm hold** (assisted, ≤15 s) → 2-arm-up/1-arm hold unassisted → **2-arm-up / 1-arm eccentric** (5-second tempo) with band → unassisted one-arm negative → **band-assisted high-grip 1-arm** (heavy→light band) → band-by-side 1-arm → **full one-arm pull-up** → (elite reps). [Hooper's Beta — 16 levels]. Strength readiness benchmark: a weighted two-arm pull-up around **+50% bodyweight** (some coaches cite 3×3 @ +50%, up to +66%) signals OAP readiness; one clean OAC ≈ a two-arm chin with +~66% bw added. [Liftoff / StrongFirst / LegendaryStrength].

**One-arm CHIN-up is ~one notch easier** than the one-arm pull-up (supinated grip recruits biceps harder), so its ladder is shifted down vs. OAP and uses the chin/supinated bridges (heighted chin-up, weighted chin-up). [Hooper's Beta / NinjaWarriorX OAP-vs-OAC]; matches the in-tree `pp.one-arm-chin-up` prereq on `pp.heighted-chin-up`.

**Archer → assisted-one-arm sub-chain** (jlin's spec): archer pull-up → assisted one-arm (band, start ~30% bw) → one-arm negative (5 s) → assisted one-arm (lighter band) → full; reps within each rung. [PrimalStride / Hybrid Athlete / Hooper's Beta].

---

## STEP 3 — Proposed graduated 9-tier ladders

Convention: **Forged = first clean strict rep of the named skill.** Initiate–Apprentice = the assisted/band/negative/lead-up you can already do. Veteran–Unbound[peak] = reps or a harder variant. "Existing" = criterion already in `PpSkillTiers`; "**NEW**" = proposed change/addition.

### `pp.muscle-up` — Muscle-Up (Keystone, A)
*Already graduated — proposal only tightens the bridge labels. Keep as the template.*

| RankTier (display) | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | strict pull-up + dip base | 5 pullup **&** 5 straight-bar dip | Existing |
| Novice | chest-to-bar + dip | 3 C2B pullup **&** dip logged | Existing |
| Apprentice | banded MU + transition drill | 3 banded muscle-up **&** low-bar MU transition | Existing |
| Forged | **first muscle-up** | 1 muscle-up | Existing |
| Veteran | muscle-up | 2 muscle-up | Existing |
| Master | muscle-up | 5 muscle-up | Existing |
| Vessel | muscle-up | 8 muscle-up | Existing |
| Ascendant (`.unbound`) | muscle-up | 10 muscle-up | Existing |
| Unbound (`.ascendant`, peak) | muscle-up | 12 muscle-up | Existing |

> Optional refinement: insert an explicit **explosive/high pull-up** check at Novice (`reps 3 "explosive pullup"`) and a **negative muscle-up** at Apprentice to mirror the canonical "snap to support" bridge. NEW (optional).

### `pp.ring-muscle-up` — Ring Muscle-Up (A)
*Currently flat 1→12. Proposal adds false-grip + bar-MU + transition on-ramp.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | bar muscle-up owned | 1 muscle-up | **NEW** |
| Novice | false-grip ring pull / row | 5 false-grip ring row (`variant "false grip ring row"`) | **NEW** |
| Apprentice | banded ring MU + ring transition | 3 banded ring muscle-up | **NEW** |
| Forged | **first ring muscle-up** | 1 ring muscle-up | Existing(4→1) |
| Veteran | ring muscle-up | 3 ring muscle-up | NEW (was 5) |
| Master | ring muscle-up | 5 ring muscle-up | Existing |
| Vessel | ring muscle-up | 8 ring muscle-up | Existing |
| Ascendant | ring muscle-up | 10 ring muscle-up | Existing |
| Unbound (peak) | ring muscle-up | 12 ring muscle-up | Existing |

### `pp.strict-muscle-up` — Strict Muscle-Up (Mythic, S)
*Currently 1→8 of the strict MU itself — unreachable bottom. Proposal: kipping/regular MU + 10 strict C2B + slow-MU bridge below Forged.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | regular (hip-assisted) muscle-up | 3 muscle-up | **NEW** |
| Novice | strict chest-to-bar (above sternum) | 5 chest-to-bar pullup | **NEW** |
| Apprentice | strict C2B + slow/negative MU | 10 C2B **&** 1 negative muscle-up | **NEW** |
| Forged | **first strict muscle-up** | 1 strict muscle-up | Existing(3→1) |
| Veteran | strict muscle-up | 2 strict muscle-up | NEW |
| Master | strict muscle-up | 3 strict muscle-up | NEW |
| Vessel | strict muscle-up | 5 strict muscle-up | NEW |
| Ascendant | strict muscle-up | 6 strict muscle-up | NEW |
| Unbound (peak) | strict muscle-up | 8 strict muscle-up | Existing |

### `pp.one-arm-pullup` — One-Arm Pull-Up (Mythic, S)
*Currently 1→10 OAP (Initiate already demands the move). Proposal seats the Hooper's Beta bridge below Forged.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | weighted pull-up @ ~50% bw + archer | `exerciseBodyweightRatio 0.5 "weighted pullup"` **&** 5 archer pullup | **NEW** |
| Novice | typewriter + 1-arm flexed hang | 3 typewriter pullup | **NEW** |
| Apprentice | assisted one-arm (band) + 1-arm negative | 3 one-arm pullup negative | **NEW** (was 2 OAP) |
| Forged | **first one-arm pull-up** | 1 one-arm pullup | Existing(3→1) |
| Veteran | one-arm pull-up | 2 one-arm pullup | NEW |
| Master | one-arm pull-up | 3 one-arm pullup | NEW |
| Vessel | one-arm pull-up | 4 one-arm pullup | NEW |
| Ascendant | OAP reps + weighted base | 6 OAP **&** 0.5× weighted pullup | NEW |
| Unbound (peak) | OAP reps + weighted base | 8 OAP **&** 0.75× weighted pullup | Existing(10) |

### `pp.oap-negative` — One-Arm Pull-Up Negative (A)
*The bridge node itself. Currently 1→12 negatives. Proposal seats archer/typewriter below the first slow negative and keeps reps on top.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | archer pull-up | 3 archer pullup | **NEW** |
| Novice | typewriter pull-up | 3 typewriter pullup | **NEW** |
| Apprentice | assisted one-arm negative (band, fast) | 1 one-arm pullup negative | NEW (was 3) |
| Forged | **first 5s one-arm negative** | 3 one-arm pullup negative | Existing(4) |
| Veteran | one-arm negative | 4 one-arm pullup negative | Existing(5) |
| Master | one-arm negative | 5 one-arm pullup negative | Existing(6) |
| Vessel | one-arm negative | 6 one-arm pullup negative | Existing(7) |
| Ascendant | one-arm negative | 8 one-arm pullup negative | NEW(9) |
| Unbound (peak) | one-arm negative | 10 one-arm pullup negative | NEW(12) |

### `pp.one-arm-chin-up` — One-Arm Chin-Up (Mythic, S)
*Supinated ≈ one notch easier than OAP. Uses chin-side bridges (heighted/weighted chin-up).*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | heighted chin-up + weighted chin ~0.5× bw | 3 heighted chin-up | **NEW** |
| Novice | archer chin-up | 3 archer chin-up (`variant`) | **NEW** |
| Apprentice | one-arm chin negative (5s) | 3 one-arm chin-up negative (`variant`) | **NEW** (was 2 OAC) |
| Forged | **first one-arm chin-up** | 1 one-arm chin-up | Existing(3→1) |
| Veteran | one-arm chin-up | 2 one-arm chin-up | NEW |
| Master | one-arm chin-up | 3 one-arm chin-up | NEW |
| Vessel | one-arm chin-up | 4 one-arm chin-up | NEW |
| Ascendant | one-arm chin-up | 6 one-arm chin-up | NEW(7) |
| Unbound (peak) | one-arm chin-up | 8 one-arm chin-up | Existing |

### `pp.archer-pullup` — Archer Pull-Up (B) — the OAP on-ramp
*Currently 1→15. Mild seating of band-archer + strict-pullup base below Forged.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | strict pull-up base | 5 pullup | **NEW** (was 1 archer) |
| Novice | wide pull-up | 5 wide pullup | **NEW** (was 2) |
| Apprentice | archer (banded/partial) | 3 archer pullup | Existing(3) |
| Forged | **first clean archer** | 4 archer pullup | Existing |
| Veteran | archer pull-up | 5 archer pullup | Existing |
| Master | archer pull-up | 7 archer pullup | Existing |
| Vessel | archer pull-up | 9 archer pullup | Existing |
| Ascendant | archer pull-up | 12 archer pullup | Existing |
| Unbound (peak) | archer pull-up | 15 archer pullup | Existing |

### `pp.clapping-pullup` — Clapping Pull-Up (A)
*Currently 1→12. Seat explosive-pullup power below the first clap.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | explosive pull-up | 3 explosive pullup | **NEW** (was 1 clap) |
| Novice | high pull-up (chest past bar) | 5 explosive pullup | **NEW** (was 2) |
| Apprentice | chest-to-bar volume | 5 chest-to-bar pullup | **NEW** (was 3) |
| Forged | **first clapping pull-up** | 1 clapping pullup | Existing(4→1) |
| Veteran | clapping pull-up | 3 clapping pullup | NEW(5) |
| Master | clapping pull-up | 5 clapping pullup | NEW(6) |
| Vessel | clapping pull-up | 7 clapping pullup | Existing |
| Ascendant | clapping pull-up | 9 clapping pullup | Existing |
| Unbound (peak) | clapping pull-up | 12 clapping pullup | Existing |

### `pp.weighted-chin-up` — Weighted Chin-Up (B)
*Already a graduated load ramp (`variant` → ratios 0.10→1.0×). Keep — it is already the model for a weighted ladder. No change needed.*

| RankTier | Variant / exercise | Criterion | Status |
|---|---|---|---|
| Initiate | weighted chin-up (any load) | `variant "weighted chin-up"` | Existing |
| Novice | +0.10× bw | ratio 0.10 | Existing |
| Apprentice | +0.15× bw | ratio 0.15 | Existing |
| Forged | **+0.25× bw clean** | ratio 0.25 | Existing |
| Veteran | +0.35× bw | ratio 0.35 | Existing |
| Master | +0.50× bw | ratio 0.50 | Existing |
| Vessel | +0.65× bw | ratio 0.65 | Existing |
| Ascendant | +0.80× bw | ratio 0.80 | Existing |
| Unbound (peak) | +1.0× bw | ratio 1.00 | Existing |

### `pp.heighted-chin-up` — Heighted Chin-Up (A) — collarbones-to-bar
*Currently 1→12. Seat weighted/strict-chin base below the first sternum-clear rep.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | strict chin-up volume | 8 chin-up | **NEW** (was 1) |
| Novice | weighted chin-up ~0.35× bw | ratio 0.35 "weighted chin-up" | **NEW** (was 2) |
| Apprentice | chest-to-bar chin | 5 chest-to-bar pullup | **NEW** (was 3) |
| Forged | **first heighted chin-up** | 3 heighted chin-up | Existing(4→3 to land first-rep band) |
| Veteran | heighted chin-up | 4 heighted chin-up | Existing(5) |
| Master | heighted chin-up | 6 heighted chin-up | Existing |
| Vessel | heighted chin-up | 7 heighted chin-up | Existing |
| Ascendant | heighted chin-up | 9 heighted chin-up | Existing |
| Unbound (peak) | heighted chin-up | 12 heighted chin-up | Existing |

### `cl.three-sixty-pulls` — 360-Degree Pulls (A, pull-related)
*Not yet in `PpSkillTiers` (prefix `cl` → ClSkillTiers; verify it has an entry). Pure power+spatial skill — bridge is explosive/clapping pulls + release drills.*

| RankTier | Variant / exercise | Reps / criterion | Status |
|---|---|---|---|
| Initiate | explosive pull-up | 5 explosive pullup | **NEW** |
| Novice | clapping pull-up | 1 clapping pullup | **NEW** |
| Apprentice | clapping pull-up + release/180 drill | 3 clapping pullup | **NEW** |
| Forged | **first 360 pull** | 1 360-degree pulls | **NEW** |
| Veteran | 360 pulls | 2 360-degree pulls | **NEW** |
| Master | 360 pulls | 3 360-degree pulls | **NEW** |
| Vessel | 360 pulls | 4 360-degree pulls | **NEW** |
| Ascendant | 360 pulls | 5 360-degree pulls | **NEW** |
| Unbound (peak) | 360 pulls | 6 360-degree pulls | **NEW** |

---

## STEP 4 — Gaps & biggest build-outs

1. **Bridge exercises need catalog entries before criteria can reference them.** The `.variant`/`.reps` shapes above introduce exercise names that may not exist in `CatalogExercise`: `banded ring muscle-up`, `false grip ring row`, `negative muscle-up`, `archer chin-up`, `one-arm chin-up negative`, `360 release/180 drill`. **Largest build-out** — without these the bottom tiers silently never match (the "won't count" path). Audit `MovementCatalog` / `ExerciseLibraryItem` and add missing names (space-lowercase per `TierCriterion.swift` rule).

2. **`cl.three-sixty-pulls` likely has no `ClSkillTiers` ladder.** It is in the `cl` prefix (routes to `ClSkillTiers.table`) but is pull-flavored. Needs a brand-new 9-tier entry (table above) — otherwise it falls through to `[:]` and the `#if DEBUG` count assert / `SkillTreeCoverageGateTests` will flag it.

3. **The `#if DEBUG` invariant in `PpSkillTiers.swift` hard-codes `count == 38` and 9 tiers each.** Any node moving cluster, or adding 360-pulls to `pp`, breaks the assert. Editing existing entries is safe; adding/removing rows requires updating the count.

4. **Forged-anchor drift on the three mythic S-tiers** (OAP, OAC, strict-MU). Today Initiate already requires the finished move (1 rep), so the bottom 3 tiers are dead. The proposal reseats Initiate–Apprentice onto real bridges — this is the highest-value behavioral change (makes the ladder *climbable* before the skill is owned) but also the most criteria churn.

5. **Compound-criterion cost.** Several proposed rungs use `.compound([...])` (e.g. OAP Initiate = weighted-ratio AND archer reps). Confirm `TierCriterionEvaluator` AND-semantics + the placement engine handle compound at low tiers the way the muscle-up ladder already proves it does.

6. **Display-name flip is a documentation trap, not a code one.** Tables here label rows by display name (Ascendant = `.unbound`, Unbound = `.ascendant`). Whoever transcribes to Swift must key by **case name**, not label, or the top two tiers invert.

---

## Sources

- [TrainHeroic — 10 Bar Muscle-Up Progressions](https://www.trainheroic.com/blog/bar-muscle-up-progression/)
- [Bodyweight Training Arena — Achieve a Strict Bar Muscle-Up](https://bodyweighttrainingarena.com/how-to-achieve-a-strict-bar-muscle-up/)
- [Maximum Potential Calisthenics — The Slow Muscle-Up (10 strict C2B minimum)](https://www.mpcalisthenics.com/tutorial/the-slow-muscle-up-how-to-conquer-one-of-the-most-difficult-muscle-ups)
- [Rubberbanditz — Why a False Grip Is Critical for Muscle-Ups](https://www.rubberbanditz.com/blog/false-grip-for-muscle-ups/)
- [Calisthenics Hub — Muscle-Up Progression (band/explosive/negative)](https://www.calishub.com/blog/muscle-up-progression-how-to-transition-from-pull-ups-to-muscle-ups)
- [Hooper's Beta — One-Arm Pull-Up in 16 Levels](https://www.hoopersbeta.com/library/one-arm-pull-up-progressions)
- [PrimalStride — One-Arm Pull-Up Progression (band ~30% bw, archer, negative)](https://primalstride.com/one-arm-pull-up-progression/)
- [The Hybrid Athlete — One-Arm Pull-Up Progression](https://thehybridathlete.com/one-arm-pull-up-progression/)
- [NinjaWarriorX — One-Arm Pull-Up / Chin-Up (supinated easier)](https://www.ninjawarriorx.com/one-arm-pull-up-one-arm-chin-up-progression/)
- [Liftoff — Weighted Pull-Up Standards](https://liftoffrank.com/blog/weighted-pull-up-standards)
- [StrongFirst forum — One-Arm Pull-Up Progression (3×3 @ +50% bw)](https://www.strongfirst.com/community/threads/one-arm-pull-up-progression.8158/page-2)
- [LegendaryStrength — Chin-ups: Two Arm vs One Arm vs Weighted (OAC ≈ +66% bw)](https://legendarystrength.com/chinups-two-arm-one-arm-weighted/)

*In-repo:* `UNBOUND/Models/SkillTreeContent.swift`, `UNBOUND/Models/SkillTreeContent/Tiers/PpSkillTiers.swift`, `UNBOUND/Models/SkillTier.swift` (RankTier + display flip), `UNBOUND/Models/TierCriterion.swift` (criterion shapes).
