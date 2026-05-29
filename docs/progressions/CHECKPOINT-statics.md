# CHECKPOINT — Statics Family Tier-Criteria Audit

**Scope:** planche (`pl.*`), handstand (`hs.*`), one-arm handstand (`oah.*`), front/back lever + L-sit + V-sit + german hang (`cl.*`), L-sit base (`cal.l-sit-10`), dead-hang holds (`co.*`).
**Status:** READ-ONLY audit. No Swift edited. Source of truth for a future reseat; OWNER refines content.
**Date:** 2026-05-29. Branch `main`, after `f7e4a32` (Foundation 2 — honest hold-seconds).

---

## 0. Mechanism facts that drive every finding (verified in code)

1. **`.seconds` is now LIVE** (`Services/Ranking/TierCriterionEvaluator.swift:22-24,72-78`). It reads
   `bestSeconds(in:) = max(durationSeconds ?? reps)` over non-warmup sets. `SetLog.durationSeconds: Int?`
   exists (`Models/WorkoutLog.swift:41`). **So statics CAN graduate by hold-time today** — every hold
   ladder below that still uses `.variant`/rep-proxy is now *fixable* by swapping to `.seconds(t)`
   (or `.compound([.variant(name), .seconds(t)])` to pin the variant + the duration).

2. **Tiers are stamped by EXACT node-id match.** `SkillTreeContent.swift:27`:
   `copy.tierCriteria = tierCriteriaTable(for: node.id)[node.id] ?? [:]`. Routing is by prefix
   (`:38-52`). Consequence:
   - A **table key with no live node of the same id = pure orphan** (its 9 tiers are never stamped onto
     anything, self-register nothing).
   - A **live node with no matching table key = empty criteria** (`[:]`, unrankable). *(None found in the
     static families — every live static node is covered.)*

3. **Self-registration** (`MovementCatalog.swift:1410-1436, 1507-1542`): each LIVE node registers as a
   `.skillTarget` whose aliases include `node.id`, `node.title`, `node.subtitle`, `node.target.displayName`,
   **and every exerciseName/variant string inside that node's stamped `tierCriteria`** (`skillTreeAliases`
   walks `node.tierCriteria.values`). Plus hand-authored `skillDrill` aliases (`:1398-1409`).
   **A token therefore resolves if it is: (a) a catalog canonical/alias, (b) a live-node target displayName,
   or (c) used as a criterion in some LIVE (stamped) node.** A token that appears ONLY in an orphan table,
   or is net-new, resolves nowhere → silent never-match.

4. **DEBUG asserts all match actual unique-key counts** (verified by grep, see §B3): Pl 10/10, Hs 20/20,
   Oah 2/2, Cl 37/37, Co 10/10, Cal 34/34. **No stale-assert B3 blocker.**

5. **Display-label swap** (`Models/SkillTier.swift`): case `.unbound` (rv7) renders "Ascendant"; case
   `.ascendant` (rv8) renders "Unbound" = peak. Tables are keyed by **case name** so they're label-correct;
   any reseat must keep the longest hold on `.ascendant`.

---

## PLANCHE (`pl.*`) — table `PlSkillTiers.swift`, 10 keys

Live `pl.*` nodes (5): `pl.tuck-planche`(T5), `pl.straddle-planche`(T6), `pl.half-lay-planche`(T6,
read as bridge), `pl.full-planche`(T7,keystone), `pl.bent-arm-planche`. The pushup/90°/one-arm tables
are **orphans** — their real nodes live under `cal.*` (`cal.tuck-planche-pushup`, `cal.pseudo-planche-pushup`,
`cal.handstand-pushup`) with their own `cal` tables, or don't exist (`pl.one-arm-planche` has no node anywhere).

### `pl.tuck-planche` (T5, target = tuck planche 5 s hold) — RESEAT
Current 9-tier (compact):
| tier | criterion |
|---|---|
| Initiate | reps 10 pseudo-planche pushup |
| Novice | reps 15 pseudo-planche pushup |
| Apprentice | variant tuck planche |
| **Forged** | variant tuck planche + reps 5 pseudo-planche pushup |
| Veteran | variant tuck planche + reps 10 pseudo-planche pushup |
| Master | variant tuck planche + reps 1 tuck planche pushup |
| Vessel | variant tuck planche + reps 3 tuck planche pushup |
| Ascendant(.unbound) | + reps 5 tuck planche pushup |
| Unbound(.ascendant) | + reps 5 tuck pl pushup + variant straddle planche |

