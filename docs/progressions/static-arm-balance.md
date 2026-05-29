# Static Arm-Balance — Graduated 9-Tier Progression Proposal

**Family:** Planche (`pl.*`), Handstand (`hs.*`), One-Arm Handstand (`oah.*`)
**Status:** RESEARCH + PROPOSAL. No Swift edited. Tables are the spec for a future tier-criteria rebuild.

## Tier vocabulary (READ FIRST — display vs case name)

`RankTier` (`UNBOUND/Models/SkillTier.swift`) raw order is `initiate(0) → ascendant(8)`,
but the **top two display names are swapped**: case `.unbound` (rv 7) shows **"Ascendant"**,
case `.ascendant` (rv 8) shows **"Unbound"** = the brand PEAK. Tables below use **display
names**. The 9 tiers, weakest → peak:

`Initiate · Novice · Apprentice · Forged · Veteran · Master · Vessel · Ascendant · Unbound(peak)`

Design contract (matches the prompt + how the tree already ranks):
- **Initiate–Apprentice** = the assisted / easier variant you can actually do (band, lean, frog, tuck, wall, close-hand straddle).
- **Forged** = first legit rep / hold of the *named* skill.
- **Veteran–Unbound** = longer holds, harder leg-extension variants, or rep volume on the dynamic.

"Metric" column: holds in **seconds**, dynamics in **reps**. "Exists?" flags whether the
variant is already a tree node (`id`) or proxied in the current tier table, vs **NEW**.

---

## 1. Planche (`pl.full-planche`, keystone, tier 7, target = 5s full hold)

### Current tree (`pl.*` nodes + edges)

| id | title | tier | target | prereq | tierCriteria style |
|----|-------|------|--------|--------|--------------------|
| `pl.pseudo-planche-pushup` | Pseudo-Planche Push-Up | 4? | 5 reps | diamond pushup | reps |
| `pl.tuck-planche` | Tuck Planche | 5 | 5s hold | `hs.crane-pose` | low tiers proxy **pseudo-planche-pushup reps**, not easier holds |
| `pl.tuck-planche-pushup` | Tuck Planche Push-Up | 5 | 3 reps | pseudo-planche-pushup | reps |
| `pl.bent-arm-planche` | Bent Arm Planche | 4 | 3s | `hs.elbow-lever` | hold |
| `pl.straddle-planche` | Straddle Planche | 6 | 5s | `pl.tuck-planche` | hold + tuck-pushup compound |
| `pl.half-lay-planche` | Half-Lay Planche | 6 | 3s | `pl.straddle-planche` | hold |
| `pl.full-planche` | Full Planche | 7 | 5s | `pl.half-lay-planche` | hold + full-pushup compound |
| `pl.full-planche-pushup` | Full Planche Push-Up | – | 1 rep | straddle/full | reps |
| `pl.ninety-degree-pushup` | 90° Push-Up | – | 1 rep | full planche | reps |
| `pl.one-arm-planche` | One-Arm Planche (mythic) | – | 1s | full chain | hold |

**Already in tree:** tuck, straddle, half-lay, full, bent-arm + the three pushup variants + one-arm.
**MISSING (canonical) :** planche **lean**, **frog stand**, **advanced tuck planche** (the standard tuck→straddle bridge), **band-assisted full planche**. The current `pl.tuck-planche` low tiers lean on pseudo-planche-pushup *reps* as a stand-in for an easier hold — a graduated ladder should use the real easier holds instead.

### Documented canonical chain (Steven Low / Overcoming Gravity, GMB, Calisthenics Assoc.)
planche lean → frog stand → tuck planche (5–10s × 3) → **advanced tuck** (12–15s × 3 before progressing) → straddle planche (close the straddle over months) → half-lay → full planche. Rule of thumb across sources: **own ~10s clean before progressing the lever**; advanced-tuck specifically gated at 12–15s.

