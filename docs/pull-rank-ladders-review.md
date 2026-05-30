# Pull-Family Rank Ladders — Review

Generated 9-tier ladders for all **26 `pp.*` skill nodes**, produced by
`SkillTierGenerator.generate` from the `PullSkillAnchors.table` anchors in
`UNBOUND/Models/SkillTierGenerator.swift`. Numbers below are the **real generated
output** (transcribed from a test run, not hand-computed).

Tier columns, in rawValue order:

`Initiate · Novice · Apprentice · Forged · Veteran · Master · Vessel · Unbound · Ascendant`

(Ascendant displays as "Unbound" = peak.)

**`exerciseName` is the live matching string** — it must equal the movement the
corresponding `PpSkillTiers` node logs against, or the skill silently can't rank
up (orphan-name trap). The `exerciseName` column is the string the generator emits.

`.full` = grind move (5 real strength levels → 9 interpolated tiers).
`.feat(floor)` = hard feat (first rep jumps to floor rank; ranks below = locked,
all show the entry value; ladder climbs floor→peak).

---

## Basic pull (grind volume / tempo / ROM)

| node id | exerciseName | metric | spec | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascendant |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| pp.pullup | pullup | reps | full | 1 | 4 | 6 | 10 | 13 | 18 | 23 | 28 | 32 |
| pp.strict-pullup | pullup | reps | full | 1 | 4 | 6 | 10 | 13 | 18 | 23 | 28 | 32 |
| pp.wide-pullup | wide pullup | reps | full | 1 | 3 | 4 | 7 | 9 | 13 | 17 | 21 | 24 |
| pp.explosive-pullup | explosive pullup | reps | full | 1 | 2 | 3 | 5 | 7 | 10 | 12 | 15 | 18 |

## Chin chain

| node id | exerciseName | metric | spec | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascendant |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| pp.chin-up | chin-up | reps | full | 1 | 4 | 7 | 10 | 13 | 18 | 22 | 26 | 30 |
| pp.strict-chin-up | chin-up | reps | full | 1 | 4 | 7 | 10 | 13 | 18 | 22 | 26 | 30 |
| pp.l-sit-chin-up | l-sit chin-up | reps | full | 1 | 2 | 3 | 5 | 7 | 10 | 13 | 17 | 20 |

## Muscle-up

| node id | exerciseName | metric | spec | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascendant |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| pp.muscle-up | muscle-up | reps | full | 1 | 2 | 3 | 5 | 7 | 9 | 11 | 14 | 17 |
| pp.strict-muscle-up | strict muscle-up | reps | feat(forged) | 1 | 1 | 1 | 1 | 2 | 3 | 5 | 8 | 12 |
| pp.ring-muscle-up | ring muscle-up | reps | feat(veteran) | 1 | 1 | 1 | 1 | 1 | 2 | 4 | 6 | 9 |

## Weighted (added-load bodyweight ratio; Elite ≈ +100% bw = 1.0)

| node id | exerciseName | metric | spec | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascendant |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| pp.weighted-pullup | weighted pullup | bwRatio | full | 0.10 | 0.20 | 0.25 | 0.40 | 0.50 | 0.65 | 0.75 | 0.90 | 1.00 |
| pp.weighted-chin-up | weighted chin-up | bwRatio | full | 0.10 | 0.20 | 0.30 | 0.40 | 0.50 | 0.65 | 0.75 | 0.90 | 1.00 |

## Rows (scale off inverted-row [1,7,19,33,48])

| node id | exerciseName | metric | spec | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascendant |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| pp.row | row | reps | full | 1 | 4 | 7 | 13 | 19 | 26 | 33 | 41 | 48 |
| pp.incline-row | incline row | reps | full | 5 | 9 | 12 | 19 | 25 | 33 | 40 | 48 | 55 |
| pp.decline-row | decline row | reps | full | 1 | 3 | 5 | 10 | 14 | 20 | 26 | 33 | 40 |
| pp.tuck-row | tuck row | reps | full | 1 | 3 | 4 | 7 | 10 | 14 | 18 | 23 | 28 |
| pp.straddle-row | straddle row | reps | full | 1 | 2 | 3 | 5 | 7 | 10 | 13 | 17 | 20 |
| pp.one-arm-row | one-arm row | reps | feat(apprentice) | 3 | 3 | 3 | 5 | 8 | 12 | 16 | 20 | 25 |