**Diagnosis:** Low tiers are a **rep proxy on pseudo-planche-pushup**, not an easier *hold* — the
"1 rep/sec of the impossible move" anti-pattern. Forged is correct (first tuck hold) but is **double-gated**
with pushup reps. Hold duration unused despite F2.
**PROPOSED (from static-arm-balance.md §1):** hold-graduated low end —
Initiate planche-lean 20s · Novice frog-stand/band tuck 15s · Apprentice tuck planche 5s · **Forged advanced
tuck planche 10s** · then straddle 5→10s · half-lay 5s · full 5s · Unbound full 10s OR +1 full-planche pushup.
(Advanced-tuck is the canonical tuck→straddle bridge, 12-15s gate.)

### `pl.straddle-planche` (T6, 5 s) — RESEAT (rep proxy at low tiers)
Initiate variant tuck planche · Novice tuck+5 tuck-pu · Apprentice variant straddle · **Forged straddle +
5 tuck-pu** · Veteran/Master straddle + 8/10 tuck-pu · Vessel straddle+full · Unbound straddle+1 full-pu ·
Unbound(peak) straddle+3 full-pu. **Holds proxied by pushup reps; convert mid tiers to `.seconds`.**

### `pl.half-lay-planche` (T6, 3 s) / `pl.full-planche` (T7, 5 s, keystone) — RESEAT
Same pattern: `.variant` + pushup-rep compounds, no `.seconds`. Forged anchors are correct
(first half-lay / first full). full-planche peak compounds full-planche-pushup reps — keep as the harder
of two Unbound options; add a `.seconds(10)` hold-first path.

### `pl.bent-arm-planche` — minor; bridge hold, `.variant` only. Convert to `.seconds` if desired.

### ORPHAN pl tables (never stamped — node lives elsewhere or nowhere):
`pl.pseudo-planche-pushup`, `pl.tuck-planche-pushup`, `pl.full-planche-pushup`, `pl.ninety-degree-pushup`,
`pl.one-arm-planche`. The first two are **duplicates** of live `cal.*` nodes; `pl.one-arm-planche` has **no
node anywhere** (the live mythic one-arm planche, if any, is not under `pl.` or `cal.`). See §B3.

---

## HANDSTAND (`hs.*`) — table `HsSkillTiers.swift`, 20 keys

Best-covered family. Live `hs.*` nodes (14): wall-plank, wall-handstand-30, headstand, tuck-handstand,
freestanding-hs-30, crow/crane/flying-crow, frog→(see orphan), elbow-lever, one-arm-elbow-lever,
tuck/straddle/press-to-handstand, wall-supported-oah.

### `hs.freestanding-hs-30` (T3, keystone, target 30 s) — GOOD STRUCTURE, NO `.seconds`
| tier | criterion |
|---|---|
| Initiate | variant freestanding handstand |
| Novice | + variant handstand walk |
| Apprentice | + variant tuck press |
| Forged | + reps 3 tuck press |
| Veteran | + reps 5 tuck press |
| Master | + reps 3 straddle press |
| Vessel | + reps 5 straddle press |
| Ascendant | + reps 1 press to handstand |
| Unbound(peak) | + reps 3 press to handstand |

**Diagnosis:** The wall→free→press *shape* is correct and reaches the named skill early. But it's a
**pure `.variant` + press-rep ladder — duration never read.** A 30 s keystone that never checks seconds is
the core "doesn't graduate by hold-time" gap. **PROPOSED (static-arm-balance.md §2):** Initiate wall-plank
30s · Novice chest-to-wall 30s · Apprentice wall-hs 60s · **Forged freestanding 10s** · Veteran tuck 5s/free
15s · Master free 30s · Vessel 45s · Ascendant 60s · Unbound 60s + press-entry. Lower tiers stay on the wall
(easier variant), Forged = first free hold — matches contract.

### `hs.wall-plank` / `hs.wall-handstand-30` — REP-AS-SECONDS PROXY
Both ladder on `.reps(N, exerciseName: "wall plank" / "wall handstand")` where N is clearly **seconds**
(10→150). Post-F2 these should be `.seconds(N)` reading durationSeconds. **Forged = wall-plank 45 / wall-hs 45**
— OK as a hold standard, just wrong metric case.

### Arm balances (`hs.crow/crane/flying-crow/frog`, `hs.elbow-lever`, `hs.one-arm-elbow-lever`) — `.variant`+pushup
All hold-type, all `.variant` + pushup-rep compounds. Forged anchors correct (first named pose). Convert to
`.seconds` if these are meant to graduate by hold-time; lower priority than the keystones.