### Proposed 9-tier ladder — `pl.full-planche` (the keystone "Planche" rank)

| Tier (display) | Variant / exercise | Metric | Exists? |
|----------------|--------------------|--------|---------|
| Initiate | Planche lean (feet down, shoulders past wrists) | 20s hold | **NEW** |
| Novice | Frog stand / band-assisted tuck | 15s hold | **NEW** (frog = `hs.frog-pose` exists; band NEW) |
| Apprentice | Tuck planche | 5s hold | node `pl.tuck-planche` |
| **Forged** | **Advanced tuck planche** (knees ~hip line) | **10s hold** | **NEW** (bridge node) |
| Veteran | Straddle planche (wide) | 5s hold | node `pl.straddle-planche` |
| Master | Straddle planche (narrowing) | 10s hold | node `pl.straddle-planche` |
| Vessel | Half-lay planche | 5s hold | node `pl.half-lay-planche` |
| Ascendant | Full planche | 5s hold | node `pl.full-planche` |
| Unbound (peak) | Full planche | 10s hold OR +1 full-planche pushup | node `pl.full-planche` (+`pl.full-planche-pushup`) |

> Note: current `pl.full-planche` table maxes its dynamic compounds at Unbound = full-planche × multiple + 90°-pushup. That's *higher* than "10s full hold" — fine to keep as the harder of the two Unbound options. The ladder above is the graduated **hold-first** path; the existing pushup compounds remain a valid alt-criterion.

---

## 2. Handstand (`hs.freestanding-hs-30`, keystone, tier 3, target = 30s freestanding)

### Current tree (`hs.*` inversion/balance nodes)

| id | title | tier | target | prereq |
|----|-------|------|--------|--------|
| `hs.wall-plank` | Wall Plank | 1 | 30s | — |
| `hs.headstand` | Headstand | 2 | 30s | `hs.wall-plank` |
| `hs.wall-handstand-30` | Wall Handstand | 2 | 30s | `hs.wall-plank` |
| `hs.wall-handstand-60` | Wall Handstand (60s) | – | 60s | `hs.wall-handstand-30` |
| `hs.tuck-handstand` | Tuck Handstand | 3 | 5s | `hs.wall-handstand-30` |
| `hs.freestanding-hs-10` | Freestanding HS opener | – | 10s | — |
| `hs.freestanding-hs-30` | Handstand (keystone) | 3 | 30s | `hs.wall-handstand-30` |
| `hs.freestanding-hs-60` | Full Handstand | – | 60s | `hs.freestanding-hs-30` |
| `hs.tuck-press` / `hs.straddle-press` / `hs.press-to-handstand` | press ladder | 5/6/7 | reps | — |
| `hs.handstand-walk-10m` | Handstand Walk | – | steps | — |

**Already in tree:** wall-plank, headstand, wall-handstand 30 & 60, tuck-handstand, freestanding 10/30/60, full press ladder, walk. This family is the **best-covered** of the three.
**MISSING (canonical):** explicit **chest-to-wall hold** as a distinct line-building step, **kick-up-to-balance** attempts, and **fingertip-pressure / heel-pull balance drills** — the documented "difference between plateau and breakthrough" (fit.gg, Weiger). These are drills, not necessarily new nodes; can live as tier rungs.

### Documented canonical chain (fit.gg, GMB, Kyle Weiger, Calisthenics Assoc.)
wall plank → chest-to-wall hold (line) → wall handstand 30→60s → **fingertip-pressure balance drill** → kick-up-to-balance → tuck handstand (first free balance) → freestanding 5–10s → 30s → 60s. Timeline: wall 1–3 mo; free 5–10s in 3–6 mo; 30s in 6–12 mo. Wall-as-crutch warning: train wall (strength/line) and freestanding (balance) as *separate* skills.

### Proposed 9-tier ladder — `hs.freestanding-hs-30` (the "Handstand" rank)

