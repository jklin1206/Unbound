# Star-Standard Progression Redesign

**Date:** 2026-05-29 · **Status:** DESIGN (council-synthesized, no code yet) · **Owner refines standards**

Replaces the per-node 9-hand-authored-tier ladder with an **Overcooked-style star rating** per skill + **one overall athlete rank**. Resolves the double-encoding bug (prereq chain vs on-ramp tiers) and the "pistol-rank-from-split-squats" dishonesty. Keeps the grand ~150-node tree fully intact.

---

## The model

- **Every node ranks on its OWN movement only** (its own reps / hold-seconds / bodyweight-load). Never a different exercise; never a restatement of its prerequisite.
- **Each node earns 0–3 stars vs a standard:**
  - ★ = "you can genuinely do this" (first clean rep / entry hold)
  - ★★ = "solid / owned / programmable"
  - ★★★ = "elite for this skill"
- **The prereq chain is the climb.** A locked hard skill shows **0 stars + a "road in"** (prereq progress + closest unlock), never a fake rank.
- **Total stars (difficulty-weighted) → ONE overall athlete rank** with the 9 named tiers (Initiate→Unbound). The named ranks live HERE, not per-node.
- **Authoring drops from ~1,350 hand-written criteria to ~3 numbers per node** (the star thresholds). The cross-exercise bug becomes unrepresentable (a node's stars read only its own movement).

---

## Standards (coach proposal — owner to refine)

Metric in parens. ★ / ★★ / ★★★.

### Pull
| Skill | ★ | ★★ | ★★★ |
|---|---|---|---|
| Pull-up (reps) | 1 | 8 | 15 |
| Chin-up (reps) | 1 | 10 | 18 |
| Wide pull-up (reps) | 1 | 6 | 12 |
| Weighted pull-up (+bw%) | +10% | +33% | +50% |
| Archer pull-up (reps/side) | 1 | 3 | 6 |
| One-arm pull-up (reps) | 1 | 2 | 5 |
| Muscle-up (reps) | 1 | 3 | 7 |
| Ring muscle-up (reps) | 1 | 3 | 6 |
| Strict muscle-up (reps) | 1 | 2 | 5 |
| Dead hang (sec) | 30 | 60 | 120 |

### Push
| Skill | ★ | ★★ | ★★★ |
|---|---|---|---|
| Push-up (reps) | 1 | 25 | 50 |
| Diamond push-up (reps) | 1 | 15 | 30 |
| Archer push-up (reps/side) | 1 | 5 | 10 |
| One-arm push-up (reps) | 1 | 3 | 8 |
| Dip (reps) | 1 | 12 | 25 |
| Pike push-up (reps) | 1 | 8 | 15 |
| Wall HSPU (reps) | 1 | 5 | 12 |
| Freestanding HSPU (reps) | 1 | 3 | 8 |
| 90° push-up (reps) | 1 | 2 | 5 |
| Bent-arm press (reps) | 1 | 2 | 5 |

### Legs
| Skill | ★ | ★★ | ★★★ |
|---|---|---|---|
| Bodyweight squat (reps) | 20 | 50 | 100 |
| Pistol squat (reps/side) | 1 | 5 | 12 |
| Shrimp squat (reps/side) | 1 | 4 | 10 |
| Nordic curl (reps) | 1 | 3 | 8 |
| Weighted pistol (+bw%) | +10% | +25% | +50% |

### Statics (clean hold seconds)
| Skill | ★ | ★★ | ★★★ |
|---|---|---|---|
| Plank | 30 | 90 | 180 |
| L-sit | 5 | 15 | 30 |
| Tuck front lever | 5 | 15 | 30 |
| Straddle front lever | 3 | 10 | 20 |
| Full front lever | 2 | 8 | 15 |
| Tuck back lever | 5 | 15 | 30 |
| Straddle back lever | 3 | 10 | 20 |
| Full back lever | 2 | 10 | 20 |
| Tuck planche | 3 | 10 | 20 |
| Straddle planche | 2 | 8 | 15 |
| Full planche | 1 | 5 | 10 |
| Wall handstand | 30 | 60 | 120 |
| Freestanding handstand | 5 | 30 | 60 |
| One-arm handstand | 1 | 5 | 15 |
| German hang | 10 | 30 | 60 |

### Threshold-setting rules (per metric)
- **Holds:** ~doubling per star (static strength scales logarithmically). ★ = first *controlled* hold (no swing/press-out), ★★ = the programmable benchmark, ★★★ = judge/camera-grade.
- **Reps:** ★ = 1 clean full-ROM rep; ★★ = a real working set (8–12 basics, 3–5 hard skills); ★★★ ≈ 2× the working set (you've outgrown it → add load).
- **Weighted (+bw%):** ★ +10%, ★★ +25–33%, ★★★ +50%. Use bw% not kg so it self-scales.
- **High-rep basics (squat):** higher floor (★=20) — 1 air squat proves nothing.
- **Mythic** (one-arm planche/handstand): compressed seconds (★ = clean instant, ★★ = 1–2s, ★★★ = 3–5s) + highest weight.
- **Binary skills:** always extend into seconds for ★★/★★★ so the node keeps giving progress; never leave a node at a single static star.

---

## Mechanics (systems proposal)

### Difficulty weighting (overall rank ≠ raw star count)
A ★ on planche must outweigh ★★★ on push-ups. Star value scales by node difficulty tier:

| Tier | Examples | ×weight |
|---|---|---|
| Foundational | push-up, squat, plank, dead hang | 1× |
| Intermediate | pull-up, dip, L-sit, tuck lever, wall HSPU | 2× |
| Advanced | muscle-up, full FL/BL, straddle planche, pistol, free HS | 4× |
| Elite | full planche, one-arm pull-up, 90° push-up | 7× |
| Mythic | one-arm planche, one-arm handstand | 12× |

Overall rank = Σ(stars × tier weight). **Show RAW stars in the UI** (what you collect); use weighted points only in the rank engine (user feels "harder skill moved me more" without math).

### Star → overall-rank curve
Back-loaded (early ranks fast, top brutal). ~450 raw-star max, practical ceiling ~330–360. Map weighted points to 9 tiers with growing gaps; **Unbound requires ≥1 Elite-tier ★★** → unreachable on volume alone, <1% of users.

### Family-balance gate (THE critical mechanic)
~6 families (Push, Pull, Core, Legs, Hinge/Handstand, Mobility). **Overall rank ≤ min(family_tier) + 1.** Framed as a next-goal ("Legs is holding your rank back — 8 stars to unlock Elite"), not a tax. A calisthenics athlete is defined by their weakest link; this encodes it.

### Anti-grind (keep light)
- **Star locks after 2 qualifying sets across 2 separate sessions** (one fluke shows "★ pending — log once more"). This is the *entire* anti-grind surface.
- **Strict/kipping = per-set quality flag**; kips don't count toward strict standards.
- No video/velocity verification (too heavy).

### Progress within a star + decay
- Continuous fill bar between stars (interpolate the metric). "1 rep from ★★★."
- **Claimed overall rank NEVER demotes** (the promise, from Phase 7). Stars are best-ever, never decay. Add a soft, recoverable **form modifier** (Sharp / Maintained / Rusty) by training recency for honesty — re-log to return to Sharp. "Unbound · Rusty."

---

## UX (felt experience)

- **Star-earn = post-workout receipt:** cards ding in sequence (~250ms stagger), star snaps with a scale-punch + tick; *filling toward* a star pulses + soft chime but stays unrewarded (makes the star feel earned). **Overall rank-up is separate + rare** — full-screen coronation, bass hit, once every few weeks. Stars = confetti; rank-up = coronation.
- **Locked hard-skill card:** 3 hollow stars (honest), ghosted hero silhouette, "road in" = vertical prereq chain with your furthest-along node flagged "CLOSEST UNLOCK." A path, not a wall.
- **Skill card (in progress):** ONE dominant number — the next star threshold ("★★ at 8s · you're at 5s") — + recent-set sparkline with the threshold marked. Never 3 competing numbers.
- **Constellation view:** a night sky by region; filled stars glow gold + lit lines, in-progress dim-white pulse, locked barely-there (lines draw themselves on unlock). Gold density per region = instant strength read.
- **The ONE beacon (highest-leverage detail):** exactly one "your next reachable star" highlight, surfaced identically on constellation + home + onboarding. Converts a 150-node sky from overwhelming to "do this next."
- **Onboarding:** 3-move calibration lights ~6 stars in 60s → camera pulls back to the dark sky → beacon points at the first chaseable star. First session *earns* a star.
- **Sharing:** dark portrait card — huge tier name + YOUR constellation fingerprint + "312 / 450 stars." Un-fakeable (every athlete's sky differs).
- **Fanfare triage:** most stars = quiet tick; ~15% are events (first-ever star, 3★ elite, a star that unlocks a node). If everything dings, nothing does.

---

## What this replaces / migration (to scope)
- Per-node `tierCriteria` 9-tier tables → **3 star thresholds per node** (+ metric + difficulty tier). The reseat work already shipped (pull/push/legs/statics on-ramps) gets **superseded** — its cross-exercise on-ramps are exactly what the council says to remove. The hold-seconds work (F2 + `exerciseSeconds`) is **kept** (statics standards use it).
- Per-skill `RankTier` (initiate..ascendant) → **stars (0–3)** per node; the 9 named tiers move to the **overall** aggregate rank (which already exists from Phase 7 — re-point it to weighted-star sum + family gate).
- New UI surfaces: star receipt, road-in card, constellation beacon. Existing skill-card/reward-beat re-pointed to stars.
- Node difficulty tiers (1×–12×) + family tags need authoring (~150 nodes, but mechanical).

**Open owner decisions:** (1) sign off / tune the standards table; (2) confirm the 5 difficulty-weight tiers + which skills sit where; (3) family list + the gate formula; (4) build sequencing (engine first vs UI first).
