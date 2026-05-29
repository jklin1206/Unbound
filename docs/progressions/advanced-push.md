# Advanced Push — Graduated 9-Tier Progression Proposal

**Family:** ADVANCED PUSH — the hard `cal.*` pushing nodes plus the two handstand-press nodes.
**Status:** Research + proposal. **No Swift was modified.**
**Goal:** Make each hard skill *rankable across its real progression* — low tiers reward the assisted / elevated / partial-ROM / negative variant a trainee can actually do today; Forged ≈ the first clean rep of the named skill; top tiers = volume / harder variant / deficit.

The 9 RankTiers (canonical, from `SkillTier.swift`):

| # | RankTier (case) | Display |
|---|---|---|
| 0 | initiate | Initiate |
| 1 | novice | Novice |
| 2 | apprentice | Apprentice |
| 3 | forged | Forged |
| 4 | veteran | Veteran |
| 5 | master | Master |
| 6 | vessel | Vessel |
| 7 | unbound | **Ascendant** (display flip) |
| 8 | ascendant | **Unbound** (peak) |

> Note the display flip baked into the enum: case `.unbound` renders "Ascendant", case `.ascendant` renders "Unbound" (peak). The columns below use the **case name** so they map 1:1 to the Swift dictionaries.

---

## 1. The nodes in scope (from `Models/SkillTreeContent.swift`)

| Node ID | Title | node `tier` | `target` | prereq | tierCriteria source | New? |
|---|---|---|---|---|---|---|
| `cal.pike-pushup` | Pike Push-Up | 4 | reps pike pushup ×10 | cal.diamond-pushup | CalSkillTiers (graduated) | existing |
| `cal.elevated-pike-pushup` | Elevated Pike Push-Up | 5 | reps ×10 | cal.pike-pushup | CalSkillTiers (graduated) | existing |
| `cal.floating-pike-pushup` | Floating Pike Push-Up | 5 | reps ×3 | cal.elevated-pike-pushup | CalSkillTiers (flat reps) | existing |
| `cal.handstand-pushup` (HSPU) | Handstand Push-Up | 6 (keystone) | reps HSPU ×1 | cal.elevated-pike-pushup | CalSkillTiers (graduated) | existing |
| `cal.bent-arm-press` | Bent Arm Press | 6 | reps ×3 | cal.floating-pike-pushup | CalSkillTiers (flat reps) | existing |
| `cal.ninety-degree-pushup` | Ninety-Degree Push-Up | 6 | reps ×1 | cal.handstand-pushup | CalSkillTiers (graduated) | existing |
| `cal.clapping-handstand-pushup` | Clapping HSPU | 7 (mythic) | reps ×1 | cal.ninety-degree-pushup | CalSkillTiers (graduated) | existing |
| `cal.triple-clap-pushup` | Triple Clap Push-Up | 7 (mythic) | reps ×1 | cal.clapping-pushup | CalSkillTiers (flat reps) | existing |
| `cal.pseudo-planche-pushup` | Pseudo-Planche Push-Up | 4 | reps ×5 | cal.decline-pushup | CalSkillTiers (graduated) | existing |
| `cal.tuck-planche-pushup` | Tuck Planche Push-Up | 5 | reps ×3 | cal.pseudo-planche-pushup | CalSkillTiers (graduated) | existing |
| `hs.straddle-press` | Straddle Press to Handstand | 6 | reps ×3 | hs.tuck-press | HsSkillTiers (graduated) | existing |
| `hs.press-to-handstand` | Press to Handstand | 7 | reps ×1 | hs.straddle-press | HsSkillTiers (graduated) | existing |

**Supporting intermediate nodes already in the tree** (the assisted/lead-up variants the ladders lean on):
`cal.sphinx-pushup`, `cal.archer-pushup`, `cal.one-arm-pushup`, `cal.explosive-pushup`, `cal.clapping-pushup`, `cal.diamond-pushup`, `cal.decline-pushup`, `hs.tuck-press`, `hs.tuck-handstand`, `hs.wall-handstand-30`, `hs.freestanding-hs-30`, `pl.tuck-planche`, `pl.straddle-planche`, `pl.full-planche`.

> **Orphan flag.** `Models/SkillTreeContent/Tiers/HspuSkillTiers.swift` defines a *fully graduated* 10-skill `hspu.*` HSPU ladder (pike → elevated pike → wall negative → first wall HSPU → wall volume → deficit → freestanding negative → first freestanding → freestanding volume). It is still wired (`case "hspu": return HspuSkillTiers.table`) **but no tree node uses the `hspu.` prefix anymore** — the cluster was collapsed into `cal.handstand-pushup` (see SkillTreeContent.swift L225). That table is dead code today, *but it is the best existing template* for the graduated HSPU ladder proposed below. Recommend either re-pointing `cal.handstand-pushup` family at it or deleting it once the cal.* ladders below are adopted (per "delete old code on change" memory).