### Press ladder (`hs.tuck/straddle-press`, `hs.press-to-handstand`) — rep skills, ladders correct, leave.

### ORPHAN hs tables (never stamped): `hs.freestanding-hs-10`, `hs.freestanding-hs-60`, `hs.wall-handstand-60`,
`hs.frog-pose`, `hs.handstand-walk-10m`, `hs.wrist-conditioning` — no live node of that id. The proposal docs
assume freestanding-10/60 & wall-hs-60 are nodes; **they are not in the live graph** (only freestanding-hs-30
and wall-handstand-30 exist). This affects the proposed reseat (the "45 s / 60 s" rungs have no backing node;
they must be authored as `.seconds` rungs INSIDE freestanding-hs-30, not as separate nodes).

---

## ONE-ARM HANDSTAND (`oah.*`) — table `OahSkillTiers.swift`, 2 keys — THINNEST, BIGGEST GAP

Live nodes (2): `oah.one-arm-handstand-5s` (T6 mythic, target 5 s), `oah.full-one-arm-handstand` (T7 mythic).
Bridge node `hs.wall-supported-oah` (T5) lives in the hs cluster.

### `oah.one-arm-handstand-5s` (T6, 5 s) — RESEAT + MISSING LEAD-UP CHAIN
| tier | criterion |
|---|---|
| Initiate | variant freestanding handstand + reps 8 wall hspu |
| Novice | + reps 12 wall hspu |
| Apprentice | variant wall-supported one-arm handstand + reps 5 freestanding hspu |
| Forged | + reps 7 freestanding hspu |
| Veteran | variant one-arm handstand + reps 3 freestanding hspu |
| Master | + reps 5 freestanding hspu |
| Vessel | + reps 7 freestanding hspu |
| Ascendant | + reps 10 freestanding hspu |
| Unbound(peak) | one-arm hs + wall-supported OAH + reps 10 freestanding hspu |

