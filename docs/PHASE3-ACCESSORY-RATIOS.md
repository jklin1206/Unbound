# Phase 3 — Accessory Family-Default Ratio Table

**Status:** CHECKPOINT — owner eyeballs the ratios before they're wired. No Swift modified.
**Scope:** the LOADED accessories in `ExerciseCatalog.swift` that do NOT inherit a compound parent (bench/squat/deadlift/OHP/row). Compounds are settled in `PHASE3-STANDARDS-PROPOSAL.md`.
**All ratios are bodyweight multiples (load ÷ bodyweight). MALE column is canonical; female handled per-family (§4).**
**Sources:** strengthlevel.com `/strength-standards/<movement>/kg`, fetched 2026-05-29. Cited per family. Families with no page are scaled from the nearest analog and **FLAGGED**.

---

## 0. Tier ladder + band anchoring (recap)

`RankTier` ordinals: `initiate(0) novice(1) apprentice(2) forged(3) veteran(4) master(5) vessel(6) ordinal7(display "Ascendant") ordinal8(display "Unbound", peak)`.

> Brand note: ordinal **8 = "Unbound" (the peak)**, ordinal **7 = "Ascendant"**. The compound proposal's prose still says "unbound(7) ascendant(8)" — that's the pre-swap labelling. This doc works in ordinals and shows the *current* display name in parentheses. The numeric thresholds are unaffected by the swap.

Band → ordinal anchoring (identical to compounds):

| StrengthLevel band | ordinal | display |
|---|---|---|
| (below Beginner) | 0 | initiate |
| **Beginner** | **1** | novice |
| — interp midpoint — | 2 | apprentice |
| **Novice** | **3** | forged |
| — interp midpoint — | 4 | veteran |
| **Intermediate** | **5** | master |
| — interp midpoint — | 6 | vessel |
| **Advanced** | **7** | Ascendant |
| **Elite** | **8** | Unbound (peak) |

Interp rule: ordinal2 = mean(Beg,Nov), ordinal4 = mean(Nov,Int), ordinal6 = mean(Int,Adv). ordinal0 = anything below the Beginner ratio (floor). Values rounded to 2 dp.

---

## 1. Accessory families (movements with NO compound parent)

The 5 compounds + their barbell/DB/machine/smith variants inherit via `rankStandardMovementId` (covered in the compound proposal). Everything below is what's LEFT — true accessories. Bodyweight-only / hold / reps movements (pushups, planks, levers, calf-raise-for-reps, etc.) are NOT load-ranked and stay on their existing bodyweight-skill path — listed in §6.

| # | Family | Anchor movement (StrengthLevel page) | Catalog members (loaded) |
|---|---|---|---|
| F1 | **Biceps curl** | barbell curl | barbell curl, ez bar curl, dumbbell curl, incline dumbbell curl, concentration curl, spider curl, cable curl, rope cable curl, hammer curl, rope hammer curl, preacher curl, machine biceps curl, band curl |
| F2 | **Triceps extension** | tricep pushdown | tricep pushdown, rope/straight-bar tricep pushdown, overhead tricep extension (cable + rope), machine triceps extension, band tricep extension, skull crushers, close grip bench press |
| F3 | **Lateral / delt raise** | dumbbell lateral raise | lateral raise (db / cable), machine lateral raise, dumbbell front raise, cable front raise, cable y raise, upright row, rear delt fly (db / machine), face pull |
| F4 | **Leg extension (quad iso)** | leg extension | leg extension, single-leg extension |
| F5 | **Leg curl (hamstring iso)** | seated leg curl | leg curl (lying / seated), single-leg curl |
| F6 | **Calf raise (loaded)** | seated calf raise | standing / seated / leg-press / smith / donkey calf raise, tibialis raise |
| F7 | **Machine vertical pull** | lat pulldown | lat pulldown (bar / neutral / wide / close / reverse grip), single-arm pulldown, straight-arm pulldown, machine pullover, band lat pull, assisted pullup machine |
| F8 | **Hip thrust / glute** | hip thrust | hip thrust, smith machine hip thrust, glute bridge, cable/machine glute kickback, cable pull through, hip abductor/adductor machine, cable hip abduction, kettlebell swing |
| F9 | **Loaded ab / trunk** | cable crunch | cable crunch, machine crunch, pallof press, landmine rotation (decline/roman-chair situp = bodyweight, see §6) |

**Coverage check:** every loaded accessory in the catalog maps to one of F1–F9. Leftover non-loaded movements → §6.

---

## 2. StrengthLevel source ratios (cited, male / female)