---

## 2. Canonical progressions (Overcoming Gravity 2, Steven Low — FIG-COP based)

From the OG2 progression charts (Handstand Chart, Pushing Chart). FIG bands: Basic (Beg), A-Lvl (Int), B-Lvl (Adv), C-Lvl (Elite).

**HSPU (HS Chart, "Handstand Pushups" col):**
L1 Pike HeSPU → L2 Box (elevated) HeSPU → L3 Wall HeSPU Eccentric → L4 Wall HeSPU → **L5 Wall HSPU** → L6 Free HeSPU → **L7 Free HSPU**. (HeSPU = head-only/partial ROM; HSPU = full ROM with deficit so the head passes below the hands.) One-Arm HS sits at L10 (B-Lvl).

**Planche pushup / 90° (Pushing Chart, "PB/FL PL Pushups" + "90 Deg Dips" cols):**
Tuck PL PU (L4–6) → Adv Tuck PL PU (L7) → Tuck PL PU full (L8) → Straddle PL PU (L10) → Half-Lay/1-Leg PL PU (L12–14) → **Full PL PU (L15)**. The 90° line is its own dip-deficit ramp: Wall PPPU → 90°+30 → … → 90°+88 (the "90-degree pushup" = bent-arm planche line, a B/C-level element).

**One-arm pushup (Pushing Chart "One Arm Pushups" col):**
Elevated OA PU (L5) → Straddle OA PU (L6) → Straight-Body OA PU (L8) → Side OA PU (L13).

**Press to handstand (HS Chart, "Straight Arm Press HS" col):**
Wall Str Press Ecc (L5) → Ele(vated) Str Std Str Press (L6) → Str/Pike Std Str Press (L7) → L-sit/Str-L Str Press (L8) → … → R SA Pike Press (L12). The bent-arm press line is the "Press Handstands" col: BA BB Press (L5) → L-Sit BA BB Press (L6) → CR SB Press (L7) → BA SB Press (L8) → PB Dip SB to HS (L10). Tuck → Straddle → straight-leg full press is the standard gym lead-up sequence.