**Diagnosis:** The whole ladder gates on **freestanding-HS + HSPU rep volume = a *strength* proxy.** The
**balance lead-up chain that actually defines OAH is entirely absent** (close-hand straddle, weight-shift,
finger tenting, fingertip-float). Only ~3 near-terminal nodes exist for the hardest skill in the tree.
**PROPOSED (static-arm-balance.md §3) — add ~4 NEW nodes** (OAH deliberately breaks "Forged = first named
rep"; the free 1-arm hold lands at **Vessel**):
| tier | variant | new node? |
|---|---|---|
| Initiate | freestanding HS 30s | `hs.freestanding-hs-30` (exists) |
| Novice | close-hand straddle HS + weight shift 20s | **NEW node #1** |
| Apprentice | wall-supported OAH 5s | `hs.wall-supported-oah` (exists) |
| Forged | 2-finger tent 10s | **NEW node #2** |
| Veteran | 1-finger tent 10s | **NEW node #3** |
| Master | fingertip-lift / off-hand float 3-5s | **NEW node #4** |
| Vessel | free one-arm handstand 5s | `oah.one-arm-handstand-5s` |
| Ascendant | free OAH 8s | proxy of same node |
| Unbound(peak) | full OAH 10s+ | `oah.full-one-arm-handstand` |

### `oah.full-one-arm-handstand` (T7) — extends 5s standard with HSPU-rep proxy; reseat to longer `.seconds`.

---

## LEVERS + CORE STATICS (`cl.*`, `cal.l-sit-10`, `co.*`)

These ladders **already cascade tuck→straddle→full structurally** (good) but are **binary `.variant` checks
or `.variant` + rep-proxy compounds — no `.seconds`.** Post-F2 the fix is the cheap authoring swap.

### FRONT LEVER — all GOOD STRUCTURE, convert to `.seconds`
- `cl.tuck-front-lever` (T4, node): Forged = `variant tuck front lever`. Low tiers hollow-body + HLR reps;
  upper tiers tuck-FL + HLR. → PROPOSED (levers-core.md): tuck-FL 3/5/8/**10(Forged)**/15s → adv-tuck 5/10/15/20s.
- `cl.straddle-front-lever` (T5, node): Forged = `variant straddle front lever`. PROPOSED adv-tuck 10s →
  one-leg 5s → straddle 3/**5(Forged)**/8/12/15/20/30s.
- `cl.full-front-lever` (T6, keystone node): Forged = `variant front lever`. PROPOSED straddle 10/15 → full
  3/**5(Forged)**/8/10/15/20/30s.
**B1 note:** proposed `one-leg front lever` is **not** a catalog token (NEEDS add); `advanced tuck front
lever` ALREADY resolves (catalog alias, `MovementCatalog.swift:848,871`).

### BACK LEVER
- `cl.straddle-back-lever` (T5, node), `cl.full-back-lever` (T5, node): same `.variant`+skin-the-cat-rep
  pattern, GOOD structure, convert to `.seconds`.
- **`cl.tuck-back-lever` = ORPHAN TABLE, NO NODE** (`ClSkillTiers.swift:243-253`, no `id:"cl.tuck-back-lever"`
  in SkillTreeContent — verified node_count=0). Its tiers never stamp; and `cl.straddle-back-lever` /
  `cl.full-back-lever` reference `.variant("tuck back lever")` which therefore **self-registers nowhere** →
  see B1. Either add the node (recommended — it's the canonical BL on-ramp) or delete the orphan table AND
  the dangling `tuck back lever` references.

### L-SIT FAMILY
- **`cal.l-sit-10`** (T4, node — **`cal` prefix, edit `CalSkillTiers.swift:308`**, easy to miss): Forged =
  `compound(variant l-sit, variant leg raise)`, upper = l-sit + leg-raise reps. PROPOSED foot-supported 10s →
  tuck 10s → one-leg 8s → **full L-sit 10s (Forged)** → 15/20/30/45/60s. `cal` also has a near-duplicate
  `cal.l-sit-20`.
- `cl.semi-straddle-l-sit` (T5), `cl.straddle-l-sit` (T6), `cl.vertical-l-sit` (T6), `cl.v-sit` (T5): all
  nodes, all `.variant`+rep-proxy, GOOD cascade, convert to `.seconds`.

### GERMAN HANG — `cl.german-hang` (T3, node, target 10 s)
| tier | criterion |
|---|---|
| Initiate/Novice/Apprentice | variant german hang |
| Forged | german hang + reps 1 skin the cat |
| Veteran..Ascendant | german hang + reps 3/5/8/10/12 skin the cat |

**Diagnosis + MONOTONICITY/DOUBLE-GATE FLAG (confirmed):** german-hang is a pure-seconds skill (no easier
variant) yet ladders on **skin-the-cat reps**, and there is a **prereq inversion**: `cl.german-hang` (T3)
prereq = `cl.tuck-front-lever` (**T4**), AND its Forged criterion needs `skin the cat` reps while
`cl.skin-the-cat` (**T4**) has `cl.german-hang` as ITS prereq → **circular T3↔T4 gate** (the `german-hang
t3<t4` flag). PROPOSED: pure `.seconds` ladder 5/8/**10(on-ramp)**/15/20/30/45/60/90s; drop the skin-the-cat
double-gate; fix the prereq to a ≤T3 skill.

### `cl.hanging-leg-raise` (T3, node) — MONOTONICITY FLAG (confirmed, rep skill not a hold)
Own ladder is monotone (2/4/6/**10**/15/20/25/30/40 reps). The `t3<t5 prereq` flag is a **downstream-consumption
inversion**: front-lever nodes consume HLR rep-counts (e.g. `cl.tuck-front-lever` veteran needs 5 HLR,
`cl.hollow-body-60` forged needs 5 HLR) at counts the HLR node only certifies above its own low tiers — the
prereq graph lets you be asked for HLR volume before the HLR node is ranked. Not a hold; flagged for graph
consistency, no `.seconds` action.

### `co.dead-hang-45` / `co.dead-hang-60` (T?, nodes) — RESEAT to `.seconds`
Both target durations (45/60 s) but ladder on **pull-up reps** (`.compound([variant dead hang, reps N pullup])`).
Post-F2 → true grip-hold `.seconds` ladders (levers-core.md §co): dh-45 10/20/30/**45**/60/75/90/105/120s;
dh-60 30/45/50/**60**/75/90/105/120/150s.

### `cl.victorian` = ORPHAN TABLE, NO NODE (`ClSkillTiers.swift:286`, node_count=0). Out of static scope but
flagged: another cl orphan alongside tuck-back-lever.

---

## B1 — UNRESOLVABLE CATALOG TOKENS (silent never-match)

**Currently-in-table blockers** (token used in a table but resolves nowhere — appears ONLY in an orphan
table, so self-registers via no live node, and is not a catalog alias):
- `frog pose` — only in orphan `hs.frog-pose` table.
- `one-arm planche` — only in orphan `pl.one-arm-planche` table.
- `reverse-hand plank` — only in orphan `hs.wrist-conditioning` table.
- `tuck back lever` — Forged of orphan `cl.tuck-back-lever`; also referenced by LIVE `cl.straddle-back-lever`
  / `cl.full-back-lever` (`.variant("tuck back lever")`) → **this one DOES bite a live node**: straddle/full
  BL Initiate/Novice tiers can never match their tuck-BL gate. **Highest-impact B1.**

*(`frog pose`/`one-arm planche`/`reverse-hand plank` are inert today because their tables are orphans/never
stamped — they only matter if those tables get wired to nodes.)*

**Tokens the PROPOSED reseat will need (not in catalog today — add as `skillDrill` aliases or node targets
before authoring, or `.variant` never matches):**
`frog stand`, `advanced tuck planche`, `band-assisted full planche`, `chest-to-wall handstand`,
`close-hand straddle handstand`, `weight shift`, `2-finger tent`, `1-finger tent`, `fingertip-lift`,
`off-hand float`, `one-leg front lever`, `advanced tuck back lever`, `one-leg back lever`,
`foot-supported l-sit`, `tuck l-sit`, `one-leg l-sit`, `tuck back lever` (if node added).
**Already resolve (no action):** `planche lean`, `advanced tuck front lever`, `crow pose`, `headstand`,
`wall handstand`, `freestanding handstand`, `frog pose`→only via NEW (current is orphan).

---

## B3 — ORPHANS / GAPS / BUGS

**OAH missing-node chain (HIGHEST priority):** add ~4 nodes — (1) close-hand straddle HS + weight-shift,
(2) 2-finger tent, (3) 1-finger tent, (4) fingertip-lift/off-hand float — to give OAH a real balance lead-up
(see OAH §). Each needs a catalog token (all 4 are B1-new). Also note proposed `hs.freestanding-hs-30` rungs
at 45/60s have **no backing node** (freestanding-hs-10/60 are orphan tables, not nodes) → author as `.seconds`
rungs inside the existing node.

**Orphan tables (entry exists, NO live node — tiers never stamped):**
- `cl.tuck-back-lever` (`ClSkillTiers.swift:243`) — **canonical BL on-ramp; recommend ADD node** (also fixes
  the `tuck back lever` B1 that bites straddle/full BL).
- `cl.victorian` (`ClSkillTiers.swift:286`) — mythic; out of static scope, flagged.
- `pl.pseudo-planche-pushup`, `pl.tuck-planche-pushup`, `pl.full-planche-pushup`, `pl.ninety-degree-pushup` —
  duplicates; real nodes are `cal.*`. **Recommend DELETE** the pl duplicates (keep cal).
- `pl.one-arm-planche` — no node anywhere; either add the mythic node or delete the table.
- `hs.freestanding-hs-10`, `hs.freestanding-hs-60`, `hs.wall-handstand-60`, `hs.frog-pose`,
  `hs.handstand-walk-10m`, `hs.wrist-conditioning` — no live node; dead tables (delete or wire to nodes).

**Monotonicity / double-gate flags (both CONFIRMED):**
- `cl.german-hang` **t3<t4 + circular**: node is T3, prereq is `cl.tuck-front-lever` (T4); Forged needs
  `skin the cat` reps but `cl.skin-the-cat` (T4) requires german-hang → fix prereq + drop skin-the-cat gate.
- `cl.hanging-leg-raise` **t3<t5 downstream**: HLR rep-counts consumed by T4+ front-lever/hollow-body tiers
  before the HLR node ranks them; graph-consistency flag, not a hold.

**Double-gating (statics generally):** planche/handstand/lever hold tiers compound the hold `.variant` with a
*rep proxy on a different exercise* (pushup, press, skin-the-cat, HLR) — the user must also own an unrelated
rep skill to rank a hold. Post-F2 the clean form is `.compound([.variant(name), .seconds(t)])` (pin variant +
duration) rather than variant + foreign-exercise reps.

**Stale DEBUG asserts:** NONE. Asserted == actual unique keys for every file: Pl 10/10, Hs 20/20, Oah 2/2,
Cl 37/37, Co 10/10, Cal 34/34. No B3 assert blocker for adds (but adding a key requires bumping the count,
and adding an OAH node bumps Oah 2→ and the live-node count the SkillGraph asserts).

---

## SUMMARY (scannable)

### (a) Nodes: reseat vs good
| Skill / node | Status |
|---|---|
| pl.tuck-planche | **RESEAT** — rep-proxy low tiers, double-gated, no `.seconds` |
| pl.straddle / half-lay / full-planche | **RESEAT** — `.variant`+pushup-rep, no `.seconds` (structure OK) |
| pl.bent-arm-planche | minor — `.variant` only |
| hs.freestanding-hs-30 (keystone) | **RESEAT metric** — good shape, never reads seconds |
| hs.wall-plank / wall-handstand-30 | **RESEAT metric** — reps that ARE seconds → `.seconds` |
| hs.crow/crane/flying-crow/elbow-lever | optional convert to `.seconds` (structure OK) |
| hs.tuck/straddle/press-to-handstand | GOOD (rep skills) — leave |
| oah.one-arm-handstand-5s / full | **RESEAT + 4 NEW NODES** — strength-proxy, no balance chain |
| cl.tuck/straddle/full-front-lever | GOOD structure → convert to `.seconds` |
| cl.straddle/full-back-lever | GOOD structure → convert to `.seconds` (+ tuck-BL B1) |
| cal.l-sit-10, cl.semi-straddle/straddle/vertical-l-sit, cl.v-sit | GOOD structure → `.seconds` |
| cl.german-hang | **RESEAT** — circular gate + skin-the-cat double-gate |
| co.dead-hang-45 / -60 | **RESEAT** — pull-up reps → `.seconds` |

### (b) Full B1 token list
- **Bites a live node today:** `tuck back lever` (breaks straddle/full back-lever Initiate/Novice).
- **Inert (orphan-only) today:** `frog pose`, `one-arm planche`, `reverse-hand plank`.
- **Must add before the proposed reseat uses them:** `frog stand`, `advanced tuck planche`,
  `band-assisted full planche`, `chest-to-wall handstand`, `close-hand straddle handstand`, `weight shift`,
  `2-finger tent`, `1-finger tent`, `fingertip-lift`, `off-hand float`, `one-leg front lever`,
  `advanced tuck back lever`, `one-leg back lever`, `foot-supported l-sit`, `tuck l-sit`, `one-leg l-sit`.
- **Already resolve:** `planche lean`, `advanced tuck front lever`.

### (c) B3 issues
- **OAH gap:** add 4 nodes (close-hand-straddle+shift, 2-finger tent, 1-finger tent, fingertip-float) + their
  catalog tokens.
- **Orphan tables:** `cl.tuck-back-lever` (ADD node — also B1 fix), `cl.victorian`, `pl.one-arm-planche`,
  duplicate `pl.{pseudo,tuck,full}-planche-pushup` + `pl.ninety-degree-pushup` (DELETE — `cal.*` is live),
  `hs.{freestanding-hs-10, freestanding-hs-60, wall-handstand-60, frog-pose, handstand-walk-10m,
  wrist-conditioning}` (no node).
- **Monotonicity (both confirmed):** `cl.german-hang` T3-prereq-is-T4 + circular skin-the-cat; 
  `cl.hanging-leg-raise` downstream rep-consumption.
- **Asserts:** all correct (no stale assert).
- **Double-gating:** statics pair hold `.variant` with foreign rep proxies; replace with
  `.compound([.variant, .seconds])`.

### (d) jlin decisions
1. **OAH new-node design:** approve the 4 lead-up nodes + their names/tokens (close-hand straddle+weight-shift,
   2-finger tent, 1-finger tent, fingertip-float) and the deliberate "named skill = Vessel, not Forged" break.
2. **Which holds convert to `.seconds`** (all are now technically possible post-F2): front lever ×3, back
   lever ×2, L-sit family ×5 (incl. `cal.l-sit-10`), german hang, dead-hang ×2, planche ×4, handstand keystone
   + wall holds. Pick the priority set vs leaving `.variant` for low-traffic poses.
3. **Orphan tables:** ADD `cl.tuck-back-lever` node (recommended) vs delete; DELETE the `pl.*-pushup`
   duplicates vs keep; decide on `pl.one-arm-planche` / hs orphan tables.
4. **german-hang prereq fix** (break the T3↔T4 circular gate) and whether to drop foreign-rep double-gates.
5. **Advanced-tuck / one-leg / tuck-L-sit:** author as `.variant` tokens inside tables (cheap, no node) vs
   real nodes (tree-shape change). Docs assume tokens; both work once the catalog tokens exist.
