# Phase 4 — Skill-Tree Placement: Investigation + Plan

**Date:** 2026-05-29 · **Scope:** investigation only, NO Swift edits.
**Headline verdict:** `SkillLevel` / `node.levels` is **genuinely deletable dead progression** (no XP, no gate, no live consumer) — BUT it is **load-bearing display copy** for 135 nodes, so deletion needs a copy-replacement decision. `MovementDifficulty` is **NOT a skill-node axis and is NOT safely foldable** — the plan misclassified it. **Phase 4 needs a jlin checkpoint before execution.**

---

## TL;DR table — what the plan says vs. what the code shows

| Plan claim (Phase 4) | Reality | Safe as written? |
|---|---|---|
| `SkillLevel`/`node.levels` is a "dead Lv1–5 XP ladder that grants no XP" | TRUE — it grants no XP, gates nothing, drives no progression. The live Lv1–5 ladder is a **different type** (`SkillProgress.currentLevel`). | ✅ deletable, **but** it's the only source of per-node Lv1–5 criterion **copy** shown in 2 views (135 nodes) |
| `MovementDifficulty` is "a separate difficulty axis" to "fold into placementRank" | FALSE — it's a property of **catalog `MovementDefinition`** (every loggable exercise), and it **feeds the live XP/LVL work-math** (`VelocityService.skillMultiplier`). Phase 7 explicitly KEEPS this weight. | ❌ do **not** fold/delete — load-bearing |
| `SkillRank` (E–S) folds into `placementRank` | It's `node.rank`, drives staircase **bands, skin tints, rank badges, reward summary, detail header** (~10 live consumers). | ⚠️ foldable but needs copy decision (taglines/labels) |
| `tier 0–8 = Initiate→Ascendant` | Content uses **tier 1–8** (no tier 0). 9 buckets need a 1–8 (or 0–8) mapping decision. | ⚠️ off-by-one to resolve |
| `NodeState` "reduce to locked/proven only" | Currently 4 states: `locked/attempting/achieved/mastered`, all live in prereq + XP logic. | ⚠️ real refactor, not trivial |
| `.new` 336 KB stale dupe to delete | **Does not exist in source** — only in `.derivedData-*/` build artifacts (gitignored). | ✅ nothing to delete in repo |

---

## 1. What is `SkillLevel`? (`UNBOUND/Models/SkillLevel.swift`)

A `Codable` struct: `level (1…5)`, `target: LevelTarget`, `criterion: String`, `xpReward: Int`. Each `SkillNode` carries `var levels: [SkillLevel] = []` (`SkillTree.swift:135`). Defined comment: "Phase 1b wires XP accrual… Phase 1c populates these." **That wiring never landed.**

- **Grants/tracks XP?** No. `xpReward` is referenced **only** inside `SkillTreeContent.swift` (the data) and `SkillLevel.swift` (the def). The substring "xpReward" appears elsewhere only as an unrelated local in `WorkoutRewardSequence.swift`. **No code reads `SkillLevel.xpReward`.**
- **`LevelTarget` / `.firstRep` / `.weight(multiplier:)`** — pattern-matched **nowhere** outside the content file. Pure dead enum.
- **Persisted?** No. `SkillNode` is `Codable` but the graph is built in-code from `SkillTreeContent.swift`; node defs aren't round-tripped from user storage. User progression persists in `UserSkillProgress` (`skillProgress` collection) — which stores `SkillProgress`, **not** `SkillLevel`.

## 2. The "680 refs" — almost entirely noise

| Bucket | Count | Live? |
|---|---|---|
| `SkillTreeContent.swift` (generated data: 135 nodes × 5) | **675** | data-only |
| `SkillLevel.swift` (the definition) | 3 | def |
| `SkillTree.swift` (`var levels` + builder copy `levels: n.levels`) | 2 | plumbing |
| **Real external consumers of the `SkillLevel` type** | **0** | — |

