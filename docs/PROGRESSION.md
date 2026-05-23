# UNBOUND Progression System — Canonical Reference

**Status:** Source of truth for all progression, ranking, attribute, and trial logic.
**Date:** 2026-05-20
**Audience:** Designers, engineers, agents touching any system below.

This document defines every progression system in UNBOUND, how they interact, and what the user sees. Anything that contradicts this doc is wrong; update this doc first, then the code.

---

## 1. Overview

UNBOUND has **five first-class progression systems**, **one progression currency**, **one reward-callout layer**, **one optional weekly event layer**, and **two diagnostic surfaces**, all unified under a single rank ladder.

### First-class systems (each has a visible rank or level)

1. **Skills** — possession of specific positions/movements (Pull-Up, Muscle-Up, Handstand, L-Sit, Pistol Squat). Each skill has its own 9-tier ladder with a variant tree.
2. **Movements / Lifts** — strength/performance standards on tracked exercises (Bench Press, Squat, Deadlift, Lat Pulldown, Farmer Carry). 9-tier ladder by weight/rep/distance/time standard. **No variant tree** — just numerical standards.
3. **Attributes** — 6 derived stats (POW / AGI / END / CTL / MOB / EXP) with XP curves.
4. **Overall Level (LV)** — single global counter fed by raw AP earned. Concave curve. The unified "I am leveling up" signal.
5. **Overall Rank** — headline identity rank gated by trials at each tier transition.

### Progression currency (visible, but not a rank)

**AP (Ascension Points)** — the raw work ledger for each movement/skill. AP feeds attributes and Overall LV, gives users a per-session progress number, and preserves the story of training volume. AP does **not** have its own tier ladder and does **not** rank the user by itself.

### Reward-callout layer (visible, but not a currency)

Reward callouts are the visible "something happened" moments after training. They are not AP, XP, rank, or level.

V1 callouts:
- Personal records
- Badge unlocks
- First clean standard on a movement/skill
- Trial completion
- Comeback trial re-run
- Program consistency milestone

Rank-ups stay separate from callouts because rank-ups are larger tier events. XP/AP stay separate because they are currencies. The reward screen should answer three different questions cleanly:
- "What did I earn numerically?" → AP / XP
- "Did my tier change?" → rank-ups
- "What should I remember?" → PRs and badges

**Do not create a separate major system called Feats.** If a named accomplishment persists outside the reward screen, it is a Badge. If it only happened inside the session, it is a PR/callout. "Feat" may appear as casual flavor copy, but not as a data-model layer.

### Optional weekly event layer

**Weekly Vows** are optional short-term commitments that give the user something exciting to opt into during the week. They are not Overall Rank Trials and must never use the word "Trial" in product copy.

Weekly Vows have three lanes:
- **Ember** — recovery-safe rest-day work, 8-12 minutes, RPE 3-5.
- **Overdrive** — short after-workout finisher, 6-12 minutes, RPE 7-8.
- **Apex** — dedicated weekend event, 20-45 minutes, RPE 8-9.

The work itself earns normal AP, attribute XP, body-map volume, skill XP when relevant, and LV XP through the same movement pipeline as every other workout. Completing the Vow can grant bonus Overall LV XP, badge progress, cosmetic progress, and a share card for Apex clears. Vows do **not** grant artificial attribute bonuses; attributes only come from the actual movements performed.

### Diagnostic surfaces (no rank, no progression)

1. **Body Map** — anatomical regions. Tracks saturation (recent volume with decay). Drives novelty multipliers and coaching suggestions. **Never ranked.**
2. **Trial Readiness Card** — derived view that shows what the user needs to attempt the next trial.

### The trial loop

```
training → raw AP → movement ranks + skill ranks + attribute XP + LV XP + body map saturation
                                          │
                                          ▼
                              Trial requirements met
                                          │
                                          ▼
                              Attempt named brutal workout
                                          │
                                          ▼
                              Pass → next overall rank tier
```

### Implementation migration guardrail

During the unified progression migration, all new AP, attribute XP, Overall LV XP, body-map, skill XP, rank, and reward writes must enter through:

```text
PerformanceLog -> TrainingCompletionService -> unified receipt/history side effects
```

Legacy `WorkoutLog` / `SessionLog` writers may remain only as compatibility or history adapters after the replacement route is proven. Do not add new progression math, rank evaluation, reward callouts, or trial/Vow effects to those direct-save paths. Quarantined legacy paths should carry explicit `MIGRATION(Phase 9)` markers plus a focused proof or audit note before they are deleted.

---

## 2. The 9-Tier Ladder

Used everywhere — same tier names across skills, movements, attributes, and overall rank.

| # | Tier | Vibe |
|---|---|---|
| 1 | **Initiate** | Day-one starting point |
| 2 | **Novice** | First real proof of work |
| 3 | **Apprentice** | Established practice |
| 4 | **Honed** | Solid intermediate |
| 5 | **Forged** | Strong intermediate |
| 6 | **Veteran** | Advanced |
| 7 | **Vessel** | Elite |
| 8 | **Unbound** | Brand-defining tier — "break the restriction" |
| 9 | **Ascendant** | Top of the ladder, perpetual prestige |

Each system uses these tier names but with system-specific standards. "Forged" on Bench Press means 1.5× BW; "Forged" on Handstand means 60s freestanding hold; "Forged" on POW attribute means having crossed a specific XP threshold. Same tier name, different proof in each system.

---

## 3. Skills

### Definition

Skills are **capability-based goals** where the proof is demonstration of a position, movement, or clean standard. They are calisthenics-coded by nature, but not limited to vibes or judgment calls: a skill standard can use reps, holds, load, range, tempo, or form requirements when those are the cleanest proof.

### Catalog (initial)

- Pull-Up
- Muscle-Up
- Handstand
- L-Sit
- Pistol Squat

(Catalog expands over time with planche, front lever, OAPU, etc.)

### Variant trees (skill-specific)

Each skill has an internal progression tree of variants that map to the 9-tier ladder. The ladder is **calibrated so that the same tier across different skills represents roughly equivalent athletic capability** — same way Diamond in a ranked game means roughly the same skill level regardless of role.

Example calibration:

| Tier | Pull-Up | Muscle-Up | Handstand | L-Sit | Pistol Squat |
|---|---|---|---|---|---|
| Initiate | jumping/negative | bar dip control | wall-assist 15s | tuck 5s | assisted full-depth |
| Novice | 1 strict | strict bar pull above waist | wall-supported 30s | tuck 15s | strict unweighted 1 |
| Apprentice | 5 strict | 1 clean strict | freestanding 5s | 1-leg 15s | 3 unweighted |
| Honed | 10 strict | 3 strict | freestanding 20s | straddle 15s | 5 unweighted |
| Forged | 15 strict + 25 lb | 5 strict | freestanding 45s | straddle 30s | 8 + 10 lb |
| Veteran | 20 strict + 50 lb | 8 strict, deep range | press to handstand | full L 30s | 5 + 25 lb |
| Vessel | 5 + 90 lb / archer | 12 strict / chest-to-bar | press to HS × 5 | full L 45s | 5 + 45 lb / shrimp |
| Unbound | 3 OAPU each side | 5 ring MUs | freestanding 60s + walk | full L 60s + V-sit prep | 5 shrimp |
| Ascendant | 5 OAPU each side / clean human flag adjacent | 10 ring MUs / 5 strict ring | freestanding 90s + variations | V-sit 30s | 5 shrimp / 3 dragon |

