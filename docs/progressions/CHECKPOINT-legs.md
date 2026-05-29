# CHECKPOINT — LEGS family tier-ladder audit

**Status:** READ-ONLY audit. No Swift touched. For jlin to refine before any implementation.
**Scope:** LEGS (`ld.*`) — pistol, shrimp, nordic-curl + lead-up leg nodes.
**Sources audited:** `docs/progressions/legs.md`, `LdSkillTiers.swift`, `SkillTreeContent.swift`, `MovementCatalog.swift`, `ExerciseCatalog.swift`, `TierCriterion.swift`, `MovementProofMatcher.swift`.

---

## How matching actually works (load-bearing for B1)

From `MovementProofMatcher.movementMatches` + `MovementCatalog.skillTreeAliases`:

1. **Exact self-match** (`MovementProofMatcher` L42): if a logged set's normalized name `==` the criterion's normalized `exerciseName`, it matches — *even if that name is in no catalog*. So a criterion can never "silently never match" a user who logs that exact string. The blocker is **discoverability/programmability**, not evaluation: an unregistered name never appears in the exercise picker, can't be prescribed, and won't alias-bridge from a logged synonym.
2. **Live-node self-registration** (`MovementCatalog.skillTreeAliases` L1514–1518): for every node in `SkillGraph.shared.nodes`, *every* `exerciseName` inside that node's `tierCriteria` is inserted as a catalog alias. So any criterion name on a **live** node resolves to a real movementId. **Orphan tables are NOT in `SkillGraph.shared.nodes`, so their criterion names do NOT register.**
3. **Regression gate** (`MovementProofMatcher` L26–32, L59–68): if the *logged* name contains a regression term the *required* name lacks → no match. The actual term list is **`assisted, band, banded, machine, negative, jumping, eccentric, partial`** (NOTE: `box`, `counterbalance`, `elevated` are **not** regression terms — legs.md's note about them being "blocked" is inaccurate). A regression-named *criterion* (e.g. required `negative nordic curl`) self-matches a same-named log because both contain the term.

**Net B1 rule:** a name is a *blocker* (needs catalog wiring) when it is **neither** (a) an `ExerciseCatalog` canonical name/alias, **nor** (b) a criterion name on a **live** node. Such names only work via verbatim self-typing and are invisible/unprogrammable.

---

## Per-node ladders

### 1. `ld.pistol-squat` — Pistol Squat (live node, tier 4, keystone, rank C; prereq `ld.deep-squat`; target 5× pistol squat)

**Current 9-tier ladder** (all `pistol squat` reps):
`Initiate 1 · Novice 2 · Apprentice 3 · Forged 5 · Veteran 8 · Master 10 · Vessel 12 · Ascendant(raw7) 15 · Unbound(raw8) 20`

**Diagnosis:**
- **Flat single-exercise rep ramp.** Every tier is the full pistol; only rep count changes.
- **Initiate–Apprentice unreachable pre-skill:** Initiate = 1 rep of a full pistol. A beginner who can't yet do a pistol cannot earn even Initiate. This is the core "1 rep of the impossible move" problem.
- **Forged mis-anchor:** Forged = **5** reps, not first clean rep. (Side effect: the tree node's own target is also 5×, so Forged ≈ "owns the skill at volume," not "first rep.")

**PROPOSED reseat** (from legs.md, lightly synthesized — jlin to refine reps/loads):
| Tier | Criterion | Resolves? |
|---|---|---|
| Initiate | `.reps(3, "box pistol")` | B1 NEW |
| Novice | `.reps(5, "assisted pistol")` | B1 (orphan-only string, see note) |
| Apprentice | `.reps(3, "negative pistol")` | B1 NEW |
| **Forged** | `.reps(1, "pistol squat")` — **first clean rep** | OK (live) |
| Veteran | `.reps(3, "pistol squat")` | OK |
| Master | `.reps(5, "pistol squat")` | OK |
| Vessel | `.reps(8, "pistol squat")` | OK |
| Ascendant(raw7) | `.exerciseBodyweightRatio(0.25, "weighted pistol")` | OK (live) |
| Unbound(raw8) | `.exerciseBodyweightRatio(0.50, "weighted pistol")` OR `.reps(3, "dragon pistol")` (`.compound` is AND-only — an OR needs two-criterion handling or pick one) | weighted OK; `dragon pistol` B1 |

> ⚠️ `.compound` is AND across sub-criteria (`TierCriterion` + matcher). There is **no OR criterion shape.** legs.md's "compound OR" for the Unbound tier is **not expressible** — pick a single gate, or jlin decides whether to add an OR case.

---

### 2. `ld.shrimp-squat` — Shrimp Squat (live node, tier 4, rank C; prereq `ld.bulgarian-split-squat`; target 3× shrimp squat)

**Current 9-tier ladder** (all `shrimp squat` reps):
`Initiate 1 · Novice 2 · Apprentice 3 · Forged 5 · Veteran 8 · Master 10 · Vessel 12 · Ascendant 15 · Unbound 20`

**Diagnosis:**
- Flat rep ramp on the full shrimp.
- Initiate–Apprentice unreachable pre-skill (Initiate = 1 full shrimp rep).
- Forged mis-anchor: Forged = 5 reps, not first clean rep. (Node target is only 3×, so Apprentice `3` already exceeds the tree node's completion bar — minor monotonicity oddity: you "complete" the node before reaching Forged.)

**PROPOSED reseat:**
| Tier | Criterion | Resolves? |
|---|---|---|
| Initiate | `.reps(3, "box shrimp squat")` | B1 NEW |
| Novice | `.reps(3, "counterbalance shrimp")` | B1 NEW |
| Apprentice | `.reps(5, "counterbalance shrimp")` | B1 NEW |
| **Forged** | `.reps(1, "shrimp squat")` — **first clean rep** | OK (live) |
| Veteran | `.reps(3, "shrimp squat")` | OK |
| Master | `.reps(5, "shrimp squat")` | OK |
| Vessel | `.reps(8, "shrimp squat")` | OK |
| Ascendant(raw7) | `.reps(3, "elevated shrimp squat")` | B1 NEW |
| Unbound(raw8) | `.reps(3, "weighted shrimp squat")` | B1 NEW |

> Catalog already has `assisted shrimp squat` (canonical) — legs.md doesn't use it but it's an available rung name if jlin prefers a catalog-backed Initiate/Novice over the NEW `box shrimp squat` / `counterbalance shrimp`.

---

### 3. `ld.nordic-curl` — Nordic Curl (live node, tier 6, rank A; prereq `ld.advancing-nordic-curl`; target 3× nordic curl)

**Current 9-tier ladder** (all `nordic curl` reps):
`Initiate 1 · Novice 2 · Apprentice 3 · Forged 5 · Veteran 7 · Master 10 · Vessel 12 · Ascendant 15 · Unbound 20`

**Diagnosis:**
- Flat rep ramp on the full nordic.
- Initiate–Apprentice unreachable pre-skill.
- Forged mis-anchor: Forged = 5 reps. Worse than pistol/shrimp because a full nordic-curl rep is elite — 5 unassisted reps is a very high "first" bar.
- **DOUBLE-GATING BUG (see B3):** shares the `nordic curl` logged name with `ld.advancing-nordic-curl`.

**PROPOSED reseat:**
| Tier | Criterion | Resolves? |
|---|---|---|
| Initiate | `.reps(3, "band nordic curl")` | B1 NEW (`band` = regression term; self-matches fine) |
| Novice | `.reps(5, "partial nordic curl")` | B1 NEW (`partial` = regression term; self-matches) |
| Apprentice | `.reps(3, "negative nordic curl")` | B1 NEW (`negative` = regression term; self-matches) |
| **Forged** | `.reps(1, "nordic curl")` — **first full negative to floor** | OK (live) |
| Veteran | `.reps(2, "nordic curl")` | OK |
| Master | `.reps(3, "nordic curl")` | OK |
| Vessel | `.reps(5, "nordic curl")` | OK |
| Ascendant(raw7) | `.reps(8, "nordic curl")` | OK |
| Unbound(raw8) | `.reps(3, "weighted nordic curl")` | B1 NEW |

---

### 4. `ld.advancing-nordic-curl` — "Advanced Nordic Hip Hinge" (live node, tier 5, rank B; prereq `ld.nordic-hip-hinge`; target 5× advanced nordic hip hinge)

**Current 9-tier ladder** — gates on **`nordic curl`** reps `1·2·3·4·5·6·8·10·12`.

**Diagnosis:**
- **Wrong exercise name (the double-gate bug).** This node's title/target is "advanced nordic hip hinge" (5× per the tree), but its 9 tiers all gate on `nordic curl` — the *same* logged name as `ld.nordic-curl`. A single logged "nordic curl" set advances **both** nodes. Also its tiers reach 12 reps of `nordic curl` while the harder downstream `ld.nordic-curl` Forged is only 5 — an inversion (you'd hit Vessel+ on the easier node off the same log that barely Forges the hard one).
- PROPOSED (legs.md §5): re-point low/all tiers to `negative nordic curl` / `nordic hip hinge` so the on-ramp stops sharing the `nordic curl` name. jlin to decide exact name + reps.

---

### Lead-up / supporting leg nodes (live) — status

| node | current ladder shape | verdict |
|---|---|---|
| `ld.weighted-pistol` | `variant` → `exerciseBodyweightRatio` 0.10→1.25 on `weighted pistol` | **GOOD** (graduated by load; legs.md only suggests cosmetic re-anchor of Forged, optional) |
| `ld.goblet-20`, `ld.bw-front-squat`*, `ld.weighted-bss`, `ld.weighted-split-squat`, `ld.weighted-sl-calf` | `variant` → ratio ramp | **GOOD** (same correct load pattern) |
| `ld.glute-bridge`, `ld.single-leg-glute-bridge`, `ld.fire-hydrant`, `ld.flying-kickback`, `ld.calf-raise`, `ld.step-up`, `ld.box-jump`, `ld.jumping-squat`, `ld.split-squat`, `ld.bulgarian-split-squat`, `ld.sissy-squat`, `ld.leg-extensions`, `ld.nordic-hip-hinge`, `ld.deep-squat` | rep ramp / hold-compound on a single owned movement | **ACCEPTABLE** — these are foundational/accessible movements where "few reps → many reps of the same thing" is a fine ladder (you can already do a glute bridge). Reseat NOT required. |
| `ld.floor-to-ceiling-squat` (mythic, S) | `floor to ceiling squat` reps 1→16 | Flat ramp but it's a mythic single-skill; Forged=4 reps. Out of LEGS hard-skill scope; leave to jlin. |

\* `ld.bw-front-squat` is an **orphan** table (no node) — see B3.

---

## B1 — Missing catalog tokens (the blocker list)

Names a proposed/current ladder references that are **neither** an `ExerciseCatalog` name/alias **nor** a live-node criterion name. These don't appear in the picker, can't be programmed, and won't alias-bridge — they only work if the user types them verbatim.

**Brand-new (proposed, 10):**
`box pistol`, `negative pistol`, `box shrimp squat`, `counterbalance shrimp`, `elevated shrimp squat`, `weighted shrimp squat`, `band nordic curl`, `partial nordic curl`, `negative nordic curl`, `weighted nordic curl`

**Orphan-only strings legs.md assumes "EXIST" but do NOT resolve (3):**
`assisted pistol`, `elevated pistol`, `dragon pistol`
→ These live *only* in orphan tables (`ld.assisted-pistol` / `ld.heighted-pistol` / `ld.dragon-pistol`), which are **not** live nodes, so they do **not** register as aliases. legs.md marks them "EXISTS" — that's true as orphan-table strings, **false** as resolvable names. Catalog *does* have a different string `assisted pistol squat` (canonical) but `assisted pistol` ≠ `assisted pistol squat` under normalization.

**Important wiring nuance:** once any of these names is placed into a **live** node's `tierCriteria`, `skillTreeAliases` auto-registers it → it resolves for proof-matching. But it still has **no muscle/equipment/difficulty metadata** and won't surface as a pickable catalog exercise. Full fix = add real `ExerciseCatalog` entries (legs.md's "catalog wiring, largest build-out"). Minimum fix to make tiers gradeable = just put them in the live tables.

**Already resolvable (no action) — reused at Forged+:** `pistol squat`, `shrimp squat`, `nordic curl`, `weighted pistol` (all live-node names).

---

## B3 — Orphans, bugs, asserts, monotonicity

### Orphan tables (10) — confirmed: table exists in `LdSkillTiers.table`, NO `SkillNode` in `SkillTreeContent`
Computed by diffing 34 table ids vs 24 live `id: "ld.*"` node ids:

`ld.100-lunges`, `ld.assisted-pistol`, `ld.bw-front-squat`, `ld.dragon-pistol`, `ld.heighted-pistol`, `ld.heighted-split-squat`, `ld.hip-hinge`, `ld.jumping-pistol`, `ld.single-leg-rdl`, `ld.tempo-squat`

- **All 10 are orphan-only** (rank silently if logged, never render in the tree, never register their criterion names as aliases).
- The pistol ladder legs.md leans on (`assisted pistol`, `elevated pistol`/`heighted-pistol`, `dragon pistol`, `jumping pistol`) are in this orphan set → the "EXISTS" reuse claim is unsafe (see B1).
- Decision needed: (a) delete the 10 orphan tables, or (b) add matching `SkillNode`s to surface them as the visible pistol-ladder rungs (legs.md's optional heaviest lift).

### Nordic double-gating bug — CONFIRMED
- **Nodes:** `ld.advancing-nordic-curl` (tier 5) and `ld.nordic-curl` (tier 6).
- **Shared logged name:** **`nordic curl`** — both tables gate every tier on `exerciseName: "nordic curl"`.
- **Effect:** one logged `nordic curl` set advances both nodes; and the *easier* on-ramp reaches 12 reps while the *harder* skill Forges at 5 — a cross-node inversion.
- **Fix direction:** re-point `ld.advancing-nordic-curl` off `nordic curl` (use `negative nordic curl` / `nordic hip hinge`).

### `#if DEBUG` count assert — MATCHES (not stale)
- Assert: `LdSkillTiers.table.count == 34`; per-table `tiers.count == 9` + all 9 cases present.
- Actual unique table-key count = **34**. ✅ Assert is **correct**.
- ⚠️ Implication for any reseat: edits that *replace* tier criteria are fine; if jlin chooses to **delete** orphan tables, the `== 34` literal must drop to match (e.g. 24 if all 10 orphans deleted) or the DEBUG assert fires (B3-style blocker on the next build).

### Prereq / monotonicity issues
- `ld.shrimp-squat`: current Apprentice (`3` reps) already meets/exceeds the tree node's `target` (3× shrimp) — you finish the node before Forged. Proposed reseat fixes this (Forged = 1 rep, target alignment shifts).
- `ld.advancing-nordic-curl` vs `ld.nordic-curl`: rep inversion described above.
- Pistol/shrimp/nordic prereq chains are otherwise sound: `goblet-20→split→bss→{shrimp, (deep-squat→)pistol→weighted-pistol}`; `…→nordic-hip-hinge→advancing-nordic-curl→nordic-curl`. No prereq cycles found.
- `.compound` is AND-only — legs.md's pistol "Unbound" OR-gate (`weighted` OR `dragon`) is **not expressible** with current criterion shapes.

---

## SUMMARY

### (a) Nodes needing reseat vs good
- **RESEAT (flat ramp + unreachable low tiers + Forged mis-anchor):** `ld.pistol-squat`, `ld.shrimp-squat`, `ld.nordic-curl`.
- **FIX (wrong/duplicate gate):** `ld.advancing-nordic-curl` (re-point off `nordic curl`).
- **GOOD as-is (load-graduated):** `ld.weighted-pistol`, `ld.weighted-bss`, `ld.weighted-split-squat`, `ld.weighted-sl-calf`, `ld.goblet-20`, `ld.bw-front-squat`.
- **ACCEPTABLE (foundational, accessible — no reseat):** glute-bridge / SL-glute-bridge / fire-hydrant / flying-kickback / calf-raise / step-up / box-jump / jumping-squat / split-squat / bulgarian-split-squat / sissy-squat / leg-extensions / nordic-hip-hinge / deep-squat / floor-to-ceiling (mythic, out of scope).

### (b) Full B1 token list (needs catalog wiring)
New (10): `box pistol`, `negative pistol`, `box shrimp squat`, `counterbalance shrimp`, `elevated shrimp squat`, `weighted shrimp squat`, `band nordic curl`, `partial nordic curl`, `negative nordic curl`, `weighted nordic curl`.
Orphan-only / falsely "EXISTS" (3): `assisted pistol`, `elevated pistol`, `dragon pistol`.

### (c) B3 issues
- **Orphans (10, all orphan-only):** `ld.100-lunges`, `ld.assisted-pistol`, `ld.bw-front-squat`, `ld.dragon-pistol`, `ld.heighted-pistol`, `ld.heighted-split-squat`, `ld.hip-hinge`, `ld.jumping-pistol`, `ld.single-leg-rdl`, `ld.tempo-squat`.
- **Nordic double-gate:** `ld.advancing-nordic-curl` + `ld.nordic-curl` both gate on `nordic curl`; plus easy-node-reaches-higher-reps inversion.
- **DEBUG assert:** `== 34`, actual = 34 → **correct now**; but it will block any orphan-deletion edit unless updated in the same commit.
- **`.compound` is AND-only** — no OR shape exists for the proposed pistol Unbound dual-gate.

### (d) jlin decisions needed
1. Confirm Forged = **first clean rep** (1) for pistol / shrimp / nordic (vs current 5).
2. Pick reps/loads for each proposed regression rung (drafts above).
3. Catalog wiring depth: full `ExerciseCatalog` entries (picker-visible, programmable) vs minimum (drop names into live tables to make them gradeable only)?
4. Orphan tables: delete the 10, or promote some (`assisted/heighted/dragon/jumping-pistol`) to real tree nodes? Either way update the `== 34` assert.
5. Re-point name for `ld.advancing-nordic-curl` (`negative nordic curl`? `nordic hip hinge`?).
6. Pistol "Unbound" gate: single criterion (can't OR), or add an `.either`/OR criterion shape?
7. `assisted shrimp squat` already exists in catalog — use it for shrimp Initiate/Novice instead of new `box shrimp squat` / `counterbalance shrimp`?