**Sources:**
- [Overcoming Gravity 2nd Edition & Progression Charts — Steven Low](https://stevenlow.org/overcoming-gravity/)
- [OG2 Exercise Charts (PDF)](https://www.calisthenics-101.co.uk/wp-content/uploads/2020/05/Overcoming-Gravity-2nd-Edition-Exercise-Charts.pdf)
- [The Fundamentals of Bodyweight Strength Training — Steven Low](https://stevenlow.org/the-fundamentals-of-bodyweight-strength-training/)

---

## 3. Proposed 9-tier ladders

Convention: **reps** unless a variant/hold is named. **Forged = first clean rep of the named skill.** Lower tiers reward an easier-but-relevant variant; upper tiers escalate to volume / a harder variant / deficit. `*` marks a variant **not currently a tree node** (would need a `variant("…")` criterion or a new node).

### 3a. HSPU — `cal.handstand-pushup` (keystone)

Anchor: Forged = first clean **wall HSPU**. Below it is the OG2 partial-ROM / negative ladder; above it is deficit then freestanding.

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | elevated pike pushup *(existing node)* | 10 |
| novice | pike HeSPU — partial-ROM, head only* | 5 |
| apprentice | wall HSPU negative* (5s eccentric) | 3 |
| **forged** | **wall HSPU (full ROM)** | **1** |
| veteran | wall HSPU | 5 |
| master | wall HSPU | 8 + deficit wall HSPU* ×1 |
| vessel | deficit wall HSPU* | 3 |
| unbound | freestanding HSPU negative* ×3 + deficit wall HSPU ×5 | — |
| ascendant | **freestanding HSPU** | 3 |

*Build-out:* introduce `pike HeSPU`, `wall HSPU negative`, `deficit wall HSPU`, `freestanding HSPU negative`, `freestanding HSPU` as `variant("…")` strings (or nodes). The existing `HspuSkillTiers` table already encodes almost exactly this ladder and is the ready template.

### 3b. Ninety-Degree Push-Up — `cal.ninety-degree-pushup`

Anchor: Forged = first 90° rep. It is a bent-arm planche line, so the lead-up is planche + freestanding HSPU strength (matches the current cascade, just re-graduated lower).

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | wall HSPU *(via cal.handstand-pushup)* | 5 |
| novice | tuck planche* hold + wall HSPU ×5 | hold |
| apprentice | freestanding HSPU* negative + straddle planche* | 3 |
| **forged** | **90-degree pushup** | **1** |
| veteran | 90-degree pushup | 2 |
| master | 90-degree pushup | 3 |
| vessel | 90-degree pushup ×3 + full planche* hold | — |
| unbound | 90-degree pushup ×5 + freestanding HSPU ×1 | — |
| ascendant | 90-degree pushup ×8 + freestanding HSPU ×3 | — |

*(Largely matches current CalSkillTiers entry; proposal lowers entry from "tuck planche only" to a wall-HSPU rung so an advanced-but-not-elite lifter can still register Initiate.)*

### 3c. Clapping HSPU — `cal.clapping-handstand-pushup` (mythic)

Anchor: Forged = first clapping HSPU. Below: stable freestanding HSPU + deficit power base.

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | wall HSPU | 5 |
| novice | freestanding HSPU* | 1 |
| apprentice | deficit/explosive wall HSPU* | 3 |
| **forged** | **clapping handstand pushup** | **1** |
| veteran | clapping handstand pushup | 2 |
| master | clapping handstand pushup | 3 |
| vessel | clapping HSPU ×3 + freestanding HSPU ×3 | — |
| unbound | clapping HSPU ×5 + freestanding HSPU ×5 | — |
| ascendant | clapping HSPU ×8 + freestanding HSPU ×8 | — |

### 3d. Bent Arm Press — `cal.bent-arm-press`

Anchor: Forged = first bent-arm press to handstand (tripod/tuck/straddle entry). OG2 "Press Handstands" col gives the lead-up: support hold → L-sit BA press → straddle BA press.

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | wall handstand hold* *(hs.wall-handstand-30)* | hold |
| novice | tripod-to-tuck negative* | 3 |
| apprentice | bent arm press (kick-assisted)* | 1 |
| **forged** | **bent arm press** | **3** |
| veteran | bent arm press | 5 |
| master | bent arm press | 6 |
| vessel | bent arm press ×8 + straddle press* ×1 | — |
| unbound | bent arm press ×10 + straddle press ×3 | — |
| ascendant | bent arm press ×12 + press to handstand* ×1 | — |

*(Current entry is flat reps 1→12. Proposal adds a sub-Forged on-ramp + bridges the top into the straight-arm press family.)*

### 3e. Press to Handstand — `hs.press-to-handstand`

Anchor: Forged = first straight-leg, straight-arm press. Lead-up: tuck press → straddle press → wall straight-arm press eccentric.

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | tuck press *(hs.tuck-press)* | 1 |
| novice | tuck press | 3 |
| apprentice | straddle press *(hs.straddle-press)* | 1 |
| **forged** | **press to handstand** | **1** |
| veteran | press to handstand | 2 |
| master | press to handstand | 3 |
| vessel | press to handstand | 5 |
| unbound | press to handstand | 7 |
| ascendant | press to handstand | 10 |

*(Matches the existing HsSkillTiers ladder almost exactly — already well-graduated; listed for completeness/parity.)*

### 3f. Straddle Press to Handstand — `hs.straddle-press`

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | straddle press | 1 |
| novice | straddle press | 2 |
| apprentice | straddle press | 3 |
| **forged** | **straddle press** | **5** |
| veteran | straddle press | 7 |
| master | straddle press | 10 |
| vessel | straddle press ×10 + press to handstand ×1 | — |
| unbound | straddle press ×12 + press to handstand ×3 | — |
| ascendant | straddle press ×15 + press to handstand ×5 | — |

*(Already graduated in HsSkillTiers — no change needed; here for parity.)*

### 3g. Planche Push-Up line — `cal.pseudo-planche-pushup` / `cal.tuck-planche-pushup`

**`cal.pseudo-planche-pushup`** (Forged = 10 pseudo-planche pushups). Already graduated:

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | pushup | 5 |
| novice | pushup | 10 |
| apprentice | pseudo-planche pushup | 5 |
| **forged** | **pseudo-planche pushup** | **10** |
| veteran | pseudo-planche pushup | 15 |
| master | pseudo-planche pushup | 20 |
| vessel | pseudo-planche pushup ×20 + tuck planche hold | — |
| unbound | pseudo-planche pushup ×25 + tuck planche hold | — |
| ascendant | pseudo-planche pushup ×30 + tuck planche pushup ×3 | — |

**`cal.tuck-planche-pushup`** (Forged = 3 tuck-planche pushups). OG2: Tuck PL PU → Adv Tuck PL PU → Straddle PL PU → Full PL PU. Already graduated; recommend top tiers bridge into the **planche-pushup** (`pl.*`) line not just the static hold:

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | tuck planche hold | hold |
| novice | tuck planche hold + pseudo-planche pushup ×10 | — |
| apprentice | tuck planche pushup | 1 |
| **forged** | **tuck planche pushup** | **3** |
| veteran | tuck planche pushup | 5 |
| master | tuck planche pushup | 7 |
| vessel | tuck planche pushup ×7 + straddle planche hold | — |
| unbound | tuck planche pushup ×10 + straddle planche hold | — |
| ascendant | tuck planche pushup ×10 + full planche hold | — |

### 3h. Floating Pike / Elevated Pike (mid-progression rungs)

`cal.elevated-pike-pushup` is already graduated (pike → elevated pike → wall HSPU negative bridge). `cal.floating-pike-pushup` is currently **flat reps 1→15** — recommend re-graduating it to bridge into the bent-arm press at the top:

| Tier (case) | Variant / exercise | reps |
|---|---|---|
| initiate | elevated pike pushup | 5 |
| novice | elevated pike pushup | 8 |
| apprentice | floating pike pushup | 1 |
| **forged** | **floating pike pushup** | **4** |
| veteran | floating pike pushup | 7 |
| master | floating pike pushup | 10 |
| vessel | floating pike pushup ×10 + bent arm press ×1 | — |
| unbound | floating pike pushup ×13 + bent arm press ×3 | — |
| ascendant | floating pike pushup ×15 + bent arm press ×5 | — |

---

## 4. Gaps & biggest build-outs

1. **Missing partial-ROM / negative variant names (biggest build-out).** The graduated HSPU ladder needs `pike HeSPU`, `wall HSPU negative`, `deficit wall HSPU`, `freestanding HSPU negative`, `freestanding HSPU` as recognized exercise tokens. The `HspuSkillTiers.swift` table already references them as `exerciseName:` strings — confirm these exist in the exercise catalog (`MovementCatalog.swift`), else logging them won't satisfy the criteria. **Verify catalog coverage before adopting.**
2. **Dead `HspuSkillTiers` table.** Fully built graduated HSPU ladder exists but is unreachable (no `hspu.` nodes). Either re-point `cal.handstand-pushup` (+ siblings) at this content or delete it. Cleanest path: lift its ladders into the `cal.*` HSPU entries in CalSkillTiers, then delete the `hspu` table + its `case "hspu"` dispatch in one commit.
3. **Flat-rep ladders that ignore the real progression.** `cal.floating-pike-pushup`, `cal.triple-clap-pushup`, `cal.bent-arm-press`, `cal.one-arm-pushup`, `cal.explosive-pushup`, `cal.clapping-pushup`, `cal.archer-pushup`, `cal.sphinx-pushup` are linear single-exercise rep ramps. They *work* but don't reward the assisted/lead-up variant at low tiers nor a harder variant at the top. Sections 3c/3d/3h above show the graduated rewrites for the three highest-value ones (clapping HSPU, bent arm press, floating pike).
4. **Planche-pushup top tiers gate on a static hold, not the next pushup variant.** `cal.tuck-planche-pushup` tops out compounding with `straddle planche`/`full planche` *holds*. OG2 progression is straddle **planche pushup** → full **planche pushup**. Either add `straddle planche pushup` / `full planche pushup` tokens (new) or accept the hold as a proxy.
5. **One-arm pushup line not graduated by OG2 sequence.** `cal.one-arm-pushup` is flat reps; OG2 lead-up is elevated OA → straddle OA → straight-body OA → side OA. Low priority (it's a B-level element, plenty of headroom in flat reps), flagged for completeness.

---

## 5. Adoption notes (for the eventual Swift change — NOT done here)

- All edits land in `Models/SkillTreeContent/Tiers/CalSkillTiers.swift` and `HsSkillTiers.swift` (the `[String: [SkillTier: TierCriterion]]` tables). No node definitions in `SkillTreeContent.swift` need to change — only their tier criteria.
- `TierCriterion` already supports everything required: `.reps(n, exerciseName:)`, `.variant(name)`, `.compound([...])`, `.seconds(t)` for holds.
- The `#if DEBUG` asserts require **exactly 9 tiers per skill, one per `SkillTier` case** — keep all 9 rows.
- Per project memory: when re-graduating, delete the dead `HspuSkillTiers` table + its dispatch case in the **same commit**; don't leave it parked.
