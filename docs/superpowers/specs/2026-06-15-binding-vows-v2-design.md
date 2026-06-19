# Binding Vows v2 — Design Spec

**Date:** 2026-06-15
**Status:** Approved design, pending implementation plan
**Supersedes:** `docs/binding-vows-v1.md` (lifestyle-lanes sketch) and the current Ember/Overdrive/Apex "intensity" vow model.

---

## 1. Problem

The current Binding Vows (the "Trials" / Weekly Vow subsystem) don't earn their name. Grounded in the current code:

- **The reward is modest.** Completion grants flat XP (Ember 60 / Overdrive 120 / Apex 240), ~250–370 shop currency, and progress toward titles (3/7/15) / badges (every 3) / cosmetics (every 5). Against a real session (~400–600 XP) the vow XP is a topping, and Ember's +60 is a rounding error.
- **The "sacrifice" is toothless.** Failure adds *deferred debt* (`pendingVowPenaltyXP`) that only subtracts from your **next vow completion** — never your level, currency, or streak. Skip vows forever and you lose nothing. The words "binding / vow / fracture" promise a blood-oath; the mechanic is an ignorable IOU.
- **No real stakes / gamble.** Everything is flat and deterministic — fixed reward, fixed penalty, guaranteed payout, no wager.
- **Verification is backwards.** There is a weekend proof window (Sat 00:00 → Sun 23:59). Ember/Overdrive verify via live timer or auto-detection; the **headline Apex vow is trust-based "Mark Complete."** The highest-reward vow is the least verified.
- **Reward bloat.** A weekly nudge mints cosmetics + a title ladder, cheapening the cosmetic/title economy that should be earned through rank and training.

## 2. Goals

Turn a Binding Vow into a **weekly commitment-device bet** that:

1. Has a **real, felt stake** without ever ripping away progress the user already holds (no de-leveling, no negging).
2. Stays a **thin supplement to training**, not a habit/lifestyle tracker.
3. Pays in **prestige, not XP velocity** — winning must never let engaged users rush past content and the rank curve.
4. Has **honest verification**: track where we can, self-accountability where we can't.
5. Has a **lean, theme-true reward** instead of generic cosmetic bloat.

## 3. Core Concept

A Binding Vow is a **self-directed weekly bet**. The user voluntarily binds themselves to a lightweight commitment and backs it with a real XP stake. The only uncertainty is whether they follow through — there is no RNG. Taking a vow is opt-in; **skipping the week risks nothing**, so the app never punishes a user who didn't choose to bind. This is the Jujutsu-Kaisen "binding vow" fantasy: accept a restriction for amplified standing.

## 4. Weekly Flow & Cadence

- **Weekly.** Fresh cards each Monday (local week), judged at week's end. Deliberately a tight, un-forgettable feedback loop — multi-week vows were rejected because they decay into a habit tracker and drift from being a supplement to the system.
- Each week the user is shown **3 vow cards**, spanning lanes and bet sizes, drawn from a **curated bank pool** (see §6).
- The user **takes one card or skips.** A taken vow is **bound** for the week.
- **Window/judging:** the vow is evaluated **pass/fail at the end of the week.** Pass → payout (§5). Fail (week closes without the target met) → the stake is owed (§5).

## 5. Stake & Payoff Economics

### Bet size = the card's in-week ambition

The stake is **not** arbitrary; it falls out of how much the card asks for that week (do it 1× / 2× / 3×, etc.). Each bank-pool card is authored with a bet size.

| Bet | Break → owe (stake) | ≈ workout | Clear → win |
|-----|---------------------|-----------|-------------|
| Small  | 150 XP | ~⅓ | +50 XP |
| Medium | 250 XP | ~½ | +100 XP |
| Large  | 300 XP | ~⅔ | +150 XP |

These are anchored to a real session (~400–600 XP). The asymmetry is intentional:

- **The win is a token** (+50/100/150) so success **never rushes the curve**. The real reward of winning is the commitment kept + the badge/sigil.
- **The loss is a real chunk of a session.** Because the bet is self-directed, a disciplined user almost always wins; the debt only bites flaky weeks.

### The garnish mechanic (the one true mechanical change)

On a broken vow, the stake becomes **XP debt that is withheld from the user's next *earned* training XP** — NOT subtracted from their existing total.

