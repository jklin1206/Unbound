# CHECKPOINT — Advanced Push family audit

**Status:** READ-ONLY audit. No Swift modified. For jlin to refine before any reseat lands.
**Scope:** the hard pushing nodes — HSPU, 90°, clapping HSPU, bent-arm press, the two handstand presses, the planche-pushup line, plus the mid-progression pike rungs.

## How resolution actually works (the rules this audit applies)

A criterion's `exerciseName` / `variant` token **counts** when a logged set's name resolves to it. A token resolves if it is ONE of:
1. An **ExerciseCatalog** exercise (or one of its aliases) — `MovementCatalog.aliasIndex`.
2. A token referenced by a **LIVE skill node's** `tierCriteria` (or that node's `target`/title/subtitle) — `skillTreeAliases(for:)` self-registers every live node's criterion exerciseNames as aliases of that skill target. (Built from `SkillGraph.shared.nodes`, which excludes conditioning + any orphan table.)
3. The criterion's own exact string — `MovementProofMatcher` returns true on `normalized(logged) == normalized(required)`.

Normalization (`MovementCatalog.normalized`) lowercases and collapses every non-alphanumeric run to a single space, so `"pseudo-planche pushup"` == `"pseudo planche pushup"` and `"90-degree pushup"` == `"90 degree pushup"`. Hyphen vs space is therefore **never** a blocker.

**The real B1 trap:** a token that is neither a catalog exercise NOR referenced by any *live* node — i.e. it lives only in an orphan table (Hspu, or the 5 dead pl.* keys) or is net-new in the proposal. Those never enter `aliasIndex`, so the only way to satisfy them is to log the literal string (rule 3) — fine for a manual skill-attempt log, but they won't match catalog substitutes or appear in pickers.

**Regression guard** (`MovementProofMatcher.regressionTerms`): `assisted, band, banded, machine, negative, jumping, eccentric, partial`. A logged set containing one of these is blocked from satisfying a criterion that does NOT also contain it. NOTE: `wall` and `pike` are NOT in the live guard list (the task brief listed them speculatively) — so `wall hspu` / `pike pushup` are not regression-blocked. `negative` IS guarded, but every negative criterion here names "negative" itself, so it passes.

---

## Per-node ladders + diagnosis

### `cal.handstand-pushup` (keystone) — CalSkillTiers L459
Target string: `handstand pushup` (count 1). Criteria:

| tier | criterion |
|---|---|
| initiate | 3× wall hspu negative |
| novice | 5× wall hspu negative |
| apprentice | 1× wall hspu |
| **forged** | **3× wall hspu** |
| veteran | 5× wall hspu |
| master | 8× wall hspu |
| vessel | 8× wall hspu + 1× deficit wall hspu |
| unbound | 10× wall hspu + 3× deficit wall hspu |
| ascendant | 12× wall hspu + 1× freestanding hspu |

**Diagnosis:** ALREADY GRADUATED (negative → first wall rep → volume → deficit → freestanding). Initiate/Novice reachable pre-skill via negatives. **Forged mis-anchor:** Forged = **3× wall hspu**, not the first clean rep (Apprentice holds the 1-rep). Proposal 3a wants Forged = the first wall HSPU rep; current table puts the first rep one tier *below* Forged. Minor reseat. Also a **content smell:** node `target` says `handstand pushup` while every criterion says `wall hspu` / `freestanding hspu` — they diverge but both self-register, so it works.

### `cal.ninety-degree-pushup` — CalSkillTiers L513
Target: `90 degree pushup`. Criteria:

| tier | criterion |
|---|---|
| initiate | tuck planche (variant) |
| novice | tuck planche + 5× wall hspu |
| apprentice | straddle planche + 5× wall hspu |
| **forged** | **1× 90-degree pushup** |
| veteran | 2× 90-degree pushup |
| master | 3× 90-degree pushup |
| vessel | 3× 90-degree pushup + full planche |
| unbound | 5× 90-degree pushup + 1× freestanding hspu |
| ascendant | 8× 90-degree pushup + 3× freestanding hspu |

**Diagnosis:** Graduated, Forged correctly anchored to first rep. **Unreachable-low-tier flag:** Initiate requires a `tuck planche` hold — an Adv/Elite skill. An advanced-but-not-planche lifter who owns 90° pressing strength still can't register Initiate. Proposal 3b lowers Initiate to `wall hspu ×5`. Reasonable; jlin call. (Two ladders of `90 degree pushup` exist — this live one uses hyphen `90-degree pushup`, the orphan `pl.ninety-degree-pushup` uses space — same after normalize.)