| Tier (display) | Variant / exercise | Metric | Exists? |
|----------------|--------------------|--------|---------|
| Initiate | Wall plank (shoulders over wrists) | 30s hold | node `hs.wall-plank` |
| Novice | Chest-to-wall handstand (line) | 30s hold | partly — `hs.wall-handstand-30` (chest-to-wall NEW as named step) |
| Apprentice | Wall handstand | 60s hold | node `hs.wall-handstand-60` |
| **Forged** | **Freestanding handstand (kick-up + balance)** | **10s hold** | node `hs.freestanding-hs-10` |
| Veteran | Tuck handstand → freestanding | 5s tuck / 15s free | nodes `hs.tuck-handstand` + free |
| Master | Freestanding handstand | 30s hold | node `hs.freestanding-hs-30` |
| Vessel | Freestanding handstand | 45s hold | between 30/60 (proxy `hs.freestanding-hs-60`) |
| Ascendant | Freestanding handstand | 60s hold | node `hs.freestanding-hs-60` |
| Unbound (peak) | Freestanding handstand | 60s + press-to-handstand entry (1 rep) | `hs.freestanding-hs-60` + `hs.press-to-handstand` |

> Forged = first legit *freestanding* hold (10s), matching the contract. Lower tiers stay on the wall (the easier variant you can do). Top tiers add the press-to-handstand *entry* — the canonical "you own the shape, not just the kick-up" proof. Tree already compounds higher freestanding tiers with press reps, which this preserves.

---

## 3. One-Arm Handstand (`oah.one-arm-handstand-5s`, mythic, tier 6, target = 5s)

### Current tree (`oah.*` + the one bridge `hs.*` node)

| id | title | tier | target | prereq |
|----|-------|------|--------|--------|
| `hs.wall-supported-oah` | Wall Supported One-Arm HS | 5 | 5s | `hs.freestanding-hs-30` |
| `oah.one-arm-handstand-5s` | One-Arm Handstand (mythic) | 6 | 5s | `hs.wall-supported-oah` |
| `oah.full-one-arm-handstand` | Full One-Arm HS (mythic) | 7 | 5s+ | `oah.one-arm-handstand-5s` |

**Already in tree:** wall-supported OAH, free OAH 5s, full OAH. That's **3 nodes for the hardest skill in the tree** — the THINNEST family. Current tiers gate almost entirely on freestanding-HS + HSPU reps; the *balance lead-ups* (the actual OAH learning curve) are absent.
**MISSING (canonical):** the entire documented entry chain — **close-hand straddle handstand**, **weight-shift / lean holds**, **three/two/one-finger tenting**, **fingertip-lift (hand floats off floor)**, and **side-flexion (hip drop over working hand)**. These are exactly the drills GMB/Berg/MP Calisthenics teach, and they're the bulk of the years-long progression.

### Documented canonical chain (GMB, Berg Movement, MP Calisthenics, Coach Bachmann)
Prereq: solid freestanding handstand (sources say 30–60s+). Then:
straddle HS close hands → **weight shift** (shoulder stays over hand) → side-flexion (drop hip to weighted side) → **tenting**: 3-finger → 2-finger → 1-finger on the off-hand → off-hand **fingertip-lift / float** → arm extension → full OAH. Hold-drill rule: **build each stage to 20–30s "time under balance" before advancing.** Wall used for endurance/shape at higher stages; practice one level below the wall freestanding.

### Proposed 9-tier ladder — `oah.one-arm-handstand-5s` (the "One-Arm Handstand" rank)