Raw 5-band ratios as fetched. These feed the 9-tier expansion in §3.

| Family | Page | M Beg/Nov/Int/Adv/Elite | F Beg/Nov/Int/Adv/Elite | Per-hand? |
|---|---|---|---|---|
| F1 curl | `/barbell-curl/kg` | 0.20 / 0.40 / 0.60 / 0.85 / 1.15 | 0.10 / 0.20 / 0.40 / 0.60 / 0.85 | total (barbell) |
| F1 curl (DB ref) | `/dumbbell-curl/kg` | 0.10 / 0.15 / 0.30 / 0.50 / 0.65 | 0.05 / 0.10 / 0.20 / 0.35 / 0.45 | **PER-HAND** |
| F2 triceps | `/tricep-pushdown/kg` | 0.25 / 0.50 / 0.75 / 1.00 / 1.50 | 0.15 / 0.25 / 0.50 / 0.75 / 1.05 | total (stack) |
| F3 lateral raise | `/dumbbell-lateral-raise/kg` | 0.05 / 0.10 / 0.20 / 0.30 / 0.45 | 0.05 / 0.10 / 0.15 / 0.20 / 0.30 | **PER-HAND** |
| F4 leg ext | `/leg-extension/kg` | 0.50 / 0.75 / 1.25 / 1.75 / 2.50 | 0.25 / 0.50 / 1.00 / 1.25 / 2.00 | total (stack) |
| F5 leg curl | `/seated-leg-curl/kg` | 0.50 / 0.75 / 1.00 / 1.50 / 2.00 | 0.25 / 0.45 / 0.75 / 1.05 / 1.45 | total (stack) |
| F6 calf | `/seated-calf-raise/kg` | 0.25 / 0.75 / 1.25 / 2.00 / 3.00 | 0.25 / 0.50 / 1.00 / 1.75 / 2.50 | added load (excl. bw) |
| F7 lat pulldown | `/lat-pulldown/kg` | 0.50 / 0.75 / 1.00 / 1.50 / 1.75 | 0.30 / 0.45 / 0.70 / 0.95 / 1.30 | total (stack) |
| F8 hip thrust | `/hip-thrust/kg` | 0.50 / 1.00 / 1.75 / 2.50 / 3.50 | 0.50 / 1.00 / 1.50 / 2.25 / 3.00 | **total incl. 20 kg bar** |
| F9 cable crunch | `/cable-crunch/kg` | 0.25 / 0.50 / 1.00 / 1.50 / 2.25 | 0.25 / 0.50 / 1.00 / 1.50 / 2.25 | total (stack) |

Notes baked in:
- **F1**: F1 anchor is the **barbell** curl (total load), because most catalog curls log a single barbell/EZ/cable total. The DB-curl row is shown only to derive the per-hand mapping (§3.1).
- **F6**: StrengthLevel's *seated calf raise* is added load (plate/stack), not bodyweight — matches how the app logs machine/standing calf raise added weight. The bodyweight-only `/standing-calf-raise` page is **reps-based** (no ratio) → not used.
- **F9**: cable crunch male=female on StrengthLevel (identical bands). We keep them equal.

---

## 3. The 9-tier ratio tables (MALE)

Generated by the §0 anchoring rule. **Bold** = StrengthLevel-cited anchor; *italic* = interpolated midpoint. ordinal0 = below the ordinal1 value.

### F1 — Biceps curl (total barbell/cable load)  · source `/barbell-curl/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.20 |
| 1 | novice | **0.20** |
| 2 | apprentice | *0.30* |
| 3 | forged | **0.40** |
| 4 | veteran | *0.50* |
| 5 | master | **0.60** |
| 6 | vessel | *0.73* |
| 7 | Ascendant | **0.85** |
| 8 | Unbound | **1.15** |

### F2 — Triceps extension (total stack)  · source `/tricep-pushdown/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.25 |
| 1 | novice | **0.25** |
| 2 | apprentice | *0.38* |
| 3 | forged | **0.50** |
| 4 | veteran | *0.63* |
| 5 | master | **0.75** |
| 6 | vessel | *0.88* |
| 7 | Ascendant | **1.00** |
| 8 | Unbound | **1.50** |

### F3 — Lateral / delt raise (PER-HAND)  · source `/dumbbell-lateral-raise/kg`  · **DUBIOUS, see §6**
| ord | display | ratio (per hand) |
|---|---|---|
| 0 | initiate | <0.05 |
| 1 | novice | **0.05** |
| 2 | apprentice | *0.08* |
| 3 | forged | **0.10** |
| 4 | veteran | *0.15* |
| 5 | master | **0.20** |
| 6 | vessel | *0.25* |
| 7 | Ascendant | **0.30** |
| 8 | Unbound | **0.45** |