Standards are tunable; this is the shape.

### AP source

Skills earn AP from logged work toward the skill — quality reps, hold time, clean attempts. AP per skill is independent (Pull-Up AP doesn't feed Muscle-Up AP unless explicitly defined to roll up).

### Rank-up gate

**Proof of position.** User demonstrates the next-tier standard (logged via video clip, multi-rep log, or timed hold). AP doesn't gate skill rank-ups; the proof does.

### Dual identity with movements

Some entries exist as both a **skill** and a **movement**. Pull-Up, Dip, Pistol Squat, and L-Sit can be trained as skill goals while also being logged as ranked movement standards.

The rule:
- The **skill** answers: "Can you perform this capability at the next progression standard?"
- The **movement** answers: "What is your best numerical performance on this exercise?"
- A log can update both only when the catalog explicitly links them.
- Skill AP and movement AP stay separate unless a roll-up is explicitly declared.

Example: a strict pull-up set may update Pull-Up movement AP and Pull-Up skill progress. It does not update Muscle-Up skill progress unless the catalog has a deliberate bridge such as high pull-ups or transition drills.

---

## 4. Movements / Lifts

### Definition

Movements are **loaded or counted exercises** where the proof is *weight × reps* or *time × distance*. They are gym-coded by nature.

### Catalog (initial)

- Bench Press
- Squat (back squat)
- Deadlift
- Overhead Press
- Lat Pulldown
- Pull-Up (counted as movement when treating it as load/rep)
- Row variants
- Farmer Carry

(Catalog expands per release.)

### **No variant tree**

This is the key distinction from skills. Movements have *one rank ladder per movement*, defined by standards. A Bench Press is a Bench Press — the rank ladder is just escalating weight or rep targets. There is no variant progression tree like "incline bench → close-grip bench → spoto press." Variants are *logged*, but they roll up into the parent movement's AP pool (e.g., neutral/wide/close-grip Lat Pulldown all feed Lat Pulldown AP).

### Rank standards (calibrated to BW)

Example for Bench Press (BW = bodyweight):

| Tier | Standard |
|---|---|
| Initiate | bar (45 lb) × 5 |
| Novice | 0.75× BW × 5 |
| Apprentice | 1.0× BW × 5 |
| Honed | 1.25× BW × 5 |
| Forged | 1.5× BW × 5 |
| Veteran | 1.75× BW × 3 |
| Vessel | 2.0× BW × 3 |
| Unbound | 2.25× BW × 1 |
| Ascendant | 2.5× BW × 1 |

Each movement has its own calibrated table. BW-relative standards by default; absolute weight (225, 315, 405) shown as alternate landmarks for cultural recognition.

### AP source

Per-set AP, intensity-weighted (see §7).

### Rank-up gate

**Hit the standard.** AP doesn't gate the rank; the explicit weight/rep target does. You can't grind 1000 sets at 50% RM and rank up — you have to hit the actual number for the next tier.

---

## 5. Attributes (POW / AGI / END / CTL / MOB / EXP)

### The 6 attributes

| Code | Name | What it captures |
|---|---|---|
| **POW** | Power | Raw force / strength expression |
| **AGI** | Agility | Change of direction / coordination / footwork |
| **END** | Endurance | Sustained capacity / conditioning / cardio |
| **CTL** | Control | Stability, form, balance, isometric strength |
| **MOB** | Mobility | Range of motion, flexibility, joint health |
| **EXP** | Explosiveness | Rate of force / power output / quick burst |

### XP curve

Each attribute has its own XP pool with a concave growth curve until LV 100, then a fixed late-game cost so the meter never becomes dead:

```
if L <= 100: xp_required_for_attribute_lv[L] = attr_base × L^1.5
if L > 100:  xp_required_for_attribute_lv[L] = xp_at_100 + (L - 100) × 1,500
```

So Initiate → Novice is cheap (~200 XP), Vessel → Unbound is hard (~8000 XP), Unbound → Ascendant is brutal (30k+).

### How XP is granted

Every exercise has an **attribute weight vector**: `{POW: 0.5, CTL: 0.3, END: 0.2, ...}`. When the user logs a set, the awarded whole AP funnels into the attributes via the vector, multiplied by the body map novelty bonus.

```
attribute_xp[a] += round/reconcile(awarded_AP × attribute_weight[a] × novelty_multiplier)
```

### Attribute Level (the per-axis number on the hex)

Every attribute has a **derived integer level** alongside its tier label. Same mental model as Overall LV but per attribute — small readable integer, grows forever. The per-level cost caps after LV 100.

```
if xp < xp_at_100:
    attribute_level[a] = floor( (attribute_xp[a] / attr_base)^(1/1.5) )
else:
    attribute_level[a] = 100 + floor((attribute_xp[a] - xp_at_100) / 1,500)
```

The curve mirrors LV: early levels tick over fast, mid levels take more work, and late levels keep moving at a fixed prestige cadence. This gives the system a **third dopamine cadence** between per-set XP (`+47 POW`) and per-tier rank-ups (`POW reached Honed`):

```
per-set:     "+47 POW XP"                ← every set
per-level:   "POW LV 15 → 16"            ← every few sessions
per-tier:    "POW reached Honed"         ← every few weeks/months
```

Attribute level is the integer that lives on the hex axis. Tier is the prestige label underneath.

### Display

The hex visualizes attribute levels on a **shared progression scale** (all users use the same axis math). Attribute XP can grow forever, but the chart should not become a cluttered 9-ring target or a maxable 0-100 shape. The visual uses a compressed display curve with a prestige glow after LV 100.

```
effective_attribute_lv = attribute_level + progress_to_next_level

if effective_attribute_lv <= 100:
    hex_axis_fill = 0.92 × (effective_attribute_lv / 100)^0.9
else:
    hex_axis_fill = 0.92 + 0.08 × (1 - e^(-(effective_attribute_lv - 100) / 75))

prestige_glow = max(0, 1 - e^(-(effective_attribute_lv - 100) / 75))
```

So LV 12 is still a small slice, LV 50 is a meaningful build shape, LV 100 is near the outer edge, and post-100 levels keep adding glow/pressure without pretending the stat is capped.

Each axis on the hex shows: **`<ATTR> <level>`** (e.g. `POW 14`). Tier label sits underneath as the prestige clue.

The hex should communicate build shape first: POW-heavy, CTL-heavy, balanced hybrid, etc. The detailed rank/tier math lives in the axis labels and drill-down, not in nine dense rings.

Per-attribute display on the profile card (drill-down):

```
POW  LV 14 · Apprentice  1,247 XP   → Honed in 753 XP
```

Attribute level + tier label + numerical XP + distance to next tier.

### Where users see XP

- **Reward screen** after every workout: `+85 POW XP (×1.4 fresh stimulus)`
- **Profile hex**: tier label per axis + small bar fill at the tip
- **Profile detail (tap hex axis)**: full XP breakdown, contributing exercises, novelty patterns

---

## 6. Overall Level (LV)

### Definition

A **single global counter** that ticks up from every session. It is the unified "I am leveling up" dopamine signal across the whole app, distinct from per-attribute XP (which expresses *what kind* of athlete you are) and per-movement AP (which expresses progress on a specific lift).

### How LV XP is earned

Every raw AP point earned anywhere contributes to Overall LV XP. The default is 1:1 before freshness bonuses:

```
overall_lv_xp += raw_AP_earned    # every set, every skill rep contributes
```

PR bonuses on lifts also bonus to LV. The novelty multiplier from the body map applies once when raw AP is converted into LV XP — varied training rewards LV growth more than spamming, without inflating the underlying movement AP ledger.

### LV curve

Piecewise. Early levels are cheap; mid levels slow down; late levels cap at a fixed cost so leveling never becomes impossible. Beginners feel constant motion; veterans feel each level as a milestone without the account meter going dead.

```
if L <= 100: xp_required_for_lv[L] = lv_base × L^1.5
if L > 100:  xp_required_for_lv[L] = xp_at_100 + (L - 100) × 3,750
```

Same curve shape as attributes, but the LV pool is far larger because it aggregates from every set. After LV 100, attribute levels cost 1,500 XP each and Overall LV costs 3,750 XP each.

### Why LV exists alongside attributes

| Question | Answered by |
|---|---|
| What kind of athlete am I? | Attribute hex shape |
| How strong/skilled am I at X? | Movement rank + Skill rank |
| Where am I on the journey? | Overall Rank |
| How much have I trained in total? | **Overall LV** |

LV is the **time-in-game** signal. A user can hit specific movement standards relatively fast if they came in already strong, but they can't reach a high LV without putting in genuine total volume. This is why LV gates trials (see §11) — it prevents min-maxers from cheesing tier promotions by speed-running specific lifts.

### Display

- **Profile headline**: `LV 47` always visible next to overall rank, with a small XP bar.
- **Reward screen**: `+340 LV XP this session` next to attribute XP gains.
- **Tier crossings**: LV milestones (LV 10, LV 25, LV 50, LV 100, etc.) fire small celebrations.

### What LV does NOT do

- LV does not gate movement or skill rank-ups (standards do).
- LV does not gate attribute tier crossings (attribute XP curve does).
- LV is not the same thing as overall rank — overall rank is identity, LV is time-in-game.

### LV velocity mechanics (no calibration onboarding required)

**Explicit design choice: the system never asks the user to declare their stats upfront.** No 1RM survey, no "what can you bench" question, no honor-system seeding. The system observes truth through training behavior. A vet's first month rewards them appropriately because they hit upper-tier ranks fast; a beginner's first month rewards them gently because they're still establishing baselines. Both fall out of the same math.

The mechanics that make organic acceleration work:

#### 1. Rank-up LV boluses (scale with tier hit)

Every rank-up grants a one-time LV XP bolus. Sizes scale fast with tier:

| New rank achieved | LV XP bolus |
|---|---|
| Novice | 50 |
| Apprentice | 150 |
| Honed | 400 |
| Forged | 900 |
| Veteran | 1,800 |
| Vessel | 3,500 |
| Unbound | 6,500 |
| Ascendant | 12,000 |

A returning vet hitting upper-tier ranks across multiple movements in month 1 picks up serious LV — easily 15,000–25,000 LV XP in 30 days. A beginner hitting Novice/Apprentice on a handful of things gets a few hundred. Both honest. Both organic.

#### 2. Skill difficulty multipliers (on rank-up boluses only)

Some skills are inherently harder to acquire. Their rank-up boluses are multiplied by an inherent-difficulty factor:

| Skill | Difficulty multiplier |
|---|---|
| Pull-Up | 1.0 (baseline) |
| L-Sit | 0.8 |
| Pistol Squat | 1.0 |
| Handstand | 1.3 |
| Muscle-Up | 1.5 |
| OAPU | 1.8 |
| Front Lever | 2.0 |
| Planche | 2.5 |

So Veteran Planche = 1,800 × 2.5 = **4,500 LV XP**. Veteran L-Sit = 1,800 × 0.8 = **1,440 LV XP**. The tier *standards* are calibrated for equivalent capability at the same tier, but acquiring Planche takes vastly more training time than L-Sit — the bolus difference acknowledges that.

For movements (lifts), the multiplier is uniform **1.0**. BW-relative standards already normalize across body sizes, so a Veteran Bench at 1.75× BW is roughly equivalent effort to a Veteran Squat at 2.25× BW.

#### 3. Compound velocity multiplier (rolling 30-day window)

Hitting multiple rank-ups in a short window is a strong signal of advanced ability. Reward it:

```
3+ rank-ups in last 30 days → 1.25× multiplier on subsequent rank-up boluses
5+ rank-ups in last 30 days → 1.5×  multiplier on subsequent rank-up boluses
```

The multiplier compounds with the skill difficulty factor. A returning athlete who stacks ranks fast triggers the multiplier, accelerates further, and reaches their honest LV ceiling quickly. A beginner gradually ranks one thing at a time, never trips the multiplier, progresses at the natural pace.

#### 4. Trials still gate everything in order

These velocity mechanics let a vet reach high LV fast (LV 60–80 in 1–2 months is plausible). But they can't trial up past their current tier — **trials must be passed in order**, and the upper trials (Restriction, Ascension) take real training to prepare for. The trial workouts are the brake that prevents calibration-cheese.

Realistic time-to-Ascendant:
- Genuine Ascendant-level vet on day 1: 6–9 months
- Intermediate user (Veteran-tier ability): 12–18 months
- Beginner: 18–24+ months

The system reads training honestly, rewards appropriately, and gates by trial workouts — which take real work to pass regardless of how fast LV climbs.

---

## 7. AP (Ascension Points)

### Definition

AP is a **whole-number per-movement/per-skill currency** that ticks up every set, rep, hold, carry, interval, or skill attempt. It's the granular per-session progress number and the audit trail for "what did this user actually train?"

AP's value:
- It gives every workout a visible reward even when no rank changes.
- It shows progress inside a specific movement/skill between hard standards.
- It feeds attribute XP and Overall LV without creating separate grindable pools.
- It lets variants roll into parent standards in a controlled, auditable way.
- It gives the app enough history to recommend substitutions, trials, and comeback paths.

### Math

```
raw_AP_per_set = base × intensity_factor × rep_factor

intensity_factor = (weight / current_e1rm) ^ 1.5    # 100% RM ~1.0; 70% RM ~0.43
rep_factor       = ln(1 + reps)                     # diminishing within a set
PR_bonus         = flat +large AP on weight PR or rep PR
```

The formula may create decimals internally, but the ledger never stores decimal AP/XP:

```
awarded_AP = round(raw_AP_per_set)
if raw_AP_per_set > 0: awarded_AP = max(1, awarded_AP)
```

The displayed reward is the true stored reward. If the UI says `+20 AP`, the movement ledger stores `+20 AP`, attributes fan out from `20`, Overall LV XP uses `20`, and level-up checks use `20`.

Body-map novelty does **not** inflate awarded movement AP. A bench set should grant the same Bench Press AP whether the user's chest is fresh or saturated. Novelty applies once when AP fans out into whole-number attribute XP and Overall LV XP (see §8).

### What AP funnels into

Every set of an exercise grants AP that fans out:

```
Set of Bench Press
  ├─ +N awarded AP to BENCH PRESS (visible per-movement)
  ├─ round/reconcile(N × attribute_weights × novelty) → POW, CTL XP
  ├─ round(N × novelty) → Overall LV XP
  └─ +saturation to CHEST, SHOULDERS, ARMS body regions
```

Attribute split rounding is reconciled so the visible total matches the stored ledger. Example: `10 AP` split evenly across three attributes becomes `4 / 3 / 3 XP`, not hidden decimals.

### What AP does NOT do

AP **does not gate rank-ups**. Rank-ups fire when the explicit standard is hit. AP is the engagement metric and progress narrative.

### Variants rolling up

Variants of a tracked movement feed the parent movement's AP pool only when declared in the catalog:

- Neutral / wide / close-grip Lat Pulldown → Lat Pulldown AP
- Hammer Strength / plate-loaded Chest Press → Machine Chest Press AP
- Goblet Squat, Front Squat, and Back Squat are separate standards unless the catalog explicitly declares a roll-up

Different movement standards **do not** cross-feed by default. Lat Pulldown AP is not Pull-Up AP. Tricep Pushdown AP is not Dip AP.

---

## 8. Body Map

### Definition

A diagnostic visualization of training distribution and recovery state across anatomical regions. **Not a ranked system.**

### Regions

Body-map regions should stay anatomical and visually understandable:
- Chest
- Back
- Shoulders
- Arms
- Core (abs, obliques)
- Legs
- Glutes
- Calves

Grip is **not** a body-map region. Grip is a performance tag/attribute contributor used by carries, hangs, rows, pulls, and loaded holds. It can appear in exercise metadata and coaching explanations, but it should not be fused with calves on the body map.

### What it tracks

```
body_saturation[region] = Σ(recent_volume × decay) over a rolling window
                        + lifetime_volume × small_factor
```

Recent volume decays with a ~10-14 day half-life. Lifetime volume contributes a small persistent baseline so historically well-trained regions stay slightly warmer.

### What it drives

1. **Novelty multiplier on attribute XP.** Low-saturation regions grant up to 1.5× XP on exercises that hit them. Saturated regions grant 1.0×. The math:

   ```
   novelty_multiplier = 1 + (1 - saturation_normalized[r]) × 0.5
   ```

   Averaged across the regions the exercise hits.

2. **Coaching layer suggestions.** The program generator reads body map signals as input. When a region has been chronically under-trained or recently smoked, the generator suggests swaps (see §13).

### UI

Heat coloring on a body silhouette. No numbers. Tap a region → see "what trained this" + "last hit X days ago."

### Why no rank

Anatomy isn't a meaningful unit of capability. "Chest rank 5" is incoherent. Ranking body parts invites isolation farming (chase the chest number with cable flies instead of pressing). Keeping body map as a *diagnostic* preserves training honesty.

---

## 9. Overall Rank

### Definition

The user's headline identity rank, earned by passing named trials. Requirements unlock the trial; the trial grants the rank.

### Derivation

```
candidate_tier = highest tier where trial requirements are met:
   - required count of movement standards at target tier
   - required count of skill standards at target tier
   - required attribute floor
   - required Overall LV

overall_rank = highest passed trial tier
```

There is no hidden aggregate score in V1. If a user wants to become Vessel, the app checks the Vessel trial requirements: for example, 4 movement standards at Vessel, 3 skill standards at Vessel, the attribute floor, and LV 60. Meeting those requirements unlocks **The Ten Hundred**. Passing that trial grants Vessel.

Concretely: a user can be *at most* the highest tier they have passed a trial for. If they've passed Forged Trial but not Veteran Trial, they're capped at Forged regardless of how their lifts/skills look. Trials are the gate.

### Display

The overall rank is the **headline** on the profile screen. Tier label, badge, color band. Everything else (skills, movements, attributes) supports it.

---

## 10. Paths

### The three paths

- **Lifter** — primarily trains weighted compound movements
- **Calisthenics** — primarily trains bodyweight skills and bodyweight movements
- **Hybrid** — mixed

### How a path is determined

Two signals:

1. **Inferred from training data.** What % of AP came from weighted vs. bodyweight in the last 30 days. The system computes this automatically.
2. **User selection** at trial-time. The user picks which variant of the trial they want to attempt. The system suggests based on inference but doesn't force.

### Where paths matter

- Trial variants (see §11)
- Skill catalog the user is held to (a lifter's "skills" can include strength-skills like weighted plank, farmer carry hold, etc.)
- Movement standards the user must hit
- Attribute distribution naturally differs by path (lifter is POW-heavy, calisthenics is CTL-heavy) and that's a feature

### Critical principle

**Both paths reach Ascendant.** Neither is forced to become the other. The trial system asks for excellence *within the chosen path*, not equality across both.

---

## 11. Trials

### Definition

A single brutal named workout that gates each tier transition on Overall Rank. 8 trials total, one per transition.

### Trial requirements (at TARGET tier)

The user must hit these *before* the trial unlocks:

| → Tier | Movement ranks at TARGET | Skill ranks at TARGET | Attribute floor | **Min Overall LV** | Workout |
|---|---|---|---|---|---|
| **Novice** | 1 | — | — | **3** | The Awakening |
| **Apprentice** | 2 | 1 | — | **8** | The Calibration |
| **Honed** | 2 | 1 | 1 of 6 | **15** | The Forge |
| **Forged** | 3 | 2 | 2 of 6 | **25** | The Reckoning |
| **Veteran** | 3 | 2 | 3 of 6 | **40** | The Gauntlet |
| **Vessel** | 4 | 3 | 3 of 6 | **60** | The Ten Hundred |
| **Unbound** | 4 | 3 | 4 of 6 | **85** | The Restriction |
| **Ascendant** | 5 | 3 | 4 of 6 | **110** | The Ascension |

**Path-aware**: "movements" and "skills" pull from the user's path catalog. A lifter's skills can include strength-skills.

**Attribute floor**: at higher tiers, "X of 6" means the *top X of 6 attributes* must be at the target tier. Allows specialization to skip END or MOB if that's their build, while still requiring breadth.

**Min Overall LV**: the time-in-game gate. Even if a user can hit specific lifts/skills fast (e.g., they came in already strong), they cannot trial up past the LV gate without putting in genuine total volume. This is the anti-min-max gate. LV thresholds are tunable; these are starting calibrations.

### The 8 trial workouts

Each is a **uniquely designed event workout**, not a checklist of PR attempts and not a Murph reskin. The point is ceremony: users should recognize the names, talk about them, and feel like a rank-up was earned through a memorable challenge.

Trials are allowed to feel hard, dramatic, and slightly mythic. They should not all become generic CrossFit/hybrid workouts by accident. Each trial needs:
- a clear identity/name
- path variants for Lifter, Calisthenics, and Hybrid
- equipment fallbacks
- tier-appropriate scaling
- objective pass/fail rules

The listed workouts are **first-pass shapes**. Volumes, caps, and pass standards must be calibrated before implementation, especially the early trials. Trial 1 and Trial 2 should feel ceremonial and challenging, not like secretly advanced conditioning tests.

---

#### Trial 1 · The Awakening (Initiate → Novice)
*Ritual establishment. Approachable but ceremonial.*

```
Format: For time
  1 mile easy run/walk
  100 BW squats
  50 push-ups (any quality)
  25 pull-ups (assisted ok at this tier)

Cap: 30 min
```

Variants:
- BW-only / no equipment: substitute pull-ups with inverted rows on a sturdy table
- Path: none — this trial is universal

---

#### Trial 2 · The Calibration (Novice → Apprentice)
*Density baseline. AMRAP feel.*

```
Format: AMRAP 20 minutes
  5 pull-ups
  10 push-ups
  15 squats

Pass: 14+ rounds
Cap: 20 min hard stop
```

Variants:
- Lifter: 5 strict pull-ups + 10 push-ups + 15 goblet squats @ 25 lb
- Calisthenics: standard
- Hybrid: standard
- No pull-up bar: 7 inverted rows + 10 push-ups + 15 squats per round

---

#### Trial 3 · The Forge (Apprentice → Honed)
*Multi-round chipper. Strength + conditioning integration.*

```
Format: 3 rounds for time
  400m run
  21 kettlebell swings (or DB swings)
  21 burpees
  15 thrusters (light barbell) or 15 push-press with DBs
  10 strict pull-ups

Cap: 35 min
```

Variants:
- Lifter: 35 lb KB / 65 lb bar thrusters / 25 lb DB push-press
- Calisthenics: substitute thrusters with 21 handstand push-ups (or pike push-ups)
- Hybrid: as written
- No KB / barbell: substitute with DB equivalent or BW alternatives

---

#### Trial 4 · The Reckoning (Honed → Forged)
*Heavy + conditioning sandwich. Strength expression under fatigue — can you still hit your numbers when you're already spent?*

```
Format: For time
  Heavy block A — 5 singles at 85% on your main lift (bench/squat/deadlift)
  Conditioning chunk — 2km row OR 1.5 mi run + 50 burpees-over-bar
  Heavy block B — 5 singles at 85% on the same lift (matched intent)

Cap: 45 min
Pass: complete all 10 singles + the conditioning chunk
```

Variants:
- Lifter: as written, your choice of compound lift
- Calisthenics: replace barbell singles with weighted pull-up singles at 85% of max + the conditioning + 5 strict muscle-up attempts (3 must succeed)
- Hybrid: weighted singles using dumbbells (max weight DB row, DB clean, etc.)
- No barbell: heavy weighted vest pull-ups or weighted dips substitute

---

#### Trial 5 · The Gauntlet (Forged → Veteran)
*Hyrox-style multi-modal hybrid. Running through punishment, station by station — test of total athleticism.*

```
Format: 8 stations, completed for time
  1. 1000m row OR 1km run
  2. 50m sled push at BW (or 30 wall-balls @ 20 lb if no sled)
  3. 30 wall balls (20 lb to 10 ft target)
  4. 50m sled pull at BW (or 30 ring rows if no sled)
  5. 40 walking lunges holding 25 lb plate overhead
  6. 50m farmer carry @ BW × 2 (heavy)
  7. 20 sandbag-over-shoulder @ 40 lb (or sub: hang-clean + press)
  8. 30 burpee box jump-overs (20" box)

Cap: 50 min
```

Variants:
- Lifter: as written
- Calisthenics: substitute sled work with hill sprints / stair runs; substitute sandbag with weighted dips; everything else BW-friendly
- Hybrid: as written
- Home gym / no sleds: rower or run replaces both sled stations with extended distance

---

#### Trial 6 · The Ten Hundred (Veteran → Vessel)
*Pure volume hell. 1000 reps. Mental + physical endurance.*

```
Format: 1000 reps total, 100 each across 10 movements, completed for time
  Quality reps only — half reps don't count

Default 10 movements (Hybrid path):
  - Pull-ups
  - Push-ups
  - BW squats
  - Sit-ups
  - Dips
  - Lunges (each leg = 1 rep)
  - Mountain climbers (each leg = 1)
  - Russian twists (each side = 1)
  - Burpees
  - Kettlebell swings (35 lb)

Cap: 75 min
```

Variants:
- Lifter: replace 5 BW movements with light weighted equivalents (DB squats, KB swings, light deadlifts, barbell rows, DB shoulder press) at moderate weight
- Calisthenics: pure BW (handstand push-ups, ring dips, ring rows, etc. — substitute upward in difficulty for advanced users)
- Hybrid: as written

---

#### Trial 7 · The Restriction (Vessel → Unbound)
*Limit-breaking. Push past your trained ceiling. The "break the restriction" moment.*

```
Format: 4 phases, completed in sequence, single session

Phase A — Strength Ladder (20 min)
  Escalating heavy singles on your main lift
  Must reach 95% of your observed e1RM or verified recent best (or set a new PR)

Phase B — Conditioning Block (20 min)
  5K row OR 3 mi run
  OR: 50 burpees-over-bar + 50 box jumps (24")

Phase C — Volume Finisher (25 min)
  50 reps each of 4 movements at moderate intensity:
    - 50 strict pull-ups
    - 50 weighted dips (BW + 25 lb)
    - 50 weighted lunges (25 lb each side)
    - 50 KB swings (53 lb)

Phase D — Skill Proof (10 min window)
  Demonstrate one advanced skill at Vessel+ tier
  (e.g., 60s L-sit, 30s freestanding handstand, 5 strict muscle-ups)

Cap: 90 min total
```

Variants:
- Lifter: Phase A and C heavier; Phase D's skill can be a strength-skill (60s farmer carry hold at 2× BW, 60s weighted dead hang at +50 lb)
- Calisthenics: Phase A replaced with weighted pull-up max attempts + max muscle-up reps; Phase D requires an advanced calisthenics skill (planche progression, OAPU, etc.)
- Hybrid: as written

---

#### Trial 8 · The Ascension (Unbound → Ascendant)
*The final form. 5-phase 90-minute athletic warfare. All attributes tested.*

```
Format: 5 sequential phases in a single session

Phase 1 — Strength (20 min)
  Heavy compound sequence: 3 heavy singles on each of bench / squat / deadlift
  (or path-equivalent: 3 weighted pull-up singles + 3 weighted dip singles + 3 weighted pistol singles)

Phase 2 — Power / Explosiveness (15 min)
  Max effort on 3 explosive movements:
    - 5 max-distance broad jumps (target: BW)
    - 5 box jumps at max-attainable height (target: BW)
    - 5 sprint intervals @ 40m

Phase 3 — Endurance (20 min)
  5K row OR 5K run OR 1500m swim

Phase 4 — Skill (15 min window)
  Demonstrate 3 Ascendant-tier skill standards (path-appropriate)
  (e.g., 90s freestanding handstand, 5 OAPU each side, 30s planche; OR farmer carry 2× BW × 60s + weighted dead hang +90 lb × 30s + weighted L-sit + 45 lb × 30s for strength-path)

Phase 5 — Final Integration (20 min)
  Hybrid finisher: 5 rounds of:
    - 400m run
    - 10 thrusters at 95 lb (or 10 muscle-ups, or 10 weighted dips)
    - 10 strict pull-ups (or weighted)
    - 10 burpees

Cap: 120 min
Pass: complete all 5 phases within sub-targets per phase
```

Variants:
- Lifter: heavier phases 1, 5; phase 4 uses strength-skills
- Calisthenics: phase 1 BW-based singles; phase 4 demands advanced acrobatic skills
- Hybrid: as written, balanced load

---

### Trial UX flow

1. **Requirements visible** — trial readiness card shows progress on every requirement.
2. **Locked until requirements met** — user trains toward them, the card updates in real time.
3. **Attempt opens** when requirements satisfied. User chooses variant (suggested per path + equipment).
4. **Trial session** — guided in-app with stopwatch, prescribed work, log as you go.
5. **Pass** → cinematic, new overall rank tier, badge unlock, title shift.
6. **Fail** → no rank-up, but the work counts as a normal session (AP, attribute XP, etc.). Cooldown to retry: 1 day for lower tiers, 7 days for Forged-Veteran, 30 days for Unbound and Ascendant.

### Mythology

Each passed trial is logged forever:

```
🔥 The Awakening · 2026.05.12 · 24:18
🔥 The Calibration · 2026.06.01 · 18 rounds
🔥 The Forge · 2026.07.20 · 32:11
🔒 The Anvil — in progress
```

That list becomes the user's hero log. Trial completions generate share cards.

---

## 12. Weekly Vows

### Definition

Weekly Vows are optional weekly commitments. They exist to give users a cool, self-selected push without pretending every week should contain a PR test or rank-gate event.

They are **not** Overall Rank Trials. Trials are rare tier gates. Vows are weekly spice: a small promise, a finisher, or a dedicated event that fits the user's current program and recovery.

### The three lanes

| Lane | Slot in the week | Feel | Duration | Intensity | Best for |
|---|---|---|---|---|---|
| **Ember** | Rest day / low day | Controlled, restorative, still intentional | 8-12 min | RPE 3-5 | Mobility, trunk, easy skill exposure, zone-2 flush |
| **Overdrive** | After a normal workout | Short, sharp, earned | 6-12 min | RPE 7-8 | Density sets, carries, EMOMs, pump finishers, skill volume |
| **Apex** | Dedicated weekend slot | Event-like, memorable, shareable | 20-45 min | RPE 8-9 | Hard mixed circuits, benchmark events, path-specific challenges |

### Scaling

Vows are scaled by deterministic app data first:
- Overall LV and Overall Rank
- movement ranks and skill ranks
- recent 7-day and 28-day training volume
- path: lifter, calisthenics, hybrid, or user override
- available equipment
- recovery state and rest-day placement
- injury/limitation tags
- what anatomical regions and attributes have already been hit this week

AI can help author or refresh Vow templates later, but the runtime system should not require AI for basic safe scaling. The movement library metadata should carry enough information for substitutions and dose control.

### Rewards

The Vow's prescribed work earns normal rewards through the unified completion pipeline:
- movement / skill AP
- attribute XP from the exercise vector
- Overall LV XP
- body-map saturation
- PRs, rank-ups, and badges when they happen naturally

Vow completion can add:
- bonus Overall LV XP
- Vow badge progress
- cosmetic progress
- Apex share card

Vows should not give flat attribute XP just for completion. If an Overdrive finisher uses kettlebell swings, it earns POW / EXP / END because kettlebell swings carry that vector. The completion bonus belongs to Overall LV and collectibles, not fake attribute growth.

### Example reward beats

```
OVERDRIVE CLEARED — Final Round
Work earned: +84 AP
Vow bonus: +120 LV XP
Badge progress: Overdrive I · 2/3
```

```
APEX CLEARED — Redline
Work earned: +310 AP
Vow bonus: +500 LV XP
Badge unlocked: Redline
Share card ready
```

### Product language

Use:
- Weekly Vow
- Ember
- Overdrive
- Apex
- Vow cleared

Avoid:
- weekly trial
- weekly rank trial
- feat as a system noun
- mark
- challenge spam

The user should feel like they opted into something with identity and payoff, not like the app added homework.

---

## 13. Atrophy, Staleness, and the Comeback Path

Real fitness degrades when you stop training. The system's job is to represent this honestly *without* punishing users for life events (injury, vacation, parenthood, burnout). The policy:

### No-decay rule

**Nothing in earned progression ever decays.** Movements, skills, AP, attribute XP, and Overall LV are all permanent. Earned is earned. The Vessel rank you earned two years ago does not become Forged because you took six months off.

This is non-negotiable. Decay-based progression systems are app-uninstall energy at scale — percentage decay on AP/LV would mean a user opens the app after a layoff to see half their work erased. Catastrophic trust break, no recovery.

### How staleness is communicated honestly (without penalty)

Three non-punitive signals make current capability legible without taking anything away:

**1. Body map saturation (already designed in §8)**

Body map decays naturally with ~10-14 day half-life. Cold anatomical regions visually communicate "haven't trained this recently." No rank or stat is affected — it's just the recovery/freshness layer doing its job.

**2. Recent best vs. lifetime best (per movement)**

Each movement tracks two numbers:

- **Lifetime best** — heaviest/longest/most you've ever hit (the proof that earned the rank)
- **Recent best** — heaviest/longest/most you've hit in the last 90 days (rolling window)

```
BENCH PRESS · Honed
  Lifetime PR: 225 lb (Honed standard ✓)
  Recent best: 185 lb           ← honest stale signal
```

The rank stays Honed (lifetime PR earned it). The recent best shows current capability. **No demotion, full transparency.** Re-hitting 225 snaps recent best back to 225.

**3. Stale flag per movement/skill**

After 30+ days without a logged set on a tracked movement, a small `🌫️ stale` marker appears next to it. Doesn't change rank or AP. Clears the moment a qualifying set is logged. Same logic per skill.

### The comeback path — trial re-runs grant the boost

Trials are re-runnable indefinitely (§11). When a user returns from a layoff — default threshold: **4+ weeks of fewer than 2 sessions/week** — re-running any previously-passed trial activates **comeback velocity**:

```
trial_rerun_after_layoff → 1.5× LV bolus multiplier for next 30 days
```

This is **calibration via behavior**, not via self-reported stats. The user doesn't tell the system "I'm still a Vessel" — they prove it by re-running the workout. Pass the workout, get the boost. Fail the workout, learn where they actually stand. Either outcome is honest.

Stacking rule: comeback velocity does **not** stack additively with compound velocity (§6). The system uses `max(comeback_velocity, compound_velocity)`. So a returning vet who's also stacking rank-ups doesn't double-dip — they get the highest applicable multiplier.

### UX of the comeback flow

A returning user opens the app after 8 weeks off:

```
WELCOME BACK
─────────────────────────────────────
You've been away 8 weeks. Your earned ranks are
still yours — no decay, no demotion.

Some movements show as stale:
  🌫️ Bench Press · last trained 67d ago
  🌫️ Squat · last trained 67d ago
  🌫️ Pull-Up · last trained 67d ago

⚡ Comeback boost available:
   Re-run any previously-passed trial to activate
   1.5× LV velocity for 30 days.

   Recommended: The Forge (your most-recent passed trial)

   [Run The Forge]    [Just train normally]
```

The user has agency: run a trial for the boost, or just train. Either is valid. The "just train normally" path is fine — comeback boost is optional, just an extra reward for users who want to mark their return with a ceremony.

### What this avoids

| Decay model | Problem |
|---|---|
| Percentage decay on AP/LV | Catastrophic trust break — user sees half their work erased |
| Hard rank demotion | Punitive, kills retention exactly when retention is most fragile |
| No staleness signaling at all | Dishonest — hex/ranks claim things the body can't currently do |
| **Recent-vs-lifetime + stale flags + comeback boost** ✓ | Honest, non-punitive, makes returning rewarding |

The chosen model preserves the dignity of earned progression while showing current capability honestly, and turns the comeback into a **reward** (boost) rather than a **recovery** (climbing back to what was lost).

### Implementation notes

- Track `lifetime_best` and `recent_best` per movement in the existing movement progression record (`ProgressionState` already has the right shape).
- Stale flag is a derived view on `last_logged_at` field per movement/skill (>30 days = stale).
- Comeback boost detection: count sessions in last 28 days; if < 8 sessions over that window AND last_logged_at > 28 days, comeback boost is available on next trial re-run.
- Welcome-back card fires on first app open after detected layoff; non-modal, dismissible.

---

## 14. Adaptive Coaching

### Closed-loop training adjustment

The body map signals feed the program generator, which makes session-level suggestions to the user.

### Signal hierarchy (by reliability)

| Signal | Reliability | Drives |
|---|---|---|
| **Recent volume** (auto-computed) | High | Daily swaps, weekly accessory rebalancing |
| **Push/pull balance** | High | Block-level program tuning |
| **Chronic neglect** (lifetime gap) | Medium | Surfaced as suggestion at block rollover |
| **User-reported soreness** | Low-medium | Hint-level only |
| **Scan focus areas** | Medium-high | Existing block-bias system |

### Posture: Suggested with one-tap accept

The system **suggests**, the user **decides**. No silent program changes, no nagging.

```
Coach suggestion (one per session max):

  Your chest is still cooked from Monday — swap today's
  bench for incline DB? (chest volume +220% vs weekly avg)

  [Accept swap]  [Keep bench]
```

### Respect for user intent

- **Explicit declarations** (Focus: lifter, no leg work, etc.) silence suggestions on that axis
- **Pattern detection** — if user skips suggested leg day 3× in a row, prompt once: "Want us to drop legs from your program?" Drop on yes, never ask again.
- **Archetype baselines** — *removed; the system no longer uses archetype as a behavior driver*
- **Observed behavior > stated** — what the user trains tells the truth, weighted higher than what they said in onboarding

### Failure modes refused

- Suggestion fatigue (cap at 1 swap/week visible)
- Recovery-driven progression breaks (never skip the same compound week after week)
- Forced balance the user doesn't care about (mute, don't escalate)
- Reactive ping-pong (signal must hold for N sessions before driving a swap)

### Math enforces the rest

If a user never trains legs, their AGI/EXP/POW lower-body contribution stays low, their leg-related body map region stays cold, their leg-feeding movement ranks plateau — they'll cap out lower in overall rank than someone balanced. **The math makes the tradeoff visible without any scolding.** They figure it out themselves when they hit the ceiling.

---

## 15. UI Surfaces

### Profile / character sheet (the headline)

```
┌──────────────────────────────────────────┐
│  OVERALL RANK: VESSEL · LV 47             ← headline tier + total level
│  ▓▓▓▓▓░░░  62% to LV 48                   ← LV progress bar
├──────────────────────────────────────────┤
│  HEX (6 axes)                             ← build identity
│    POW 23 · Vessel                        ← LV integer + tier label per axis
│    AGI 19 · Veteran
│    END 15 · Forged
│    CTL 24 · Vessel
│    MOB 10 · Honed
│    EXP 18 · Veteran
│  Build name: "Power Hybrid"               ← derived identity label
├──────────────────────────────────────────┤
│  Streak · Sessions · Best                 ← living state
├──────────────────────────────────────────┤
│  → Skills        → Movements              ← deep progression tabs
│  → Body Map      → Trial Readiness        ← diagnostic + roadmap
└──────────────────────────────────────────┘
```

### Reward screen (after every workout)

```
WORKOUT COMPLETE — 45:22

BENCH PRESS                  toward HONED (225 lb)
  Set 1: 185×5    +42 AP
  Set 2: 195×5    +51 AP
  Set 3: 205×3    +58 AP
  Set 4: 225×1    +84 AP + 200 PR  ★ HONED ACHIEVED
  Total: +435 AP into Bench Press

Attribute XP gained:
  POW   +180 XP   (×1.2 fresh stimulus 🔥)
  CTL   + 95 XP
  END   + 30 XP

Overall LV:  +340 XP   (LV 47, 62% → 73% to LV 48)

Highlights:
  PR: Bench Press 225 lb × 1
  Badge: First Plate Club

Body map updated:
  Chest, Shoulders, Arms — saturated
  Back, Legs — fresh (×1.4 bonus available next session)
```

Reward-screen summary tokens should stay simple:

```
XP       = session XP / legacy reward XP if still shown
RANK UPS = movement, skill, or attribute tier crossings
PRS      = personal records
BADGES   = persistent named accomplishments
```

Do **not** use "Marks" as the label. It is too vague. Do **not** make "Feats" a major tab or data model. If a moment persists, it should be a Badge; if it is session-local, it should be a PR or highlight.

### Trial readiness card (the motivation engine)

```
FORGED TRIAL — locked
─────────────────────────────────────────
MOVEMENT RANKS  (3 at Forged)
  ✅ Squat        Forged   (275 / 1.75× BW)
  ✅ Deadlift     Forged   (365 / 2.25× BW)
  ⬜ Bench        Honed    195 / 225 needed     ← close

SKILL RANKS  (2 at Forged)
  ✅ Weighted Plank   Forged  (3:00 @ 45 lb)
  ⬜ Farmer Carry     Honed   60s / 90s needed

ATTRIBUTE FLOOR  (2 of 6 at Forged)
  ✅ POW Forged
  ✅ AGI Forged
  ⬜ CTL Honed                                  ← close

MIN OVERALL LV  (25)
  ✅ Your LV: 27

CHALLENGE: THE RECKONING
  Variant: Lifter (78% lifts last 30 days)
  Heavy block A → 2km row + 50 burpees → Heavy block B
  Cap: 45 min

STATUS: 2 requirements remaining
EASIEST UNLOCK: Bench to Honed (10 lb away)
```

### Body map (the coaching surface)

Heat-colored anatomical silhouette. No numbers. Tap a region:
- "When did I last hit X?"
- "What feeds this region?"
- "Recent volume vs. weekly average"

---

## 16. Math Model (cheat sheet)

```
# Raw AP per set
raw_AP = base × (weight/e1rm)^1.5 × ln(1+reps)
awarded_AP = max(1, round(raw_AP)) if raw_AP > 0 else 0
PR_bonus = flat +large AP if weight or rep PR set
movement_AP[movement] += awarded_AP + PR_bonus

# Attribute XP gain (per set)
attr_xp[a] += round/reconcile(awarded_AP × attribute_weight[a] × novelty_bonus)

# Overall LV XP gain (per set) — single global counter
overall_lv_xp += round(awarded_AP × novelty_bonus)
# (PR bonuses also stack into LV XP)
# Weekly Vow completion bonuses can add Overall LV XP, but never artificial attribute XP.

# Overall LV requirement
if L <= 100: xp_required_for_lv[L] = lv_base × L^1.5
if L > 100:  xp_required_for_lv[L] = xp_at_100 + (L - 100) × 3,750

# LV rank-up bolus (fires on every movement/skill rank-up)
rank_up_lv_bolus = base_for_tier[new_tier] × skill_difficulty_factor[skill] × velocity_multiplier
# tier_factor table: Novice 50, Apprentice 150, Honed 400, Forged 900,
#                    Veteran 1800, Vessel 3500, Unbound 6500, Ascendant 12000
# skill_difficulty_factor: Pull-Up 1.0, L-Sit 0.8, Pistol 1.0, Handstand 1.3,
#                          Muscle-Up 1.5, OAPU 1.8, Front Lever 2.0, Planche 2.5
# movements always use difficulty_factor = 1.0

# Compound velocity multiplier (rolling 30-day window)
if rank_ups_last_30_days >= 5: compound_velocity = 1.5
elif rank_ups_last_30_days >= 3: compound_velocity = 1.25
else: compound_velocity = 1.0

# Comeback velocity (active for 30d after qualifying trial re-run)
if user_was_inactive AND trial_rerun_completed:
    comeback_velocity = 1.5  # active for 30 days
else:
    comeback_velocity = 1.0

# Final multiplier — do NOT stack, take the max
velocity_multiplier = max(compound_velocity, comeback_velocity)

# Staleness signals (display only, never affect rank/AP/LV)
recent_best[movement] = max(weight × reps) over last 90 days
is_stale[movement] = (now - last_logged_at[movement]) > 30 days
comeback_boost_available = sessions_last_28_days < 8 AND last_logged_at > 28 days

# Novelty bonus (from body map)
novelty_bonus = avg over hit_regions of (1 + (1 - saturation[r]) × 0.5)
# saturated region → 1.0×; fresh region → ~1.5×

# Attribute level requirement
if L <= 100: xp_required_for_attribute_lv[L] = attr_base × L^1.5
if L > 100:  xp_required_for_attribute_lv[L] = xp_at_100 + (L - 100) × 1,500

# Attribute level (per-axis integer shown on the hex)
attribute_level[a] = inverse of xp_required_for_attribute_lv
# Mirrors Overall LV curve. Grows forever, but per-level cost caps after LV 100.

# Body map saturation
saturation[r] = Σ(volume × time_decay) over rolling window
time_decay = exp(-days_ago / 10)

# Overall rank
candidate_tier = highest tier where movement_count + skill_count + attribute_floor + LV gates are satisfied
overall_rank = highest_trial_passed_tier
# candidate_tier unlocks trial attempts; passed trials grant rank
```

---

## 17. Design Principles & Failure Modes

### Principles to keep

1. **One causality arrow.** Attributes derive from raw AP (which derives from real work). Body map derives from volume. Overall rank derives from skills/movements/attributes/LV unlocking trials, then trials granting rank. **No parallel grindable XP pools.**
2. **Standards gate ranks, AP shows narrative.** You can never grind to a movement rank without hitting its explicit standard.
3. **Body map shows truth, never nags.** The math enforces tradeoffs quietly; the system doesn't moralize about user choices.
4. **Both paths reach Ascendant.** The system measures excellence within the path, not equality across paths.
5. **Specialization survives the attribute floor.** Top-N-of-6 lets specialists ascend without becoming hybrids.
6. **Trial workouts are distinct.** Each tier transition is its own moment with its own format. No two trials feel the same.
7. **Earned is permanent.** Ranks, AP, attribute XP, and Overall LV never decay. Staleness is signaled via display layers (recent-vs-lifetime, stale flag, body map cold) but never strips earned progression.
8. **The comeback path rewards.** Returning users get a boost via trial re-run, not a recovery climb. The system pulls returning users back in, never pushes them away.
9. **Weekly Vows are optional spice, not rank gates.** They create weekly anticipation without stealing the word Trial or forcing PR testing.

### Failure modes to refuse

1. ❌ Independent attribute XP grindable separately from lifts/skills → isolation farming, decoupling from real progress
2. ❌ Body-part ranks visible to user → invites cable-fly cheese, reduces fitness to aesthetic
3. ❌ Bounded 0–100 attributes → maxable, then dead
4. ❌ Five rank ladders visible at once → paralysis, no headline
5. ❌ Overall rank with no trial gate → just a number, no stakes
6. ❌ Lift standards in absolute weight only → unfair across body weights; use BW-relative as baseline
7. ❌ Skill rank criteria with judgment calls → always pin to numbers
8. ❌ Trial workouts that all feel like Murph → no variety
9. ❌ Multi-day trials → kills story moment, increases failure friction
10. ❌ Hex chart that fills to max → no long-term progression
11. ❌ Nagging users about legs / mobility / endurance → suggest once, respect intent, let math enforce the tradeoff
12. ❌ Archetypes as drivers — **removed**; system doesn't use archetype to weight behavior anymore
13. ❌ Percentage decay on AP / LV / attribute XP → catastrophic trust break, app-uninstall energy. Permanence is non-negotiable.
14. ❌ Rank demotion after inactivity → punitive, kills retention at the most fragile moment. Use staleness signals + comeback boost instead.
15. ❌ Asking returning users to "re-declare" their stats via survey → use trial re-run as behavior-based calibration, never a form
16. ❌ Weekly "trials" that compete with Overall Rank Trials → vocabulary collision, lowers the stakes of real trials
17. ❌ Flat attribute rewards for optional events → fake stat growth; attributes must come from actual movement vectors

---

## 18. Outstanding implementation notes

- Execution roadmap lives at `docs/superpowers/handoff/2026-05-21-unified-workout-progression-migration-roadmap.md`.
- 2026-05-22 Overall Rank trial lane: service definitions cover Foundation Proof, The Calibration, and V1 The Forge. The runner still routes attempts through `TrainingSessionDraft` -> `PerformanceLog` -> `TrainingCompletionService`, then records pass/fail rank-gate attempts idempotently by performance log id. Focused service tests cover The Forge readiness, locked, failed, passed, and duplicate-log paths; simulator UI proof remains pending.

- Functional migration order:
  1. **Unified completion receipt** — every completion route emits AP, attribute XP, Overall LV XP, skill XP when relevant, rank-ups, PRs, and badge unlocks through one receipt shape.
  2. **Movement rank standards** — finish calibrated 9-tier standards for every ranked movement and ensure variants roll up only where declared.
  3. **Skill proof standards** — every skill node exposes the next unlock requirement clearly, with numeric proof requirements and prerequisite links.
  4. **Reward callouts + badges** — standardize PRs, badge unlocks, first standards, trial completions, comeback events, and consistency milestones without creating a separate Feats system.
  5. **Weekly Vows migration** — rename current weekly trial/challenge surfaces into Ember / Overdrive / Apex, route completions through the same receipt, and reserve Trial for Overall Rank only.
  6. **Trial readiness** — derive the readiness card from movement ranks, skill ranks, attribute floors, and Overall LV gates.
  7. **Trial runner** — implement named trial sessions and pass/fail logging; overall rank only advances from passed trials.
  8. **Body map diagnostics** — wire anatomical saturation to novelty bonuses and coaching suggestions without creating body-part ranks.
  9. **Program adjustment hooks** — let skill goals, travel weeks, deloads, equipment limits, and trial prep adjust workouts through library metadata before using AI.

- Skill-rank standards table is calibrated but tunable — first 6 months of telemetry should refine
- Movement-rank standards are tunable per movement
- Attribute weight vectors per exercise are the design DNA; maintain a versioned `exercise_weights.json`
- Body map decay half-life starts at 10–14 days; tune empirically
- Grip is a metadata/performance tag, not a body-map region
- Trial workouts have BW / Home / Full-Gym variants; all calibrated to equivalent difficulty
- Path detection runs on rolling 30-day AP distribution; user can override

---

**End of canonical reference.** Anything contradicting this doc is an inconsistency to fix in code, not in this doc.