## Holds (seconds)

| node id | exerciseName | metric | spec | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascendant |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| pp.dead-hang | dead hang | seconds | full | 20 | 30 | 40 | 50 | 60 | 75 | 90 | 105 | 120 |

## Feats (one-arm / lever / plyo / archer — first rep jumps to floor)

| node id | exerciseName | metric | floor | Init | Nov | App | Forged | Vet | Master | Vessel | Unbound | Ascendant |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| pp.archer-pullup | archer pullup | reps | apprentice | 1 | 1 | 1 | 2 | 3 | 4 | 6 | 8 | 9 |
| pp.clapping-pullup | clapping pullup | reps | forged | 1 | 1 | 1 | 1 | 2 | 3 | 5 | 7 | 10 |
| pp.heighted-chin-up | heighted chin-up | reps | forged | 1 | 1 | 1 | 1 | 2 | 3 | 5 | 8 | 12 |
| pp.oap-negative | one-arm pullup negative | reps | apprentice | 1 | 1 | 1 | 3 | 4 | 5 | 6 | 9 | 12 |
| pp.tuck-front-lever-pullup | tuck front lever pullup | reps | veteran | 1 | 1 | 1 | 1 | 1 | 3 | 5 | 7 | 10 |
| pp.one-arm-pullup | one-arm pullup | reps | vessel | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 3 | 5 |
| pp.one-arm-chin-up | one-arm chin-up | reps | vessel | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 3 | 5 |

---

## Authoring notes & judgment calls (for human review)

- **`exerciseName` matching:** every name above is copied verbatim from the
  movement string the matching `PpSkillTiers` node already logs against, so
  name-resolution holds. Strict variants intentionally reuse a base name
  (`pp.strict-pullup` → `pullup`; `pp.strict-chin-up` → `chin-up`) — these are
  distinct ladders over the same logged exercise.

- **`pp.heighted-chin-up` — JUDGMENT CALL.** The brief listed this under the
  weighted (`bodyweightRatio`) group, but its `PpSkillTiers` node and live
  exercise string is `"heighted chin-up"` (an elevated / one-arm-assist chin —
  a *reps* movement with no added external load). Scoring it by `bodyweightRatio`
  against `"heighted chin-up"` would never match any logged set (no load ratio is
  recorded for it) — the orphan trap. I authored it as a **`.feat(floor: .forged)`
  reps ladder** instead so it actually ranks. **Please confirm** this is the
  intended movement; if it should genuinely be a loaded chin variant, the
  exerciseName + metric need to change together.

- **`pp.one-arm-row` floor choice.** Made it a `.feat(floor: .apprentice)` with a
  rep entry of 3 (not 1). A first one-arm row is not a rare one-rep feat the way an
  OAP is — it's an accessible bridge move — so the floor sits low and the entry is
  a small set rather than a single rep. Flagging in case you'd rather model it as a
  plain `.full` grind.

- **`pp.tuck-front-lever-pullup` floor = veteran.** Per brief guidance
  (tuck-front-lever-pullup ≈ Veteran). Top of 10 reps is a deliberately modest
  ceiling for a lever pull.

- **Feat floors used:** archer-pullup `apprentice`, oap-negative `apprentice`,
  one-arm-row `apprentice`; clapping-pullup `forged`, heighted-chin-up `forged`,
  strict-muscle-up `forged`; ring-muscle-up `veteran`, tuck-front-lever-pullup
  `veteran`; one-arm-pullup `vessel`, one-arm-chin-up `vessel` (1 rep = basically
  elite → Vessel; cap stops "do 12 of them").

- **Endurance ceilings capped:** incline-row tops at 55, decline-row 40, row 48
  (inverted-row Elite anchor) — no 100+ rep creep.

- **Strict variants sit *under* their base** (strict-pullup 28 vs pullup 32,
  strict-chin-up 26 vs chin-up 30) because a strict rep is harder than the
  crowd-sourced base which permits some kip/swing.

- **All 26 generate exactly 9 complete tiers** — verified by
  `testEveryPullAnchorGeneratesNineCompleteTiers` (also asserts table.count == 26),
  which catches any malformed feat ladder count.