### `cal.clapping-handstand-pushup` (mythic) — CalSkillTiers L473
| tier | criterion |
|---|---|
| initiate | 3× wall hspu |
| novice | 5× wall hspu |
| apprentice | 1× deficit wall hspu |
| **forged** | **1× clapping handstand pushup** |
| veteran | 2× clapping handstand pushup |
| master | 3× clapping handstand pushup |
| vessel | 3× clapping + 3× freestanding hspu |
| unbound | 5× clapping + 5× freestanding hspu |
| ascendant | 8× clapping + 8× freestanding hspu |

**Diagnosis:** Graduated, Forged = first clap rep (correct). Matches proposal 3c almost exactly (proposal puts `freestanding hspu ×1` at Novice; current uses wall-hspu volume). No reseat needed — optional polish only.

### `cal.bent-arm-press` — CalSkillTiers L416
| tier | criterion |
|---|---|
| initiate | 1× bent arm press |
| novice | 2× bent arm press |
| apprentice | 3× bent arm press |
| **forged** | **4× bent arm press** |
| veteran | 5× / master 6× / vessel 8× / unbound 10× / ascendant 12× bent arm press |

**Diagnosis:** FLAT 1→12 ramp of the full skill — the exact problem pattern. **Initiate–Apprentice unreachable until you already own the press.** No sub-Forged on-ramp, no top bridge. Proposal 3d reseats lower tiers onto `wall handstand hold` / `tripod-to-tuck negative` / `kick-assisted press` and bridges the top into `straddle press` / `press to handstand`. **Highest-value reseat in the family.** (Forged at 4 reps is also debatable vs "first clean press"; proposal keeps Forged=3.)

### `cal.floating-pike-pushup` — CalSkillTiers L191
Flat 1→16 of `floating pike pushup`. **FLAT ramp**, Initiate (1 rep) already needs the skill. Proposal 3h reseats Initiate/Novice onto `elevated pike pushup` and bridges top into `bent arm press`. Medium value.

### `cal.triple-clap-pushup` (mythic) — CalSkillTiers L178
Flat 1→15 of `triple clap pushup`. **FLAT ramp.** Low priority (mythic, plenty of rep headroom); proposal leaves it.

### `cal.pike-pushup` / `cal.elevated-pike-pushup` — CalSkillTiers L433 / L446
Both ALREADY GRADUATED (pushup proxy → real variant → compound into next rung). Forged = 10 reps of the named variant (these are volume nodes, not first-rep milestones, so 10-rep Forged is correct framing). Good. No change.

### `cal.pseudo-planche-pushup` — CalSkillTiers L486
Graduated (pushup → pseudo-planche → compound w/ tuck planche). Forged = 10 reps (volume node). Good.

### `cal.tuck-planche-pushup` — CalSkillTiers L499
Graduated: Initiate `tuck planche` hold → Apprentice first rep → Forged 3 reps → top compounds with `straddle planche` / `full planche` **holds**. **Smell (proposal §4.4):** OG2 progression tops into straddle/full **planche pushup**, not the static hold. Current uses holds as a proxy. jlin call: accept proxy or add `straddle planche pushup` token.

### `hs.tuck-press` / `hs.straddle-press` / `hs.press-to-handstand` — HsSkillTiers L219 / L235 / L250
All ALREADY GRADUATED and cleanly bridged (tuck→straddle→press, compounds upward). Forged = 5 / 5 / 1 reps respectively. `press-to-handstand` Forged = first rep (correct). Listed in proposal 3e/3f for parity — **no change needed.**

---

## B1 — missing catalog tokens (the blocker list)

**Live tables (Cal/Hs/Pl live nodes): ZERO blockers.** Every token they reference either is an ExerciseCatalog exercise (`pushup`, `pike pushup`, `pseudo planche pushup`, `archer pushup`, `decline pushup`, `diamond pushup`, `dip`, etc.) OR self-registers as a live skill-target alias. Verified-resolving non-catalog tokens (resolve only because a live node names them — keep them named in a live node or they break):
`wall hspu`, `wall hspu negative`, `deficit wall hspu`, `freestanding hspu`, `deficit freestanding hspu`, `freestanding hspu negative`, `90-degree pushup`/`90 degree pushup`, `clapping handstand pushup`, `bent arm press`, `tuck planche pushup`, `full planche pushup`, `elevated pike pushup`, `floating pike pushup`, `triple clap pushup`, `explosive pushup`, `clapping pushup`, `one-arm pushup`, `sphinx pushup`, `tuck press`, `straddle press`, `press to handstand`, `wall handstand`, and the `* planche` variant holds.