### F4 — Leg extension (total stack)  · source `/leg-extension/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.50 |
| 1 | novice | **0.50** |
| 2 | apprentice | *0.63* |
| 3 | forged | **0.75** |
| 4 | veteran | *1.00* |
| 5 | master | **1.25** |
| 6 | vessel | *1.50* |
| 7 | Ascendant | **1.75** |
| 8 | Unbound | **2.50** |

### F5 — Leg curl (total stack)  · source `/seated-leg-curl/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.50 |
| 1 | novice | **0.50** |
| 2 | apprentice | *0.63* |
| 3 | forged | **0.75** |
| 4 | veteran | *0.88* |
| 5 | master | **1.00** |
| 6 | vessel | *1.25* |
| 7 | Ascendant | **1.50** |
| 8 | Unbound | **2.00** |

### F6 — Calf raise (added load, excl. bodyweight)  · source `/seated-calf-raise/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.25 |
| 1 | novice | **0.25** |
| 2 | apprentice | *0.50* |
| 3 | forged | **0.75** |
| 4 | veteran | *1.00* |
| 5 | master | **1.25** |
| 6 | vessel | *1.63* |
| 7 | Ascendant | **2.00** |
| 8 | Unbound | **3.00** |

### F7 — Machine vertical pull (total stack)  · source `/lat-pulldown/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.50 |
| 1 | novice | **0.50** |
| 2 | apprentice | *0.63* |
| 3 | forged | **0.75** |
| 4 | veteran | *0.88* |
| 5 | master | **1.00** |
| 6 | vessel | *1.25* |
| 7 | Ascendant | **1.50** |
| 8 | Unbound | **1.75** |

### F8 — Hip thrust / glute (total load incl. 20 kg bar)  · source `/hip-thrust/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.50 |
| 1 | novice | **0.50** |
| 2 | apprentice | *0.75* |
| 3 | forged | **1.00** |
| 4 | veteran | *1.38* |
| 5 | master | **1.75** |
| 6 | vessel | *2.13* |
| 7 | Ascendant | **2.50** |
| 8 | Unbound | **3.50** |

### F9 — Loaded ab / trunk (total stack)  · source `/cable-crunch/kg`
| ord | display | ratio |
|---|---|---|
| 0 | initiate | <0.25 |
| 1 | novice | **0.25** |
| 2 | apprentice | *0.38* |
| 3 | forged | **0.50** |
| 4 | veteran | *0.75* |
| 5 | master | **1.00** |
| 6 | vessel | *1.25* |
| 7 | Ascendant | **1.50** |
| 8 | Unbound | **2.25** |

### 3.1 Dumbbell per-hand vs total — the load-mapping rule

The app logs **the number entered on the weight field**. For a dumbbell movement the convention is the user types the weight of ONE dumbbell (e.g. "20" for a pair of 20s). So:

- **F3 lateral raise** is authored **per-hand** (matches StrengthLevel's per-dumbbell convention AND the app's per-DB log). Compare logged kg directly to the F3 ratio. No conversion.
- **F1 curl** anchor is **total** (barbell). When a *dumbbell* curl is logged per-hand, multiply the logged kg by **2** before comparing to the F1 total-load table (two-arm work ≈ barbell total). State this in the resolver: `effectiveLoad = isDumbbellPair ? logged*2 : logged`.
  - This is the single ambiguity that needs a code-side flag. Everything else (machines, cables, barbells) is total load = logged load, 1:1.
- Single-arm DB/cable movements (concentration curl, single-arm cable row→compound, single-leg ext/curl) log per-limb; compare per-limb load to **half** the family table, or simpler: keep single-limb variants pointing at the bilateral anchor and accept they rank ~1 tier low. **Recommend: don't special-case single-limb; flag as known under-rank.**

---

## 4. Female handling (per-family sex ratio)

StrengthLevel publishes female bands per family, so we DO have real female anchors — prefer them over a flat ×0.55. Per-family female/male ratio at the Intermediate anchor (the most representative):

