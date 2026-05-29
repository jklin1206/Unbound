# CHECKPOINT — PULL-POWER family reseat audit

**Read-only audit. No Swift modified.** Pairs with `docs/progressions/pull-power.md` (the proposal) and `PpSkillTiers.swift` (current tables). Goal of the family pass: every hard `pp.*` skill ranks across its *real* graduated progression (assisted/band/variant/bridge rungs at Initiate–Apprentice, first clean rep at **Forged**, reps/harder variant above), like `pp.muscle-up` already does.

Tier ordinals: `0 initiate · 1 novice · 2 apprentice · 3 forged · 4 veteran · 5 master · 6 vessel · 7 unbound→"Ascendant" · 8 ascendant→"Unbound"(peak)`. Author by **case**, render by displayName (flip is load-bearing — do not touch).

---

## How "won't count" actually works here (matcher mechanics — read first)

The "silent never-match" trap is **narrower** than "name not in `MovementCatalog`". Resolution path: `TierCriterionEvaluator` → `MovementProofMatcher.entry` → `movementMatches`:

1. **Exact normalized-string match wins first** (`MovementProofMatcher.swift:42`). Any token matches a logged set whose name normalizes identically.
2. **Regression-term guard** (`:46`, `regressionTerms = assisted, band, banded, machine, negative, jumping, eccentric, partial`): if the *logged* name contains one of these and the *required* name does not, it is **blocked even if movementIds match**. → A criterion that *names* the regression (e.g. `"one-arm pullup negative"`, `"banded muscle-up"`) is fine; a criterion that names the clean skill can never be proven by a banded/assisted/negative log. Good for strictness, but means every assisted/band/negative bridge rung **must name the regression explicitly**.
3. **MovementId match** via `MovementResolver.resolve`. A token resolves to a real movementId iff it's in `MovementCatalog.aliasIndex`, which is built from: `ExerciseCatalog.allExercises` (canonical + displayName + hand-aliases), cardio/carry/mobility/drill defs, **and every live `SkillGraph.shared.nodes` target/criterion name** (`skillTreeAliases` self-registers each tierCriteria exerciseName as an alias of its own node — `MovementCatalog.swift:1514`). Anything else → `movementId = "unresolved.<slug>"`.

**Consequence — the real B1 rule:** a token is *safely loggable/provable* iff it is (a) a real `ExerciseCatalog` exercise, **or** (b) the target/criterion of a **live** SkillGraph node (self-registers). A token that lives **only in an orphan tier table** (table key with no live node) does **NOT** self-register and, if it's also not a catalog exercise, resolves to `unresolved.*` → only matchable by logging that exact raw string. New proposed bridge names that are neither catalog nor live-node targets are the blockers.

---

## Per-node audit

Legend: **C** = current criterion; tier shown by display name. "Flat ramp" = `1→N reps of the target itself` with no assisted/variant on-ramp (the problem). Proposed rows are **PROPOSED — jlin to refine.**

### `pp.muscle-up` — Muscle-Up (Keystone, A) — ✅ TEMPLATE, already graduated
| tier | current criterion |
|---|---|
| Initiate | compound[ reps 5 `pullup`, reps 5 `straight bar dip` ] |
| Novice | compound[ reps 3 `chest-to-bar pullup`, variant `straight bar dip` ] |
| Apprentice | compound[ reps 3 `banded muscle-up`, variant `low-bar muscle-up transition` ] |
| Forged | reps 1 `muscle-up` |
| Veteran→peak | reps 2 / 5 / 8 / 10 / 12 `muscle-up` |

**Diagnosis:** graduated bridge already seated; first rep at Forged. Keep as the pattern. All tokens resolve (`straight bar dip`, `chest-to-bar pullup`, `banded muscle-up`, `low-bar muscle-up transition`, `muscle-up` are all real catalog exercises). Optional refinement in proposal (explosive-pullup at Novice, negative MU at Apprentice) — negative MU is a **B1 blocker token** (see below).

