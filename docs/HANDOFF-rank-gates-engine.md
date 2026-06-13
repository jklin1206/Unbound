# Agent Handoff — Rank Gates Engine (Plan 1 of 4)

Branch: `claude/rank-gates-engine` (off `claude/premium-home-profile-redesign` @ `6f66fe42`)
Worktree: `/Users/jlin/Documents/toji/UNBOUND-agent-a`
Lane: A (sim iPhone 17, DerivedData `/private/tmp/unbound-dd-a`)

## Summary
Engine foundation for the rank-gates redesign (spec `docs/superpowers/specs/2026-06-12-rank-gates-redesign-design.md`,
plan `docs/superpowers/plans/2026-06-12-rank-gates-engine.md`). All 8 destination-world gates, the new
station machinery, and Gate Keys eligibility — engine only, no new UI (UI is Plans 2–4). Built by Codex
(GPT-5.5, xhigh) under orchestration; every step verified by me + an adversarial Codex review pass.

16 commits (`6f66fe42..HEAD`):
- 6 machinery: gate-named `RankTrialFormat` + tolerant legacy decode; `TrialStandards` rebaseline;
  per-option `floorOverride`; strength-tier strike floors (reps+load same-set); dynamic weakest-attribute
  resolution; strike same-set fix.
- 8 gate definitions: I First Light · II The Count · III The Forging · IV Deck of Proof · V The Ascent ·
  VI The Seven Seals · VII The Threshold · VIII The Last Gate.
- 1 Gate Keys (named eligibility proofs auto-cleared from training history).
- 1 review-fix (the adversarial-review findings below).

## What each gate is (engine)
Names/structures per spec §5. Old format raws + old definition ids preserved as `legacyIds` (tolerant
decode + id/legacyIds lookups) — no on-disk migration, no attempt-history loss. `TrialStandardsSnapshotTests`
golden rebaselined deliberately. Gate VIII's six `lastgate-landing-6-<attribute>` stations share a
`dynamicGroupKey`; the draft resolves to the user's weakest attribute, and evaluation's candidate-picker
collapses the group to whichever was logged.

## Verification done
- Trial/gate/keys suites green: GateDefinitionTests, GateKeysTests, OverallRankTrialFormatTests,
  OverallRankTrialServiceTests (+Completion/+DraftMapping/+Evaluation/+Readiness), TrialStandardsSnapshotTests
  — 88 tests, 0 failures.
- Full suite: only 3 failing tests (18 assertions) — ALL pre-existing, proven byte-identical on baseline
  `6f66fe42` (asset-PNG dupes, a weight-rounding test, a band-swap program-gen test; none touch rank trials).
  Gate branch introduces ZERO regressions.
- Device-arch build green: `xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`.
- Hygiene: 0 TEMP shims, 0 old static props/builders, 0 stale display names outside legacy contexts.
- Adversarial Codex review (independent): found 5 in-scope correctness defects → fixed → Codex re-review
  verdict RESOLVED, no new defects.

## Adversarial-review fixes already applied (commit `995e1101`)
1. Gate III ("no clock") was hard-capped at estimatedMinutes → `enforcesTotalTimeCap` opt-out (Gate III false).
2. Threshold carry Gate Key keyed on un-persisted carry distance → would PERMANENTLY LOCK Gate VII; replaced
   with a SetLog-provable loaded-press proof + an all-gate "no key depends on an unstorable field" guard test.
3. readiness/progress attempt lookups ignored `legacyIds` → post-rename history loss; now match id||legacyIds.
4. strength-tier strike failed OPEN on unresolved ratio → now fails closed.
5. loadPercent carry could pass via split sets → same-set conjunction (mirrors the strike fix).

## NEEDS YOUR DECISION — balance/design items I deliberately did NOT change (your §14 checkpoints)
These change game difficulty and were "confirm/adjust at phase start" items; I left them at the
implemented baseline rather than guess. Each is a one-line call:
1. **Gate VI POWER seal** — implemented as a single Vessel-tier hinge strike. §14 #2 default was
   "hinge + press, 3 reps each". Add the press half? (currently hinge only)
2. **Gate VI MOBILITY seal** — implemented as a 60s deep-squat hold only. §14 #3 default was
   "60s WEIGHTED deep-squat hold + 10/side cossack". Add weighted-hold enforcement + cossack reps?
   (Note: `TrialStandards.SevenSeals.mobilityCossackRepsPerSide` exists but is intentionally unwired pending this call.)
3. **Gate III "Stoke the Fire"** — implemented as a scored 300m engine (min 1 qualifying set). Spec intent
   is an UNSCORED warm-up. Make it truly unscored (exclude from pass/fail)?
4. **Gate Keys table (§14 #5)** — early gates (First Light / The Count / Deck of Proof) return NO keys by
   design (spec §7: LVL+accumulation suffice; deck capacity IS the trial). Seven Seals = 1 key (hexagon),
   Last Gate = 1 key (7 gates answered). Spec §14 says "2–3 keys each" — a spec internal inconsistency.
   Confirm the per-gate key set, or expand.

## Deferred to later plans (by design, not gaps)
- All UI: NextGateCard, Gate Hall, entry ceremony, world-stage active view, beats, verdict, The Crossing,
  Trial Records (Plans 2–4). Old mode-view symbols (Daily100TrialModeView etc.) + their dispatch sites
  remain wired until Plan 4 deletes them.
- Art/motion generation (Higgsfield/Seedance) — Plan 3 lane.

## Risks / notes
- Codex's sandbox cannot run xcodebuild or commit in the worktree; I ran all builds/tests and committed.
- Two `git worktree` are shared with Codex refactor lanes — staged explicit paths only, never `git add -A`.
- To run locally: `cd UNBOUND-agent-a && xcodegen generate` then the test/build commands above.