| Family | F/M @ Int | Use |
|---|---|---|
| F1 curl | 0.40/0.60 = **0.67** | author female column from `/barbell-curl` female bands |
| F2 triceps | 0.50/0.75 = **0.67** | female bands cited |
| F3 lateral | 0.15/0.20 = **0.75** | female bands cited |
| F4 leg ext | 1.00/1.25 = **0.80** | female bands cited |
| F5 leg curl | 0.75/1.00 = **0.75** | female bands cited |
| F6 calf | 1.00/1.25 = **0.80** | female bands cited |
| F7 pulldown | 0.70/1.00 = **0.70** | female bands cited |
| F8 hip thrust | 1.50/1.75 = **0.86** | female bands cited (glutes — smallest gap) |
| F9 ab | 1.00/1.00 = **1.00** | equal — use male column |

**Recommendation:** since every family has a cited female page, author the female 9-tier column directly from the §2 female bands (same anchoring rule) rather than scaling. The **×0.55 cross-lift default stays only as the fallback** for any future family with no female page. Note the accessory female/male gap (0.67–1.00) is *narrower* than the compound gap (~0.55) — isolation/glute work is more sex-balanced, so a flat 0.55 would badly under-rank women on accessories. This is the main reason to use the per-family female bands.

---

## 5. Difficulty multiplier — RECOMMENDATION: DROP IT

The compound proposal floated a per-movement difficulty multiplier (Beg ×0.85 / Int ×1.0 / Adv ×1.15 / Elite ×1.30). **Recommend dropping it for accessories.** Justification:

1. **Double-counting.** The family anchor already IS a difficulty level. Leg extension (easy, supported) sits at 0.50–2.50; lateral raise (hard to load) sits at 0.05–0.45. The *family choice already encodes difficulty*. Multiplying again re-penalizes movements that StrengthLevel already scored harder.
2. **Within a family, variants are near-equivalent for ranking.** Rope vs straight-bar pushdown, cable vs DB lateral raise, lying vs seated leg curl — the load you can move differs by single-digit %, well inside the tier-band width. A 4-step ×0.85–×1.30 multiplier (a 53% swing) dwarfs the real variation and would produce wrong tiers.
3. **Simplicity.** One ratio table per family, logged-load in, tier out. No per-movement difficulty lookup, no second source of truth to maintain. Matches the "one metric" goal of Phase 3.

**Where real intra-family difficulty matters** (e.g. incline vs flat DB curl), prefer a **pointer** (`rankStandardMovementId`) to the right anchor over a multiplier. The only families with a meaningful internal spread are F1 (barbell-total vs DB-per-hand — handled by the ×2 rule in §3.1) and F6 (seated vs standing calf — within band width, ignore).

---

## 6. Families/movements to keep `.unranked` or flag

| Item | Verdict | Reason |
|---|---|---|
| **F3 lateral / delt raise** | **Recommend `.unranked`** (or rank but de-emphasize) | Ego-lifting & form variance is enormous: a clean 12 kg strict raise > a heaved 25 kg. Per-hand bands are tiny (0.05–0.45) so a 5 kg log error swings 2+ tiers. Tracks momentum, not delt strength. If owner wants it ranked, keep the table but never gate cinematic moments on it. Front raise / upright row / face pull share this. |
| **F6 calf raise** | Rank, but **FLAG** | ROM/bounce variance is high; also added-load vs total ambiguity (machines vary). Tiers are directionally fine, not precise. |
| **F8 cable/machine glute kickback, hip abductor/adductor** | **Recommend `.unranked`** | No StrengthLevel page; would inherit F8 hip-thrust which is 3–5× heavier load — kickbacks/abduction log tiny stack weights and would peg at initiate forever. Pointing them at hip thrust is wrong. Either author a separate tiny-iso table or leave unranked. |
| **F9 pallof press, landmine rotation** | **Recommend `.unranked`** | Anti-rotation / positional — load isn't the goal, control is. Cable crunch + machine crunch CAN rank on F9. |
| **kettlebell swing (F8)** | **Recommend `.unranked`** | Ballistic; peak force ≠ logged kettlebell mass. Ranking by KB weight is meaningless. |
| Pushups, dips(bw), planks, levers, pistols, muscle-ups, hanging raises, bodyweight calf raise, decline/roman-chair situp | Stay on **bodyweight-skill path** (not load-ranked) | Already handled by progression-family / reps / hold logic, out of scope here. |

**Estimated/no-direct-source families:** none of F1–F9 anchors are estimates — every anchor has a cited StrengthLevel page. The only *estimate* territory is the sub-movements routed to F8 that don't belong (kickbacks, abduction) — flagged above for unranked rather than a fabricated table.

---

## 7. SANITY ROWS — the part to scan

All male unless noted, using §3 tables. Tier = highest ordinal whose ratio ≤ the logged ratio (no interpolation needed for the gut-check; the resolver interpolates between bands but the band-edge read is what matters here).