### `pp.ring-muscle-up` — Ring Muscle-Up (A) — ❌ FLAT RAMP
| tier | current |
|---|---|
| Initiate→Apprentice | reps 1 / 2 / 3 `ring muscle-up` |
| Forged | reps 4 `ring muscle-up` (Forged is *4 reps*, not first rep) |
| Veteran→peak | 5 / 6 / 8 / 10 / 12 `ring muscle-up` |
**Diagnosis:** flat; bottom 3 tiers demand you already own the ring MU; Forged mis-anchored at 4 reps. **Proposed reseat:** Initiate = reps 1 `muscle-up` (bar MU owned) · Novice = variant `false grip ring row` **[B1]** · Apprentice = reps 3 `banded ring muscle-up` **[B1]** · **Forged = reps 1 `ring muscle-up`** · Vet→peak 3/5/8/10/12.

### `pp.strict-muscle-up` — Strict Muscle-Up (Mythic, S) — ❌ FLAT + dead bottom
| tier | current |
|---|---|
| Initiate | reps 1 `strict muscle-up` |
| Novice | reps 1 `strict muscle-up` (Init==Nov — dead tier) |
| Apprentice→peak | 2 / 3(Forged) / 4 / 5 / 6 / 7 / 8 `strict muscle-up` |
**Diagnosis:** Initiate already demands the finished mythic move; Init==Nov flat. **Proposed:** Initiate = reps 3 `muscle-up` · Novice = reps 5 `chest-to-bar pullup` · Apprentice = compound[ reps 10 `chest-to-bar pullup`, reps 1 `negative muscle-up` **[B1]** ] · **Forged = reps 1 `strict muscle-up`** · Vet→peak 2/3/5/6/8.

### `pp.one-arm-pullup` — One-Arm Pull-Up (Mythic, S) — ❌ FLAT + dead bottom
| tier | current |
|---|---|
| Initiate | reps 1 `one-arm pullup` |
| Novice | reps 1 `one-arm pullup` (Init==Nov — dead) |
| Apprentice→Vessel | 2 / 3(Forged) / 4 / 5 / 6 `one-arm pullup` |
| Unbound | compound[ reps 8 `one-arm pullup`, ratio 0.5 `weighted pullup` ] |
| Ascendant(peak) | compound[ reps 10 `one-arm pullup`, ratio 0.75 `weighted pullup` ] |
**Diagnosis:** bottom 3 unreachable until OAP owned. **Proposed:** Initiate = compound[ ratio 0.5 `weighted pullup`, reps 5 `archer pullup` ] · Novice = reps 3 `typewriter pullup` **[B1 — see note]** · Apprentice = reps 3 `one-arm pullup negative` · **Forged = reps 1 `one-arm pullup`** · Vet→peak as today.

### `pp.oap-negative` — One-Arm Pull-Up Negative (A) — ⚠️ FLAT (it's the bridge itself)
| tier | current |
|---|---|
| Initiate→Master | 1 / 2 / 3 / 4(Forged) / 5 / 6 `one-arm pullup negative` |
| Vessel→peak | 7 / 9 / 12 `one-arm pullup negative` |
**Diagnosis:** acceptable as a bridge node, but the proposal wants archer/typewriter below the first slow negative. **Proposed:** Initiate = reps 3 `archer pullup` · Novice = reps 3 `typewriter pullup` **[B1]** · Apprentice = reps 1 `one-arm pullup negative` · **Forged = reps 3 `one-arm pullup negative`** · Vet→peak 4/5/6/8/10.

### `pp.one-arm-chin-up` — One-Arm Chin-Up (Mythic, S) — ❌ FLAT + dead bottom
| tier | current |
|---|---|
| Initiate | reps 1 `one-arm chin-up` |
| Novice | reps 1 `one-arm chin-up` (Init==Nov — dead) |
| Apprentice→peak | 2 / 3(Forged) / 4 / 5 / 6 / 7 / 8 `one-arm chin-up` |
**Diagnosis:** bottom 3 unreachable. **Proposed:** Initiate = reps 3 `heighted chin-up` · Novice = reps 3 `archer chin-up` **[B1]** · Apprentice = reps 3 `one-arm chin-up negative` **[B1]** · **Forged = reps 1 `one-arm chin-up`** · Vet→peak 2/3/4/6/8.