- Debt is stored (e.g. `pendingVowDebtXP`).
- On each subsequent XP-earning event, earned XP **pays the debt first**: `applied = max(0, earned - debt)`, `debt = max(0, debt - earned)`.
- **Your total XP never decreases and you never de-level.** Your bar simply doesn't move for the next session or two until the debt clears.
- This is unavoidable (can't be dodged by skipping future vows, unlike today) yet never feels like the app confiscated earned progress — it feels like the hard work you owe yourself.

This **replaces** the old `pendingVowPenaltyXP` (next-vow-only deduction).

## 6. Card Source — Curated Bank Pool

- Vow cards come from a **hand-authored bank pool**, organized by lane, each with a name, copy, target, and bet size (e.g. *Still Water Vow — 1 recovery reset — Small*).
- Each week, **draw 3** (varying lane + size). Authored copy keeps quality and theme tight and is trivially expandable over time.
- **Light targeting** (not full generation): the draw may be weighted toward a lane the user has neglected (e.g. surface Recovery after a hard week). This is a soft bias on top of the pool, not per-user card synthesis.
- Replaces the current `TrialGenerator` per-profile card generation.

## 7. Lanes & Verification

Track where we can, self-accountability where we can't. UNBOUND stays a training app — these are thin commitments, not a new progression system.

| Lane | Example commitment | Verified by |
|------|--------------------|-------------|
| **Recovery** | 1 recovery reset this week | Auto-detected from a logged recovery session |
| **Engine** | 1–2 easy cardio sessions | Auto-detected from logged cardio |
| **Fuel** | 3–5 fuel anchors (protein / hydration / meal-prep) | Self-report taps |

- **Recovery / Engine** complete automatically when a qualifying logged session appears after the vow is taken, within the week. Reuses existing logging (recovery days, `LogCardioView`).
- **Fuel** is a lightweight **self-report check-off** — the user taps to log each anchor. No calorie tracking, no external proof; the **stake is the honesty mechanism.**
- **Architecture guardrail:** Fuel anchors are **vow-scoped check-offs only.** They feed the vow's completion and nothing else — no parallel XP/rank/attribute path. This preserves the one-logging-spine guardrail.
- Heavier proof (live timers, stricter detection) is **deferred** — added later only if a lane proves gameable.

## 8. Rewards (Lean, Theme-True)

1. **XP** — per §5 (token on win; the bet itself is the draw).
2. **Vows badge track** — one general track with milestones for vows kept (e.g. 5 / 15 / 30 / 52 — exact numbers are tuning).
3. **Vow Sigil** — a single evolving oath-mark on the profile. Each kept vow seals a segment; it *is* the user's visible vow record. Optional spice: a broken vow leaves a faint **fracture** that **self-heals over time** (so it never tips into negging).
4. **Lane seal emblems** — Recovery / Fuel / Engine seals as the badge-track art.

No vow-minted generic cosmetics, no title ladder, no shop currency.

## 9. Teardown & Migration

Remove (and clean up dead wiring, per dead-code discipline):

- The **Ember / Overdrive / Apex** intensity card model → replaced by Recovery / Fuel / Engine lanes.
- Vow-fed **title ladder** (3/7/15 via `TitleThresholdEvaluator` for vows).
- Vow-fed **cosmetic-every-5**.
- Vow **shop-coin drip** (the `CurrencyWalletStore.grant(250 + …)` in `TrialsService`).
- `pendingVowPenaltyXP` next-vow-only debt → replaced by §5 garnish.

Migration:

- **Already-unlocked** titles/cosmetics are **kept** (never revoked); vows simply stop minting new ones.
- Any persisted in-flight vow state migrates to "skipped/closed" cleanly on first launch of v2.

## 10. Rules / Edge Cases

- **One vow per week.** Pick one of 3 or skip.
- **Skip = zero stakes.** No penalty, no streak effect.
- **Switching:** a short **grace window** after picking (e.g. before any progress / within ~24h) lets the user change their pick with no penalty (guards mis-taps). After that, the vow is bound — abandoning it counts as a break and owes the stake.
- **Pass/fail at week close.** Partial progress on a broken vow earns nothing (no proportional credit) — keeps it simple and binding.
- **Debt persists across weeks** until paid by earned XP; taking new vows while in debt is allowed (new wins still pay out, but earned XP keeps clearing debt first).

## 11. Architecture Touchpoints (for the plan)

- `Services/Trials/TrialsService.swift` — weekly generation → bank-pool draw; remove currency grant; completion/skip/switch flow; week-close judging.
- `Services/Trials/WeeklyVowRewards.swift` — replace penalty/bonus catalog with §5 stake/payout; emit garnish debt instead of next-vow debt.
- `Models/TrialCardKind.swift` / `TrialTheme.swift` / `TrialCard.swift` — replace Ember/Overdrive/Apex + axis themes with Recovery/Fuel/Engine lanes + bet sizes; bank-pool card model.
- `Services/Trials/TrialGenerator.swift` → bank-pool source + light targeting.
- `Services/Trials/TitleThresholdEvaluator.swift` — drop vow title-ladder usage.
- `Services/Progression/OverallLevelService.swift` — garnish hook: withhold earned XP against `pendingVowDebtXP` before applying.
- `Models/TrialsState.swift` — `pendingVowPenaltyXP` → `pendingVowDebtXP`; vow-kept counters for badge/sigil.
- New: **Fuel anchor** self-report surface (vow-scoped); **Vow Sigil** + lane-seal assets.
- Reward sequence: `WeeklyVowRewardCallout` / `WorkoutRewardSequenceView` — reflect new payout + sigil seal; keep it from "restating" (consistent with the recent reward-screen trim).

## 12. Success Criteria

- Breaking a vow **visibly withholds the next session's XP** (the bar doesn't move) and **never de-levels** the user.
- Skipping a week costs **nothing**; a user who never opts in is never punished.
- Vows mint **no** generic cosmetics, titles, or currency; they award **XP + the Vows badge track + the Vow Sigil/lane seals** only.
- Recovery/Engine auto-complete from logs; Fuel completes via self-report taps and feeds **only** the vow (guardrail intact).
- Cards come from a curated pool; the 3 weekly options span lanes and bet sizes.
- Subjectively: taking a vow feels like a **real weekly bet**, not a toothless checkbox.

## 13. Deferred / Open (not in this scope)

- Exact **bank-pool content** (card names/copy/targets per lane).
- Exact **badge milestone** numbers and **Vow Sigil** visual design / art production.
- Targeting algorithm specifics (how strongly to weight neglected lanes).
- Exact **Fuel anchor** definitions and the self-report UI.
- Any **heavier proof** for self-report lanes (only if gaming shows up).