The `.levels` token (20 hits) splits into two unrelated things:
- **`node.levels`** (the SkillLevel array): `SkillTree.swift:351` (graph rebuild), `SkillDetailView` (7), `OverviewTabView` (1). **Display only.**
- **`profile.levels` / `preview.levels`** (an attribute-level dict — a *different* `levels`): `HomeBuildChipCard`, `ProfileBuildCard`, `Step_ProblemOpening`, `WorkoutRewardSequence`. **Unrelated — do not touch.**

## 3. `node.levels` — populated everywhere, consumed only as copy

- **Populated:** all **135** nodes carry a full 5-entry `levels` array (135 × 5 = 675 `SkillLevel(...)`).
- **Read by:**
  - `SkillDetailView.swift:163-165, 901-909, 1149-1154` — "next beat" criterion + the `fallbackRankCriterion(for tier:)` backup copy (used only when `tierCriteria` is absent).
  - `OverviewTabView.swift:80` — "Your first rep" unlock step, the Lv1 criterion string.
  - Every read has a `?? "fallback string"`.
- **Gates/awards on it?** **None.** State advances on `node.target` (`NodeRequirement`) via `SkillProgressService.requirementMet`; the LVL chip advances on a flat XP curve (see §below). `node.levels` touches neither.

**Verdict on the key question:** `SkillLevel`/`node.levels` is **dead as progression** (deletable) but **live as flavor/criterion copy** for 135 nodes. Deleting the type without a copy plan removes the "what does Lv1/the next beat look like" strings from the skill detail + overview UI.

### The live Lv1–5 ladder is a *different* type — DO NOT confuse them
`SkillProgress.currentLevel (1…5)` (`Models/SkillProgress.swift`, persisted in `UserSkillProgress.skillProgress`) is the real, live ladder shown as the **"LVL N"** chip in `ClusterCardView:232`, `SkillDetailView:305`, `SkillSessionView`. It advances in `SkillProgressService.awardSessionXP` (called live from `TrainingCompletionService.complete():104`) via a **flat `xpForLevel()` curve + fixed +25 XP/session**, fully independent of `SkillLevel.xpReward`. **Phase 4 must not touch `SkillProgress.currentLevel`** — it's untouched by deleting `SkillLevel`. (Whether that separate ladder *should* survive the ONE-METRIC mandate is a Phase 5/6 question, not Phase 4.)

## 4. `SkillNode.tier` — the placement axis (`SkillTree.swift:97`)

- `let tier: Int` — comment says "1 = Novice, 6 = Elite, 7 = Mythic." Content actually uses **tier 1–8**: distribution `1:5, 2:17, 3:27, 4:30, 5:30, 6:15, 7:8, 8:3`.
- **Plan's `tier 0–8 = Initiate→Ascendant` is off-by-one** — no node uses tier 0; range is 1–8 (8 distinct values, RankTier has 9). A mapping must be chosen (e.g. tier1→Initiate…tier8→Vessel/Unbound, or tier1→Novice with Initiate reserved for locked). **This is a decision.**
- **tier-vs-prereq monotonicity:** not yet measured node-by-node (would need a prereq-depth crawl of all 135 nodes). The plan's "~10–25 reconciliations" is plausible but **unverified** — it requires authoring judgment per node (is this node mis-tiered, or is the prereq edge wrong?). **This is authoring work + decisions, not a mechanical sweep.**

## 5. `MovementDifficulty` — load-bearing, misclassified by the plan

`enum MovementDifficulty { beginner, intermediate, advanced, elite }` (`MovementCatalog.swift:109`).