| # | Case | Ratio | Tier (ordinal · display) | Gut check |
|---|---|---|---|---|
| 1 | 20 kg DB curl/hand @ 80 kg bw (→ ×2 = 40 kg total, 0.50×) | 0.50 total | **4 veteran** | A pair of 20s strict-curled at 80 kg bw = solid intermediate-ish. Feels right. |
| 2 | 40 kg barbell curl @ 80 kg (0.50×) | 0.50 | **4 veteran** | Same as #1, confirms the ×2 DB rule lines DB and barbell up. Good. |
| 3 | 15 kg lateral raise/hand @ 80 kg (0.19×) | 0.19 per hand | **4 veteran** (just under master 0.20) | 15 kg strict laterals IS strong. But see §6 — form-dependent; reasonable but dubious. |
| 4 | 25 kg lateral raise/hand @ 80 kg (0.31×) | 0.31 per hand | **7 Ascendant** | 25 kg laterals at 80 kg = almost certainly cheated. Exactly why F3 should be unranked. |
| 5 | 60 kg leg extension @ 80 kg (0.75×) | 0.75 | **3 forged** | Light-ish leg ext = early lifter. Feels right (Int is 100 kg here). |
| 6 | 140 kg leg extension @ 80 kg (1.75×) | 1.75 | **7 Ascendant** | Near-maxed stack = advanced. Correct. |
| 7 | 80 kg leg curl @ 80 kg (1.00×) | 1.00 | **5 master** | Bodyweight leg curl = intermediate. Spot on. |
| 8 | BW+40 kg hip thrust, total = 60 kg @ 80 kg (0.75×) | 0.75 | **2 apprentice** | NOTE: hip thrust ratio is TOTAL incl. bar. 40 kg+20 kg bar = 60 kg = 0.75×, below Novice(1.0). A 40 kg hip thrust IS beginner. Correct — but owner must confirm app logs total bar load. |
| 9 | 140 kg hip thrust total @ 80 kg (1.75×) | 1.75 | **5 master** | A 140 kg hip thrust = the median committed lifter. Feels right. |
| 10 | 50 kg tricep pushdown @ 80 kg (0.63×) | 0.63 | **4 veteran** | 50 kg pushdown = upper-intermediate. Reasonable. |
| 11 | 70 kg lat pulldown @ 80 kg (0.88×) | 0.88 | **4 veteran** | Just under bodyweight pulldown = approaching intermediate. Right. |
| 12 | 60 kg seated calf raise added @ 80 kg (0.75×) | 0.75 | **3 forged** | Calf added-load is high-rep/strong; 60 kg = novice-ish. Plausible. |
| 13 | 1.0× bw curl FEMALE @ 60 kg (60 kg barbell curl) | 1.00 (>Elite 0.85) | **8 Unbound** | A woman curling bodyweight on a barbell = genuinely elite. Sex column doing real work. |

**Headline gut-checks for the owner:**
- Hip thrust **#8/#9**: thresholds feel correct ONLY if the app logs total bar load. If it logs *added plates only*, every hip thrust under-ranks by ~20 kg/bw. **Confirm logging convention (O-A1 below).**
- Lateral raise **#3/#4**: the table is "correct" per StrengthLevel but the movement is the weakest rank signal in the app — recommend unranked.
- Curl DB↔barbell **#1/#2** line up cleanly with the ×2 rule — that rule is the one piece of resolver logic this whole doc requires.

---

## 8. Open questions for the owner

- **O-A1 (load convention):** Does the app's logged weight for hip thrust / barbell curl / calf raise represent TOTAL load (incl. bar) or ADDED plates only? F8 and F6 thresholds assume total. If added-only, shift F8/F6 down by the implement mass.
- **O-A2 (DB ×2 rule):** OK to implement `effectiveLoad = isDumbbellPair ? logged×2 : logged` for F1 curls (and leave F3 lateral per-hand)? This is the only new resolver branch.
- **O-A3 (unranked set):** Confirm F3 lateral/front/upright + F8 kickbacks/abduction + F9 pallof/landmine + KB swing stay `.unranked` (recommended). Or rank them anyway with the caveat?
- **O-A4 (female source):** Author per-family female columns from the cited female bands (recommended — gap is 0.67–1.00, not 0.55)? Or force the flat ×0.55? The flat default badly under-ranks women on isolation/glute work.
- **O-A5 (difficulty multiplier):** Confirm dropping the ×0.85–×1.30 per-movement multiplier for accessories (recommended — family anchor already encodes difficulty).
