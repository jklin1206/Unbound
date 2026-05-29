# Workstream B1 — "Computed but never applied" · Report

**Date:** 2026-05-28
**Coordinator:** main session (sequential — B1 shares the progression/ranking/generation engine, so no parallel fan-out per the impact-radius pass)
**Result:** ✅ All 6 B1 items addressed with falsifiable proofs, integrated to `main` and pushed to `origin`. #4b shipped as **mechanism + one representative gate** (full per-rank skill content is a deferred balance pass, per decision). Full suite: **980 tests, 0 failures.**

---

## What shipped (one commit per item, each TDD-proven)

| # | Item | Commit | Proof |
|---|---|---|---|
| 1 | **Velocity / LV layer** | `16c241e` | Vet (elite/compound) vs beginner (beginner/isolation) at **equal volume** → identical LV on the flat path (the bug), divergent on the weighted path. 7 tests + 24 regression. |
| 2 | **Honest staleness signal** | `8f519ac` | 31d idle → `isStale` + recent<peak, while peak/xp/level unchanged (rank never lost). Surfaced as RECENT-vs-PEAK in the attribute detail. 3 + 21 regression. |
| 3a | **Checkpoint load-bias applied** | `d1cc40b` | Recovery Checkpoint → next-Arc total main sets strictly **<** neutral; push → **>**; neutral band unchanged. 4 + 3 regression. |
| 3b | **Auto-deload (no Coach tap)** | `6201b71` | 2 plateaus → states deload automatically; anti-thrash (no re-deload when already deloading); week-4 → deload. 4 + 10 regression. |
| 3c | **Rank-gated realization/peaking** | `390aa58` | Verified the "no peaking" note was **stale** — LocalProgramGenerator already emits rank-gated blocks (realization @ B-, peaking @ A-). Locked with 4 tests. |
| 4a | **Trials gate on PEAK not current** | `ead2f3e` | Peaked-at-floor + current=0 → attribute gate met; peak below floor → locked. Resolves the false WS-C "peak-gating already landed" note. 2 + 47 regression. |
| 5 | **Skill auto-proof hold/steps/carry/composite** | `890d0ca` | 60s L-sit → 10s hold node achieved+mastered; <target → locked; carry needs load; composite needs all parts. 5 + 11 regression. |
| — | **Stale legacy guardrail test** | `934fac0` | Pre-existing B2 failure surfaced by the full-suite gate; corrected to the loggers-fix intent (legacy path is side-effect-free for progression). |

---

## Design notes

- **Velocity is LV-only.** Per-lift SubRank + skill tiers are objective StrengthStandards and stay pure. The "ability invisible" surface is the gamified overall level (`OverallLevelService.ingest` did `Σ rawAP × novelty`, intensity relative to the user's own baseline). New pure `VelocityWeighting` weights per-movement AP by intrinsic difficulty (skill) + compound bias, applies a capped comeback multiplier, and adds a rank-up bolus. Magnitudes centralized for one-line tuning.
- **Staleness is honest, not punitive.** `AttributeDrift` already drifts `current` toward a floor; the missing piece was an explicit per-axis `isStale` flag so "recent" never masquerades as ability. Peak/xp/level untouched — consistent with #4a (trials gate on peak).
- **Auto-deload reuses existing machinery.** `DeloadPlanner.shouldDeload`/`planDeload` existed but only fired on a Coach tap. `AutoDeloadService` runs at the end of `ProgressionEngine.ingest` (the single seam every log path flows through) with an anti-thrash guard.

---

## #4b — path-aware "any N of" skill gates (mechanism shipped, content deferred)

**Finding:** the per-skill gating machinery existed but **every trial definition had `skillStandards: []`** — trials ignored skills, and `skillStandards` is a hard AND (a lifter would be blocked by a cali skill, and vice versa).

**Shipped (`e0ad10c`):** `OverallRankTrialSkillGroup` — an "any N of" gate satisfied when any `minimumCount` of its options are met, so each athlete path has a route. Additive/backward-compatible field; wired into `requirementLines`. The Master gate ("The Tower") carries a representative group: any 1 of {muscle-up (pull), pistol squat (legs)} at Novice+. Proven via either path.

**Deferred (balance pass):** the full per-rank skill content — which skills gate which rank for each path across all mid/high gates — is a progression-balance/product decision, to be specced separately. The mechanism is ready to populate.

---

## Deploy / push status

No server changes in B1 (all client engine) — nothing to deploy. All 10 commits pushed to `origin/main`.