**PROPOSED net-new tokens that DON'T resolve today (real B1 list — must add a catalog entry, a new node, or accept literal-log-only):**
1. `pike HeSPU` (proposal 3a, Novice) — partial-ROM head-only pike. Not catalog, not any live node. Note `freestanding HSPU negative` in the same ladder ALREADY resolves (live `cal.handstand-pushup` references it) — proposal §4.1's "verify these all need adding" is partly stale; only `pike HeSPU` is genuinely new in 3a.
2. `wall handstand hold` (proposal 3d Initiate) — would resolve if pointed at the existing `wall handstand` token / `hs.wall-handstand-30`; as written ("wall handstand hold") it's a near-miss alias. Use `wall handstand`.
3. `tripod-to-tuck negative` (proposal 3d Novice) — net-new. Contains `negative` (regression-guarded) — fine since the criterion names it, but the token itself must exist.
4. `bent arm press (kick-assisted)` (proposal 3d Apprentice) — net-new. Contains `assisted` (regression-guarded) — fine since criterion names it, but token must exist.
5. `straddle planche pushup` (proposal §4.4 optional, tuck-planche-pushup top bridge) — net-new if jlin wants pushup-bridge instead of the hold proxy.

(Proposal 3a's `wall HSPU negative`, `deficit wall HSPU`, `freestanding HSPU`, `freestanding HSPU negative` are NOT blockers — already live via `cal.handstand-pushup` / `cal.clapping-handstand-pushup`.)

---

## B3 — orphans, dead tables, asserts, monotonicity

### Dead / orphan tables (no live node → aliases never register)
- **`HspuSkillTiers.swift` — fully dead.** 10 `hspu.*` keys, dispatch live (`case "hspu"` SkillTreeContent.swift L45), but **no `hspu.` node exists** — the cluster was collapsed into `cal.handstand-pushup` (L225 comment). The HSPU ladder content was already lifted into the `cal.*` entries (cal.handstand-pushup / cal.clapping-handstand-pushup carry the same wall/deficit/freestanding tokens). This table is the best *template* but is unreachable code. Per "delete old code on change": fold any remaining nuance into CalSkillTiers and delete the table + its dispatch case in one commit. (Two ExerciseCatalog entries still tag `progressionFamily: "hspu"` — `pike pushup`, `wall handstand pushup` — and `SkillCluster.handstandPushup` → `"hspu"`; those are program-gen plumbing, leave them.)
- **`PlSkillTiers.swift` — 5 orphan keys (table entries with NO node):** `pl.pseudo-planche-pushup`, `pl.tuck-planche-pushup`, `pl.full-planche-pushup`, `pl.ninety-degree-pushup`, `pl.one-arm-planche`. The live planche-PUSHUP / 90° nodes live in the `cal.*` namespace (`cal.pseudo-planche-pushup`, `cal.tuck-planche-pushup`, `cal.ninety-degree-pushup`); there is **no `pl.full-planche-pushup`, `pl.ninety-degree-pushup`, or `pl.one-arm-planche` node at all.** These 5 pl.* tier dicts are dead weight. The 5 LIVE pl nodes are the hold-types only: tuck-planche, straddle-planche, full-planche, bent-arm-planche, half-lay-planche.

### Stale-assert check (actual vs asserted) — ALL PASS
- CalSkillTiers: asserts **34**, actual **34** ✓
- HsSkillTiers: asserts **20**, actual **20** ✓
- PlSkillTiers: asserts **10**, actual **10** ✓ (but 5 of the 10 are orphan keys — assert counts table keys, not nodes, so it passes despite the orphans)
- HspuSkillTiers: asserts **10**, actual **10** ✓ (whole table is dead)
- **No stale-assert B3 bug.** BUT: the asserts validate table-key count + per-key 9-tier completeness only; they do NOT validate node↔table parity, which is why the dead Hspu table and 5 orphan pl keys slip through. Adding a node-coverage assert would catch this class.

### Tier-monotonicity / double-gating
- `cal.handstand-pushup`: **Forged anchor inversion** — Apprentice = 1× wall hspu, Forged = 3× wall hspu. The first-rep milestone sits at Apprentice, not Forged. (Reseat per 3a.)
- `cal.ninety-degree-pushup` Initiate gates on `tuck planche` (Adv/Elite hold) — effectively unreachable for a non-planche presser. Double-implicit-gate via prereq `cal.handstand-pushup` + planche hold.
- No reversed rep ladders found (all rep counts monotonic non-decreasing within each node).

### Prereq sanity (in-scope nodes, all resolve to live nodes)
`cal.pike-pushup`←diamond, `cal.elevated-pike-pushup`←pike, `cal.handstand-pushup`←elevated-pike, `cal.ninety-degree-pushup`←handstand-pushup, `cal.clapping-handstand-pushup`←ninety-degree, `cal.bent-arm-press`←floating-pike, `cal.tuck-planche-pushup`←pseudo-planche, `cal.pseudo-planche-pushup`←decline, `hs.straddle-press`←tuck-press, `hs.press-to-handstand`←straddle-press. All prereqs point at existing live nodes. No dangling prereqs.

---

## SUMMARY

### (a) Reseat status
| Node | Verdict |
|---|---|
| `cal.bent-arm-press` | **RESEAT (highest value)** — flat 1→12, low tiers unreachable, no bridges |
| `cal.floating-pike-pushup` | **RESEAT** — flat 1→16, Initiate needs the skill |
| `cal.handstand-pushup` | **MINOR** — Forged anchor inversion (first rep is at Apprentice) |
| `cal.ninety-degree-pushup` | **MINOR** — Initiate gates on tuck-planche hold (lower it) |
| `cal.tuck-planche-pushup` | **OPTIONAL** — top bridges to hold not pushup (proxy debate) |
| `cal.triple-clap-pushup` | leave (mythic, low priority) |
| `cal.clapping-handstand-pushup` | GOOD (optional polish) |
| `cal.pike-pushup`, `cal.elevated-pike-pushup`, `cal.pseudo-planche-pushup` | GOOD |
| `hs.tuck-press`, `hs.straddle-press`, `hs.press-to-handstand` | GOOD (parity only) |

### (b) B1 token list (net-new, won't resolve today)
`pike HeSPU` · `wall handstand hold` (→ use existing `wall handstand`) · `tripod-to-tuck negative` · `bent arm press (kick-assisted)` · `straddle planche pushup` (optional). Everything else the proposal lists (wall/deficit/freestanding HSPU + negatives) ALREADY resolves via live cal nodes — proposal §4.1 is partly stale.

### (c) B3 issues + assert counts
- **Dead `HspuSkillTiers` table** (10 keys, 0 nodes) — delete table + `case "hspu"` dispatch after content is confirmed lifted into CalSkillTiers.
- **5 orphan `PlSkillTiers` keys** (pseudo-planche-pushup, tuck-planche-pushup, full-planche-pushup, ninety-degree-pushup, one-arm-planche) — no nodes; live equivalents are `cal.*` or don't exist.
- **Asserts all PASS** (Cal 34/34, Hs 20/20, Pl 10/10, Hspu 10/10) — NO stale-assert bug. Asserts count table keys, not node parity, so they don't catch the orphans. Consider a node↔table coverage assert.
- **Forged anchor inversion** on `cal.handstand-pushup` (first rep at Apprentice not Forged).
- **Unreachable Initiate** on `cal.ninety-degree-pushup` (tuck-planche hold).

### (d) jlin decisions needed
1. **Bent-arm press reseat** — adopt proposal 3d on-ramp + top bridge? (needs 2–3 net-new tokens)
2. **Net-new token strategy** — add as ExerciseCatalog exercises, as new nodes, or accept literal-skill-attempt-log-only? (affects pickers/substitutes)
3. **HSPU Forged** — move first-clean-rep to Forged (shift current 1-rep up from Apprentice)?
4. **90° Initiate** — lower from tuck-planche hold to wall-hspu volume?
5. **Tuck-planche-pushup top** — keep hold proxy or add `straddle planche pushup`?
6. **Dead-code cleanup** — delete HspuSkillTiers + 5 orphan pl keys in the same commit as the reseat (per memory rule).
