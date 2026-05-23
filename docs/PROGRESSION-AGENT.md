# UNBOUND Progression — Agent Reference

**Read this first when touching any progression, ranking, attribute, body-map, level, or trial code/UI.**

The full canonical spec lives in **[`PROGRESSION.md`](./PROGRESSION.md)**. That document is the source of truth — defer to it on any conflict.

## TL;DR of the system

- **5 first-class progression systems + 1 currency:** Skills · Movements/Lifts · Attributes (POW/AGI/END/CTL/MOB/EXP) · **Overall LV** · Overall Rank · AP.
- **2 diagnostic surfaces:** Body Map (heat, never ranked) · Trial Readiness Card.
- **1 universal ladder:** 9 tiers — Initiate → Novice → Apprentice → Honed → Forged → Veteran → Vessel → Unbound → Ascendant. Used by skills, movements, attributes, and overall rank.
- **AP is the currency** of every set — fans out into movement progress, attribute XP, body-map saturation, **and Overall LV XP**.
- **Standards gate rank-ups.** AP doesn't. You only rank up a lift by hitting its explicit weight/rep target.
- **Skills have variant trees** (Pull-Up: assisted → strict → archer → OAPU). **Movements/lifts don't** — they only have weight/rep standards.
- **Overall LV is the global level counter** — single concave-curved XP pool, fed by AP. The unified "I am leveling up" signal across the whole app.
- **Overall Rank is gated by trials.** 8 trials, one per tier transition. Each trial is a single named brutal workout with equipment + path variants. Each trial has a **Min Overall LV** gate.
- **No archetypes** as behavior drivers. Removed.
- **No body-part ranks** ever. The body map is diagnostic only.
- **Specialization is supported.** Top-4-of-6 attribute floor at higher tiers lets specialists ascend without becoming hybrids.

## LV velocity mechanics (no calibration onboarding)

The system **does not ask the user to declare their stats upfront** — no 1RM survey, no honor-system seeding. Vets ramp LV fast organically through:

- **Rank-up LV boluses scale fast with tier** (Novice 50 → Ascendant 12,000). A vet hitting upper-tier ranks in month 1 gains thousands of LV XP organically.
- **Skill difficulty multipliers on boluses** (L-Sit 0.8× → Planche 2.5×) — harder-to-acquire skills reward more LV on rank-up.
- **Compound velocity multiplier** — 3+ rank-ups in 30 days → 1.25× on subsequent boluses; 5+ → 1.5×.
- **Trials still gate everything in order** — you cannot trial up out of order regardless of how fast LV climbs.

Realistic time-to-Ascendant: vet 6–9 months, intermediate 12–18 months, beginner 18–24+ months.

## Atrophy & comeback (the no-decay rule)

**Nothing earned ever decays.** Movement ranks, skill ranks, AP, attribute XP, and Overall LV are all permanent. The Vessel rank earned two years ago stays Vessel even after a 6-month layoff.

Staleness is signaled (not punished) via display layers:

- **Recent best vs. lifetime best** per movement (90-day rolling window) — the rank stays at lifetime, the recent best surfaces current capability honestly.
- **Stale flag** (🌫️) on movements/skills after 30+ days of no logged work. Clears on next qualifying set. Doesn't change rank.
- **Body map saturation** decays as already designed — cold regions = haven't trained.

The **comeback path** is trial re-runs:

- Returning user (4+ weeks of < 2 sessions/week) + completes a previously-passed trial → **1.5× LV velocity multiplier for 30 days**.
- Comeback velocity does NOT stack with compound velocity. System uses `max(compound, comeback)`.
- Trial re-run is the *calibration mechanism* — behavior-based, never a form/survey.

Realistic time-to-Ascendant for a returning vet: 6–9 months from re-engagement, with the comeback boost accelerating the rebuild.

## The 8 trial workouts

1. **The Awakening** (Initiate → Novice) — ritual establishment chipper
2. **The Calibration** (Novice → Apprentice) — AMRAP density
3. **The Forge** (Apprentice → Honed) — 3-round chipper w/ run + weighted + pull
4. **The Reckoning** (Honed → Forged) — heavy → conditioning → heavy sandwich
5. **The Gauntlet** (Forged → Veteran) — Hyrox-style 8-station hybrid
6. **The Ten Hundred** (Veteran → Vessel) — 1000-rep volume hell
7. **The Restriction** (Vessel → Unbound) — 4-phase limit-breaking session
8. **The Ascension** (Unbound → Ascendant) — 5-phase 90-min athletic warfare

Each is single-session, has equipment + path variants, named.

## Do not ship anything that contradicts these:

- Body parts are not rankable.
- Attributes are not directly grindable (only derived from AP via weight vectors).
- Overall LV is not derived from rank — it's its own XP pool fed by AP.
- Overall LV does not gate movement, skill, or attribute rank-ups. It only gates trials.
- **Do not ask users to declare 1RMs, max reps, or holds upfront.** The system observes training behavior, rewards organically. Same rule applies to returning users — re-run a trial, never a survey.
- **Earned progression never decays.** No percentage decay on AP/LV/attributes. No rank demotion. Staleness is shown via recent-vs-lifetime, stale flags, and body map heat — never via stripping ranks.
- Trial workouts must be distinct in format from each other — no Murph-clones.
- Trials are single-session. No multi-day trials.
- Movement ranks require hitting the explicit standard. AP alone never ranks up a lift.
- Both Lifter and Calisthenics paths must be able to reach Ascendant.
- "Lo-fi" is not the visual brief — clear and sharp iPhone-style is.
- Skill standards across different skills must be calibrated for equivalent capability at the same tier (rank-up LV boluses scale by inherent skill difficulty separately).

For everything else — math, trial workouts, UI surfaces, failure modes, exact requirements per trial including the LV gates and bolus tables — read **[`PROGRESSION.md`](./PROGRESSION.md)**.