| Tier (display) | Variant / exercise | Metric | Exists? |
|----------------|--------------------|--------|---------|
| Initiate | Freestanding handstand (prereq base) | 30s hold | node `hs.freestanding-hs-30` |
| Novice | Close-hand straddle handstand + weight shift | 20s hold / shift reps | **NEW** |
| Apprentice | Wall-supported one-arm handstand | 5s hold | node `hs.wall-supported-oah` |
| Forged | 2-finger tent (off-hand) | 10s hold | **NEW** |
| Veteran | 1-finger tent (off-hand) | 10s hold | **NEW** |
| Master | Fingertip-lift / off-hand float | 3–5s float | **NEW** |
| **(named-skill anchor)** | *first legit free one-arm touch* | — | overlaps Master→Vessel |
| Vessel | Free one-arm handstand | 5s hold | node `oah.one-arm-handstand-5s` |
| Ascendant | Free one-arm handstand | 8s hold | proxy of `oah.one-arm-handstand-5s` |
| Unbound (peak) | Full one-arm handstand | 10s+ hold | node `oah.full-one-arm-handstand` |

> OAH breaks the "Forged = first named rep" contract on purpose: a free 1-arm hold is mythic, so the *named skill* lands at **Vessel**, and Initiate–Master are all assisted lead-ups (wall, tenting, float). This is the family that most needs new nodes — at minimum 4 (close-hand straddle/weight-shift, 2-finger tent, 1-finger tent, fingertip-float). Current criteria's HSPU-rep gating is a *strength* proxy; the proposal adds the missing *balance* progression that defines OAH.

---

## Gap summary & build-out priority

| Skill | Coverage today | New nodes needed | Priority |
|-------|---------------|------------------|----------|
| **One-Arm Handstand** | 3 nodes, all near-terminal; zero balance lead-ups | ~4 (close-hand straddle+shift, 2-finger tent, 1-finger tent, fingertip-float) | **HIGHEST** |
| **Planche** | strong terminal chain; missing the easy on-ramps | ~3 (planche lean, advanced tuck, band-assisted) | Medium |
| **Handstand** | best covered; full wall→free→press chain exists | 0 new nodes; add fingertip/chest-to-wall as tier *rungs* only | Low |

**Cross-cutting notes**
- All three keystone ladders should be **hold-second graduated** at low/mid tiers and only compound with dynamic/press/pushup reps at Vessel+ — which is already the tree's pattern; the proposal mainly fills the *easy end*.
- `pl.tuck-planche` low tiers currently substitute pseudo-planche-pushup *reps* for an easier hold; advanced-tuck (NEW) gives a true hold rung at Forged.
- Display-name swap (`.ascendant` = "Unbound" peak) must be respected if these tables are implemented — map by **case name**, render by **displayName**.

## Sources
- Steven Low — Overcoming Gravity (advanced isometric programming): https://stevenlow.org/how-to-program-for-advanced-isometric-movements-after-a-plateau/ ; TOC/preview: https://stevenlow.org/wp-content/uploads/2018/09/OG2-preview-TOC-Intro-Ch1-3.pdf
- GMB Fitness — Planche (tuck→straddle): https://gmb.io/planche/
- Calisthenics Association — Advanced Tuck Planche (12–15s gate): https://calisthenicsassociation.org/lessons/advanced-tuck-planche
- GainStrong / XcelerateGyms — tuck planche hold standards (5–10s × 3, 10s before progressing): https://getgainstrong.com/blog/planche-progression-for-beginners ; https://xcelerategyms.com/tuck-planche-hold/
- fit.gg — handstand zero→freestanding progression + fingertip-pressure drill: https://www.fit.gg/blog/how-to-do-a-handstand-progression
- Kyle Weiger — wall to freestanding handstand: https://kyleweiger.com/wall-to-freestanding-handstand/
- GMB Fitness — One-arm handstand (straddle→weight-shift→tenting→float): https://gmb.io/oahs/
- Berg Movement — OAH beginner drills (finger leans, time-under-balance): https://www.bergmovement.com/calisthenics-blog/one-arm-handstand-drills-and-progressions-beginner
- Maximum Potential Calisthenics — OAH tutorial: https://www.mpcalisthenics.com/tutorial/one-arm-handstand-tutorial