### `pp.archer-pullup` — Archer Pull-Up (B) — ⚠️ MILD (Forged not first-rep)
| tier | current |
|---|---|
| Initiate→Apprentice | 1 / 2 / 3 `archer pullup` |
| Forged | reps 4 `archer pullup` |
| Vet→peak | 5 / 7 / 9 / 12 / 15 `archer pullup` |
**Diagnosis:** climbable (it's a B-tier on-ramp) but Forged anchors at 4 reps not first clean rep. **Proposed:** Initiate = reps 5 `pullup` · Novice = reps 5 `wide pullup` · Apprentice = reps 3 `archer pullup` · **Forged = reps 4 `archer pullup`** (proposal keeps 4 = first *clean* archer). All tokens resolve.

### `pp.clapping-pullup` — Clapping Pull-Up (A) — ❌ FLAT (Forged=4 reps)
| tier | current |
|---|---|
| Initiate→Apprentice | 1 / 2 / 3 `clapping pullup` |
| Forged | reps 4 `clapping pullup` |
| Vet→peak | 5 / 6 / 7 / 9 / 12 `clapping pullup` |
**Diagnosis:** flat; first clap demanded at Initiate. **Proposed:** Initiate = reps 3 `explosive pullup` · Novice = reps 5 `explosive pullup` · Apprentice = reps 5 `chest-to-bar pullup` · **Forged = reps 1 `clapping pullup`** · Vet→peak 3/5/7/9/12. All tokens resolve.

### `pp.heighted-chin-up` — Heighted Chin-Up (A) — ❌ FLAT (Forged=4 reps)
| tier | current |
|---|---|
| Initiate→Apprentice | 1 / 2 / 3 `heighted chin-up` |
| Forged | reps 4 `heighted chin-up` |
| Vet→peak | 5 / 6 / 7 / 9 / 12 `heighted chin-up` |
**Diagnosis:** flat. **Proposed:** Initiate = reps 8 `chin-up` · Novice = ratio 0.35 `weighted chin-up` · Apprentice = reps 5 `chest-to-bar pullup` · **Forged = reps 3 `heighted chin-up`** · Vet→peak 4/6/7/9/12. All tokens resolve.

### `pp.weighted-chin-up` — Weighted Chin-Up (B) — ✅ GRADUATED LOAD RAMP (keep)
Initiate variant `weighted chin-up` → ratios 0.10/0.15/**0.25 (Forged)**/0.35/0.50/0.65/0.80/1.00 `weighted chin-up`. **Diagnosis:** already the load-ramp model. No change. Resolves.

### `pp.dead-hang` / `pp.dead-hang-30` — Grip gate — ✅ GRADUATED (compound)
variant `dead hang` ×3, then compound[ variant `dead hang`, reps N `pullup` ] climbing 3→15. **Diagnosis:** fine. NOTE duration not tracked here — comment says holds aren't measured; with Foundation 2 (`durationSeconds` now real) jlin may want `.seconds(30)` at Forged for `pp.dead-hang-30`. **Decision flag.**

### `pp.pullup` / `pp.strict-pullup` / `pp.5-pullups` / `pp.10-pullups` — volume ladders — ✅ OK
Rep ramps on `pullup`. These are volume nodes, not "hard skills"; flat-by-design. (`pp.5-pullups`/`pp.10-pullups` are orphan tables — see B3.) Resolve.

### `pp.chin-up` / `pp.strict-chin-up` — ✅ OK (volume)
Rep ramps on `chin-up`. Fine. Resolve.

### Row chain — `pp.incline-row` / `pp.row` / `pp.decline-row` / `pp.tuck-row` / `pp.straddle-row` / `pp.one-arm-row` / `pp.tuck-front-lever-pullup` — ✅ mostly OK
Graduated rep ramps; `pp.row` correctly uses `inverted row` (real catalog) as the loggable. `pp.one-arm-row` and `pp.tuck-front-lever-pullup` already compound with straddle/tuck-row at upper tiers (good shape). `pp.tuck-front-lever-pullup` Ascendant compounds variant `front lever` (resolves via cl node). Lower-priority for the hard-skill reseat. All row tokens resolve via their live nodes.

### `pp.l-sit-chin-up` / `pp.wide-pullup` — ✅ OK (graduated variant rep ramps), resolve.

### `cl.three-sixty-pulls` — 360-Degree Pulls (A) — ❌ FLAT (lives in ClSkillTiers, NOT pp)
**Correction to proposal:** the doc says "likely no ladder / falls through to `[:]`". **It DOES have a `ClSkillTiers` entry** (`ClSkillTiers.swift:491`), a flat ramp: Initiate→peak `1.../1(Forged)/2/3/5/7/10 360-degree pulls`. **Diagnosis:** flat — bottom tiers demand the move. **Proposed** (would edit `ClSkillTiers`, not `PpSkillTiers`): Initiate = reps 5 `explosive pullup` · Novice = reps 1 `clapping pullup` · Apprentice = reps 3 `clapping pullup` · **Forged = reps 1 `360-degree pulls`** · Vet→peak 2/3/4/5/6.

---

## B1 — Missing catalog tokens (THE BLOCKER LIST)

Tokens referenced by **proposed** (and a couple current) ladders that do **NOT** resolve to a real catalog exercise **nor** a live SkillGraph node → they self-register only if/when written into a *live node's* table; otherwise they resolve to `unresolved.*` and silently never match. Each needs a `MovementCatalog`/`ExerciseCatalog` entry (or a live node) before the criterion is provable. Use space-lowercase keys.

| token | referenced by (proposed) | status | fix |
|---|---|---|---|
| `false grip ring row` | ring-MU Novice | **no backing** (0 hits in repo) | add catalog exercise (regression-clean name) |
| `banded ring muscle-up` | ring-MU Apprentice | **no backing** | add catalog exercise; note "banded" trips regression-guard — fine because the criterion names it |
| `negative muscle-up` | strict-MU Apprentice; MU optional refine | **no backing** | add catalog exercise; "negative" is a regression term — criterion must name it (it does) |
| `archer chin-up` | OAC Novice | **no backing** | add catalog exercise |
| `one-arm chin-up negative` | OAC Apprentice | **no backing** | add catalog exercise; names the negative explicitly (ok) |
| `typewriter pullup` | OAP Novice, oap-negative Novice | **orphan-table-only** | exists ONLY in `pp.typewriter-pullup` table (no live node, not catalog) → currently resolves to `unresolved.*`. Promote to catalog exercise OR add a live node, OR don't reference it as a bridge |

**Already-backed bridge tokens (safe — do NOT add):** `straight bar dip`, `chest-to-bar pullup`, `banded muscle-up`, `low-bar muscle-up transition`, `negative pullup`, `inverted row` (catalog); `archer pullup`, `explosive pullup`, `clapping pullup`, `heighted chin-up`, `wide pullup`, `one-arm pullup negative`, `weighted pullup`, `weighted chin-up`, `muscle-up`, `ring muscle-up`, `360-degree pulls`, `chin-up`, `pullup` (catalog and/or live node).

**Also unresolved but currently harmless** (orphan-table-only names not used as cross-node bridges): `slow pullup`, `l-sit pullup`, `plyometric pullup` — they back orphan tables only; if those tables ever drive a trial/readiness check they'd silently fail. Flag, low priority.

---

## B3 — Orphans / bugs / monotonicity

1. **`#if DEBUG` count assert is STALE — would trip.** `PpSkillTiers.swift:28` asserts `table.count == 38` and the header says "(38 skills)", but the dict has **39 unique keys**. Debug builds would hit the assertion (or it was bumped past). **Must reconcile** before any add/remove. Adding `cl.three-sixty-pulls` to `pp` (don't — it's a `cl` node) or any new row changes the count again.

2. **Orphan tier tables (13) — table key with no live `pp.*` tree node:** `pp.5-pullups`, `pp.10-pullups`, `pp.10-muscle-ups`, `pp.5-oap-side`, `pp.chest-to-bar`, `pp.typewriter-pullup`, `pp.slow-pullup`, `pp.l-sit-pullup`, `pp.plyometric-pullup`, `pp.negative-pullup`, `pp.dead-hang-30`, `pp.weighted-pullup-0.25`, `pp.weighted-pullup-0.5`. Not necessarily bugs (some likely back Overall-Rank trials/legacy IDs — `verify-audit-dead-claims` applies: confirm consumers before deleting), but they are "extra" relative to the 26 live nodes. Two of them (`pp.chest-to-bar`, `pp.typewriter-pullup`) are the source of bridge *names* used in proposals — only `chest-to-bar pullup` is independently catalog-backed; `typewriter pullup` is NOT (→ B1).

3. **No missing tables:** all 26 live `pp.*` nodes have a table. ✓

4. **Forged anchor drift (mis-anchored "first rep"):** proposal's rule is Forged = first clean rep. Currently violated at: `pp.ring-muscle-up` (Forged=4), `pp.archer-pullup` (4), `pp.clapping-pullup` (4), `pp.heighted-chin-up` (4), `pp.strict-muscle-up` (3), `pp.one-arm-chin-up` (3), `pp.one-arm-pullup` (3). The reseat fixes these.

5. **Dead bottom tiers (Initiate == Novice, both = "1 rep of the finished move"):** `pp.one-arm-pullup`, `pp.one-arm-chin-up`, `pp.strict-muscle-up`. Highest-value reseats — three Mythic S nodes currently un-climbable until owned.

6. **Double-gating on shared logged names** (multiple live nodes prove off the same string — by design but worth noting): `pullup` gates `pp.pullup`, `pp.strict-pullup`, and the low tiers of `pp.muscle-up`/`pp.dead-hang`; `chin-up` gates `pp.chin-up` + `pp.strict-chin-up`; `dead hang` gates both dead-hang tables. Reseats add more shared gating (`explosive pullup` → clapping + 360; `chest-to-bar pullup` → MU + strict-MU + clapping + heighted-chin). Not a bug — confirm intended (logging once can advance several nodes' low tiers simultaneously).

7. **`cl.three-sixty-pulls` lives in `ClSkillTiers`, not `PpSkillTiers`** — proposal's STEP-4 #2 is wrong that it has no ladder. Reseat would edit `ClSkillTiers.swift`. (Also: its `pp`-vs-`cl` cluster mismatch — node is `cluster: .pullingPower` but id-prefix `cl` → routes to ClSkillTiers. Works, but is the kind of cross-cluster routing that surprises.)

---

## SUMMARY

**(a) Reseat status (26 live pp nodes + cl.three-sixty):**
- ✅ Already graduated / keep: `pp.muscle-up` (template), `pp.weighted-chin-up`, `pp.dead-hang(-30)`, volume/row/chin/wide/l-sit nodes — ~15.
- ❌ Need reseat (flat ramp / dead bottom / Forged drift): **`pp.ring-muscle-up`, `pp.strict-muscle-up`, `pp.one-arm-pullup`, `pp.one-arm-chin-up`, `pp.clapping-pullup`, `pp.heighted-chin-up`, `pp.archer-pullup` (mild), `pp.oap-negative` (mild), `cl.three-sixty-pulls` (in ClSkillTiers)** — **8 pp + 1 cl**. The 3 Mythic S nodes (OAP, OAC, strict-MU) are top priority (dead Init==Nov bottoms).

**(b) B1 missing-token blocker list (single biggest dependency — add to MovementCatalog before reseat):**
`false grip ring row`, `banded ring muscle-up`, `negative muscle-up`, `archer chin-up`, `one-arm chin-up negative`, `typewriter pullup` (orphan-table-only, not catalog-backed). All others referenced by proposals already resolve.

**(c) B3 issues:** stale DEBUG assert (`== 38` vs actual **39** keys) — would trip / blocks adds; 13 orphan tables (verify trial consumers before touching); 7 Forged mis-anchors; 3 dead Init==Nov bottoms; proposal mis-states 360-pulls ladder (it exists, in ClSkillTiers); benign double-gating to confirm intentional.

**(d) Decisions needing jlin:**
1. Reconcile the `== 38` assert vs 39 keys (bug, or intentional 39th?).
2. Add the 6 B1 catalog tokens — and confirm the regression-guard naming (banded/negative rungs must name the regression, which the proposals do).
3. `typewriter pullup` as an OAP/oap-negative bridge: promote to catalog/live-node, or drop it from the proposal.
4. `pp.dead-hang-30`: now that `durationSeconds` is real (Foundation 2), switch to `.seconds(30)` at Forged, or keep variant+pullup-volume?
5. Confirm reseat scope = the 8 pp + edit `ClSkillTiers` for 360-pulls, and whether orphan tables (5/10-pullups etc.) get the same treatment or are left as trial-only.