- It is a field on **`MovementDefinition`** (`var difficulty`, line 178) — i.e. on **catalog movements**, the loggable-exercise layer, NOT on `SkillNode`.
- **Live consumer:** `VelocityService.skillMultiplier(for:)` (1.0/1.2/1.45/1.75) → `weightedAP(gains:)` → the **LVL/XP work-math**. This is exactly the "per-move difficulty weight" Phase 7 says to KEEP for accumulation.
- It's *derived* two ways: `difficulty(for: CatalogExercise)` and `difficulty(for: node:)` (`MovementCatalog.swift:1594`, which itself reads `node.tier` + `node.rank`). So node tier already *feeds* MovementDifficulty — not the reverse.
- **Verdict:** there is **no "separate MovementDifficulty axis on skill nodes" to fold.** It cannot fold into `placementRank` without breaking the XP multiplier and the catalog. The plan's Phase 4 line about `MovementDifficulty` is **based on a wrong premise** — recommend striking it from Phase 4 (it's already protected by Phase 7's "keep the difficulty weight").

## 6. `SkillRank` (E/D/C/B/A/S) — `node.rank`, live UI

`enum SkillRank { e,d,c,b,a,s }` with `unboundLabel` (Dormant/Awakened/Forged/Sharpened/Unbound/Ascended), `tagline`, `accentColor`, `rankTitle` (maps to `RankTitle.legacyLetterFallback`). `SkillNode.rank: SkillRank = .d` (`SkillTree.swift:132`). (Note: Phase 2's plan text said it would delete SkillRank; per this prompt it was reclassified to internal-only and survives — confirmed it's still present and consumed.)

**~10 live consumers:**
| File | Use |
|---|---|
| `ClusterStaircaseView` (8) | rank **bands**, band sort anchors, `bandTint(for:)`, rank-title badges — the staircase's whole vertical difficulty banding |
| `SkillTreeSkin.bandTint(for: SkillRank)` | skin tint per rank band |
| `ClusterCardView:262,271` | `rankPill(rank:)` + `accentColor` glow |
| `SkillDetailView:118,305,323` | `skillRank:` param, header subtitle, `rankDescription(for:)` |
| `RewardComputer:51,95,121` | `skillRank` / `skillRankAfter` in reward summary + `RankUp` |
| `displaysMythic` (`SkillTree.swift:242`) | `rank == .s` drives mythic visual treatment |

**Fold into `placementRank`:** mechanically, `placementRank` (9-bucket RankTier from tier) could replace `node.rank` as the band/sort key. But:
- SkillRank's **6 buckets** (E–S) ≠ RankTier's **9** — the staircase bands, skin tints, and badge set are authored against 6. Re-banding to 9 changes the visual rhythm of every cluster staircase.
- SkillRank's **bespoke copy** (Dormant/Awakened/Forged/Sharpened/Unbound/Ascended + 6 taglines + 6 accent colors) has no RankTier equivalent. Folding means: **(a)** map 6→9 and drop the bespoke copy, **(b)** keep the copy as node flavor text decoupled from rank, or **(c)** re-author 9 labels/taglines/colors. **This is a product/brand decision.**

## 7. `NodeState` — 4 states, all live (`SkillTree.swift:33`)

`locked / attempting / achieved / mastered`. Not a "parallel ladder" but a genuine 4-step lifecycle:
- `prereqsSatisfied` checks `.achieved || .mastered`.
- `awardSessionXP` promotes locked/attempting→achieved (Lv≥2), →mastered (Lv5 full).
- `attempting` is seeded for root nodes; `mastered` gates the XP cap + cosmetics.

Collapsing to **locked/proven** means redefining prereq satisfaction (proven = old achieved-or-mastered?), the achieved-vs-mastered cosmetic/2× distinction, and the `attempting` seed. **This is a real behavior change** (loses the "hit once vs hit 2×/mastered" distinction), not a rename. Needs a decision on whether "mastered/2×" survives as a flag.

---

## Deletion / fold plan (IF jlin approves the copy decisions)

### A. Delete `SkillLevel` + `node.levels` — blast radius
| Edit | File | Nature |
|---|---|---|
| Delete the type + `LevelTarget` + `Box` | `Models/SkillLevel.swift` (whole file) | mechanical |
| Remove `var levels`, ctor param, builder copy | `SkillTree.swift:135,191,217,351` | mechanical |
| Strip 675 `SkillLevel(...)` from 135 nodes | `SkillTreeContent.swift` (~675 lines) | mechanical (bulk) but huge diff |
| **Re-point / drop criterion copy** | `SkillDetailView` (7 sites), `OverviewTabView:80` | **needs copy decision** |

The only non-mechanical part: 8 read sites supply per-node "what's next" / "your first rep" / per-tier fallback strings. Options:
- **(1) Drop them** — rely on existing `?? "fallback"` generic strings (already present). Cheapest; UI loses per-node specificity for the Lv breakdown.
- **(2) Re-source from `tierCriteria`** — `fallbackRankCriterion` is *already* a fallback for when `tierCriteria` is missing; if Phase 3's `tierCriteria` covers these tiers, the level-criteria fallback is largely redundant. Verify coverage first.

`placementRank` does **not** replace `node.levels` — they're orthogonal (placement = difficulty bucket; levels = criterion copy). The plan conflates them.

### B. `placementRank` from `tier`
Add `var placementRank: RankTier { /* map tier 1–8 */ }` computed on `SkillNode`; re-point the band/sort/`displaysMythic` consumers from `node.rank` onto it. Then `node.rank` (SkillRank) can be deleted **only after** consumers move and the copy decision (§6) is made.

### C. `MovementDifficulty` — **no change.** Strike it from Phase 4 scope.

---

## Decisions for jlin (vs. mechanical execution)

| # | Decision | Why it's a decision, not execution |
|---|---|---|
| D1 | **Lv1–5 criterion copy** after `node.levels` deletion: drop / re-source from `tierCriteria` / re-author | Removes per-node UI strings on 135 nodes |
| D2 | **SkillRank bespoke copy** (Dormant…Ascended + taglines + colors): drop / keep as flavor / re-author 9 | Brand voice + 6→9 re-banding of every staircase |
| D3 | **tier 1–8 → RankTier (9)** mapping (off-by-one; no tier 0) | Defines the whole placement scale |
| D4 | **tier-vs-prereq reconciliations** (~10–25 claimed, unverified) | Per-node authoring judgment |
| D5 | **`NodeState` → locked/proven**: does "mastered / 2×" distinction survive as a flag? | Real behavior change, not a rename |

Pure mechanical (no decision): deleting the dead `SkillLevel` type + `xpReward` + `LevelTarget` plumbing; adding `placementRank`; confirming the `.new` file is build-artifact-only (nothing to delete in repo).

---

## Recommendation

**Phase 4 is NOT a safe mechanical sweep. It needs a checkpoint first.** Specifically:

1. **`SkillLevel`/`node.levels` deletion is safe-to-delete-as-code** (zero progression consumers) but **gated on D1** (the criterion copy). Recommend: verify Phase-3 `tierCriteria` coverage, then **drop** the level-criterion copy (option 1/2) — don't re-author Lv1–5 strings for a ladder we're killing.
2. **Strike `MovementDifficulty` from Phase 4** — it's the live XP weight Phase 7 keeps; the plan misclassified it as a skill-node axis. No edit.
3. **`SkillRank` fold + `NodeState` collapse are real refactors** behind brand (D2) and behavior (D5) decisions — get those answered before touching code, or they'll be re-litigated mid-sweep.
4. The **`.new` 336 KB dupe doesn't exist in source** (only `.derivedData-*/`); the Phase-4 "delete the dupe" step is a no-op for the repo.

Net: the *dead* part (SkillLevel) is real and matches the hard-lesson pattern (it genuinely grants no XP) — but the surrounding Phase-4 framing has two factual errors (MovementDifficulty, tier 0) and three product decisions buried inside it. Resolve D1–D5 with jlin, then the SkillLevel deletion + placementRank addition is clean.
