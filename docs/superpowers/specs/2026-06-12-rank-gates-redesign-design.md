# Rank Gates Redesign — design spec

**Date:** 2026-06-12
**Status:** approved pending jlin's spec review
**Scope:** full redesign of the 8 overall-rank trials — challenge structures, theming, all four experience layers (discovery, entry, in-trial, verdict), rank-up cinematics, and eligibility — plus the art/motion pipeline and technical architecture to ship it.

---

## 1. North star

Rank trials are the cornerstone of UNBOUND. Each one is the threshold between two rank-worlds — entering one must feel like the biggest moment in the app. The promise: *the gate only opens when you've already become the rank; the trial is where you prove it, in its world, by its rules.*

The visual spine is **the world** (full-bleed rank-banner-style environments). The work surface stays **calm** (true-black logging UI) because mid-set this is a workout tool. Cinema lives at the bookends and between stations, never behind live controls.

## 2. Decision log (jlin's calls, in order)

1. Anchor language: the Deck of Proof card UI is the strongest current design.
2. Latitude: full challenge redesign — all 8 structures rethought; scoring anchored to existing standards where sensible.
3. Story: **destination worlds** — each trial inherits the destination rank's environment, palette, metaphor.
4. Art: generate new per-gate trial art (anime-JRPG, style-locked to the existing rank banner series). Higgsfield/Seedance approved for stills, loops, video cinematics.
5. Flow scope: all four layers (discovery, entry, in-trial, verdict).
6. Spine: direction **B — Walk Into the World**; in-trial = world-stage header + calm surface (option 2); entry = centered JRPG title card (v2).
7. Gate IV: **classic 52-card deck kept, structure as-is, full 52 to pass**; visuals fully restyled. Reframed as the veteran's own road-worn deck.
8. Difficulty: three-axis model adopted; movement-quality ladder adopted in full, with rep conversions for substitutions.
9. Test DNA diversified: II = tempo/discipline, III = heavy strikes (strength), VI = attribute seals. Only IV (and partly VII) keep conditioning DNA.
10. **No skill-gated movements in gates, ever** (planche/levers/OAP stay in the skill tree). Gates escalate only trainable levers: tempo, range, unilateral, load.
11. Pull-ups enter at Gate III (3 strict, scored) — earlier than originally drafted.
12. Eligibility: keep LVL + accumulated-rank pillars; add **Gate Keys** (named, auto-cleared proofs).
13. Rank-up: **The Crossing** generated cinematics, tiered by rank; replayable; reduced-motion fallback.
14. Verification: full gauntlet, actually executed. Implementation delegates to Codex where possible.

## 3. The world ladder

Existing rank banners define the journey (all in `Assets.xcassets/Cosmetics/profile_banner_*`):

| Rank | World | Tint |
|---|---|---|
| Initiate | the dark training room, moonlight | `textSecondary` |
| Novice | night courtyard — striking posts, one lantern | `#8D94FF` |
| Apprentice | dojo hall — weapon rack, lantern, tatami | `#C79D46` |
| Forged | the blacksmith forge — anvil, blade, fire | `#F05A28` |
| Veteran | moss-covered shrine steps in deep forest | `#64C475` |
| Master | temple above a sea of clouds at dawn | `#2C90BB` |
| Vessel | violet inner sanctum — chalice, ritual circles | `#B27AF4` |
| Ascendant | heaven's gate — colossal magenta portal-spire | `#D861DF` |
| Unbound | golden stairway into the sky temple | `#FFC857` |

Finale pattern for every gate: trial art (the threshold, newly generated) → destination rank banner (arrival). Passing a gate also unlocks that rank's profile banner cosmetic — dramatized in the verdict.

## 4. The difficulty model

Three axes, each scaling independently and evenly:

1. **Duration:** 15 → 20 → 30 → 42 → 50 → 58 → 65 → 75 min.
2. **Structure pressure:** untimed rep gates → bell windows → untimed heavy sets → random order → ladder + boss hold → HP bars under caps → 3-act siege → everything at peak.
3. **Movement quality** (new axis): pinned minimum movements per gate where equipment exists; substitutions always allowed at converted volume.

**Pull ladder:** rows (I–II) → 3 strict pull-ups scored (III) → pull-ups preferred, rows ×1.5 (IV) → strict floors ~10–12 (V) → higher floors, weighted options (VI–VII) → weighted standard (VIII).
**Push ladder:** incline (I) → floor push-ups (II–III) → volume (IV) → deficit/blend (V) → dip-track option (VI) → weighted/tempo elite (VII–VIII).

**Guarantees:**
- Nobody faces a gate cold: gates unlock on eligibility (LVL + accumulation + keys); the program trains you between gates. Infinitely retryable.
- Gate I requires no floor push-up (incline is the standard); no pull-up is required anywhere before Gate III's scored strike. Rows are a real standard at I–II, not a consolation.
- **No skill-gated movements ever** (decision 10). Escalation levers: tempo (slow/paused), range (deficit/deep), unilateral, load (backpack/vest for no-gym — carry standards already assume a loadable backpack).
- The summit is credible: peak gates demand weighted/strict standards where equipment exists.

**Persona map ("what marks where"):** I ≈ finished on-ramp (~1 mo) · II ≈ habit formed (~3 mo) · III ≈ first real intensity (~6 mo) · IV ≈ year-one breakthrough · V ≈ gym regular (1.5–2 yr) · VI ≈ advanced (2–3 yr) · VII ≈ very advanced (3+ yr) · VIII ≈ the 1%, multi-year arc.

**Volume note:** Gate IV (~380 reps) is deliberately the capacity peak of the early game (jlin call, decision 7). The curve dips into V and rebuilds to VIII (~430 rep-equivalents).

## 5. The eight gates

User-facing copy never uses EMOM/AMRAP/WOD/metcon — world language only.

### Gate I — FIRST LIGHT (Initiate → Novice) · completeness · ~15 min
You step out of the dark room and light the courtyard. Five stations = five lanterns mapped to real places in the Novice banner; the trial ends at the dojo door.

| Lantern | Test | Floor (`TrialStandards.Daily100`, unchanged) |
|---|---|---|
| The Path | lower | 20 reps (bw squat / goblet / leg press) |
| The Posts | push | 15 reps (incline push-up / push-up / machine press) |
| The Banner | pull | 20 reps (inverted row / db row / cable row) |
| The Steps | engine | 20 step-ups in a **2:00 window** (new — teaches Gate II's bell) |
| The Door | core | 25s plank — "hold the light steady" |

Loadout movement options carry over from current daily100 definitions. Beats: each lantern ignites on the world art ("The path is lit."); finale = dawn floods the art → Novice banner.

### Gate II — THE COUNT (Novice → Apprentice) · discipline/tempo · ~20 min
The dojo's bell sets the cadence; you move with it, not against it. Calibration from `TrialStandards.OperatorScreen`.

| Bell | Test | Floor |
|---|---|---|
| The Long Bell | 700m engine at steady bell pace | 6:00 window |
| Second Count | lower ON the bell (4s cycle) | 30 reps in cadence window |
| Third Count | push on the bell | 18 reps |
| Fourth Count | pull on the bell | 24 reps |
| The Water Carry | controlled carry — spill nothing | 80m @ 20% bw, 3:00 |
| Stillness | core hold (mokusō — every dojo session ends here) | 60s, **universal across loadouts** |

Cadence implementation: window = reps × cycle + small buffer (existing window evaluation; no new scoring machinery). Metronome gong + haptic tick per count. Finishing far early gets gentle guidance ("don't rush the count"), never a fail.

### Gate III — THE FORGING (Apprentice → Forged) · strength · ~30 min
A heavy top-set day as ritual. No clock anywhere: "The fire waits. The steel doesn't rush."

Structure: **Stoke the Fire** (300m easy engine + ramp sets, unscored) → three **Strikes** per movement (hinge, push, pull): 8 reps → 5 heavier → **3 at the heaviest (scored)** → **The Quench** (40m heavy carry).

Scored bars: final 3-rep strikes must meet **Forged-tier `StrengthStandards` ratios** for bodyweight (e.g. hinge 1.5×bw → 120kg at 80kg bw — exact ratios read from the standards engine, single source of truth). Pull strikes escalate by grip/leverage: 8 rows → 5 chin-ups → **3 strict pull-ups (scored)**.
No-gym track (no-skill-gate rule): tempo + deficit + backpack load — e.g. hinge: single-leg RDL w/ backpack (scored: ~25% bw slow); push: 8 push-ups → 5 deficit → 3 slow-paused deficit; pull: elevated-row tempo track. Beats: hammer-fall haptic per completed strike, blade glows hotter; quench = steam hiss, glow dies to an edge → Forged banner.

### Gate IV — DECK OF PROOF (Forged → Veteran) · capacity under chaos · ~42 min
The veteran's own road-worn deck. **Mechanics locked as-is:** 52 cards, suit = movement (push/pull/lower/core), value = reps (ace 11, faces 10), 30s rest between cards, full clear to pass (`TrialStandards.DeckOfProof`). One ladder addition: pull-suit cards prefer pull-ups at card value; row cards count ×1.5.
Presentation rehaul: 52 illustrated card faces (17 unique paintings: 12 faces + 4 aces + back; number cards template-rendered — crest + big value + corner suit glyph for instant parsing). Card-flip + snap haptic per draw; done-stack shows progress; every ~13 cards the camera rises one shrine landing (4 quiet world-beats inside the chaos); held beat on the final card ("The last battle.") → Veteran banner.

### Gate V — THE ASCENT (Veteran → Master) · endurance + control · ~50 min
Ten floors rising through cloud layers; the temple reveals itself as you climb (`TrialStandards.Tower` floors carry over; pull floor converts to ~10–12 strict pull-ups, balance checkpoint).
Path 300m → work floors (lower 24 / push 20 / pull / hinge 30 / carry 100m) → cloudline engine 500m → thin-air floors (explosive 20, blend 15/15) → **Floor 10: the Summit Gate, 90s boss hold** at the temple doors (wind audio dies to silence for the hold). Header art gains altitude per floor.

### Gate VI — THE SEVEN SEALS (Master → Vessel) · the attribute hexagon · ~58 min
Seven ritual circles; each seal is one attribute made physical; 6:00 cap each (• = `TrialStandards.BossRush` anchor):

| Seal | Test |
|---|---|
| ENDURANCE | 800m engine • |
| VITALITY | 48-rep lower volume • |
| EXPLOSIVENESS | 40 power reps • |
| POWER | 3 heavy reps at Vessel-tier `StrengthStandards` ratios (new) |
| CONTROL | 2×60s unbroken holds • |
| MOBILITY | deep-range station: weighted deep-squat hold + cossack flow (new — balance checkpoint) |
| SPIRIT (always last) | 200m carry @ 30% bw • |

Seal broken = circle shatters, chalice flame grows. Profile shows the weakest seal before entry (reads the attribute hexagon directly).

### Gate VII — THE THRESHOLD (Vessel → Ascendant) · the grind · ~65 min
A siege in three acts (`TrialStandards.Raid` intact; pull-ups per ladder): **The Approach** (3×400m intervals, 18:00 cap) → **The Breach** (4 rounds: 10 hinge / 10 upper / 60m carry, 32:00 cap) → **Hold the Light** (one unbroken 120s control hold inside the opening gate). The portal art opens progressively across the full trial — the only gate whose world transformation spans all ~65 minutes.

### Gate VIII — THE LAST GATE (Ascendant → Unbound) · everything · ~75 min
Seven landings on the golden stairway — one memory from every gate, at peak standard (`TrialStandards.FinalExam` budgets redistributed; full calibration checkpoint):
1. First Light — five-lantern circuit, one fast set each
2. The Count — one bell window at strict pace
3. The Forging — one heavy strike: 3 reps at Unbound-tier ratios
4. The Deck — a 13-card suit run
5. The Ascent — climb block into a held position
6. The Seals — **one attribute station: the user's weakest** (resolved from the hexagon at draft time)
7. The Threshold — 240m carry @ 35% bw
**The Summit** — 120s final hold on the top stair → the gold flood.

## 6. The shared experience spine

1. **Discovery — NextGateCard** (Profile; Home when close): threshold art **sealed** (darkened + gate sigil) while accumulating. Eligibility renders as world-language quest items. Keys light as cleared; last key → seal-crack reveal + push notification ("The Forge is open.").
2. **The Gate Hall** (entry sheet): full-bleed threshold art + ambient loop; centered title stack (gate numeral → tier divider → trial name → one-line promise → rank transition → difficulty pips → format meta; radial vignette behind text); stations preview in world language; loadout pick (no-gym/home/gym); past attempt cards; BEGIN.
3. **Entry ceremony:** title stack types on line-by-line with haptic beats over the loop; ENTER lights last.
4. **In-trial — GateActiveView:** world-stage header at full brightness (top ~25–30%, art bleeding into true black) holding trial name, station N/M, progress rail, and the gate's living-world layer (lanterns/blade/seals/altitude/portal evolving with progress). Below: the calm logging surface (true-black, `#121212` cards, big targets — reuses existing ActiveWorkout logging components; one logging spine).
5. **Station-clear beats — GateBeatOverlay:** full-bleed world floods back, the world element advances, one line of copy, signature haptic (hammer fall / bell toll / seal shatter / card snap), recedes. Cinema between sets, clarity during them.
6. **Verdict — pass:** the hush ("The gate is answered.") → calm station-by-station accounting (named beats, your numbers vs floors) → **Gate Card minted** (gate art, name, date, defining number, destination crest stamp) → The Crossing.
7. **Verdict — fail:** world steady ("The gate holds.") → honest accounting (posted vs floor) → **"What stands between you"**: deltas become named training targets fed into coach/program context (one progress pipeline) → rematch CTA ("The gate isn't going anywhere."). Failed attempts mint unstamped cards with attempt count — the 0/3 → stamped arc lives in records.
8. **Trial Records shelf** (Profile): all gate cards, attempt history, replayable Crossings. Gate cards are the share cards.

## 7. Eligibility — two pillars kept, one added

Kept untouched: **Overall LVL minimum** (pacing) and **build-weighted accumulated rank ≥ target tier** (`TrialReadinessService` — fairness lives in build weighting). Added: **Gate Keys** — 2–3 concrete named proofs per gate drawn from that trial's pinned standards, **auto-cleared from training history** (PrereqClearer pattern; new `.gateKey` requirement kind; no separate test sessions). Examples (full table = balance checkpoint): Forge keys "3 strict pull-ups, one set" + "hinge 1.25×bw for 5"; Ascent keys "10 pull-ups, one set" + "60s unbroken hold"; Seals key "every attribute at Master floor." Keys render as seal fragments on the sealed NextGateCard — eligibility is a visible quest log.

## 8. The Crossing — rank-up cinematic

Replaces the static RankUpCinematic. Beats: **the hush** (black, one breath) → **the walk** (4–6s Seedance i2v: camera pushes through the threshold into the world; end-frame matched to the rank banner composition) → **the arrival** (settles onto the banner framing, holds as ambient loop — every banner in the app becomes the last frame of your crossing) → **the investiture** (rank sigil burns in — animated badge, particles; title types on: "FORGED." / "You live here now.") → **the spoils** (banner cosmetic unlock chip, stamped gate card flies to records, share).
Tiering: gates I–IV short (~7s); V–VII full (~15s); **VIII: 3s flashback montage of all eight stamped gate cards, then the gold flood.** Scored haptics + per-world audio stinger. Replayable from records. Fallbacks: Ken Burns + particles on the still (missing assets, reduced-motion).

## 9. Art & motion pipeline

**Per-gate kit (×8):** threshold still (Higgsfield image gen, existing banners as style refs; vertical-safe composition; sealed state = in-app treatment) · ambient loop (3–5s Seedance i2v, HEVC ~1–2MB) · Crossing clip (4–6s i2v, end-frame matched to banner, ~2–3MB).
**Shared kits:** beat-FX pack (ember burst, spark hit, seal shatter, cloud rush, gold flood — rendered on black, screen-blend; minor beats = native SwiftUI particles) · audio (8 world stingers + one-shots: bell, hammer, shatter, card snap) · Gate IV deck art (17 paintings + template number cards).
**Budget & delivery:** ~48MB all-in → bundle light layer (stills + FX + audio + deck ≈ 16MB), stream loops + Crossing clips via CDN/ODR with prefetch when a gate's keys start lighting; animated-still fallback offline. Bundling-vs-CDN = jlin infra call at implementation.
**Workflow per gate:** generate still → jlin curates → i2v loop + crossing → curate → HEVC compress → catalog/CDN. Eyes-on QA pass on every asset before wiring (visual-QA rule). Generation briefs live with the GateWorld configs.

## 10. Technical architecture

**New:** `GateWorlds/` — 8 declarative theme files (names, copy seeds, tint, asset refs, overlay coordinates, key definitions; ~200 lines each). Shared views: `NextGateCard`, `GateHallView`, `GateEntryCeremony`, `GateActiveView` (header + calm surface), `GateBeatOverlay`, `GateVerdictView`, `TheCrossingView`, `GateCardView`, `TrialRecordsShelf`. Eight thin `GateVisualizer` plugins (lanterns / bell / strikes / deck / ascent / seals / siege / landings). Crossing asset manager (prefetch, cache, fallback).
**Engine changes:** `OverallRankTrialDefinitions` rewritten to the new structures; evaluation machinery (stations, requirement lines, runner, progress) reused. New: cadence-window math; heavy-strike floors reading `StrengthStandards` ratios; weakest-attribute resolution at draft time; per-option floors/multipliers on `TrialMovementOption` (pull conversions); `.gateKey` requirement kind + `GateKeys` auto-clear service. `TrialStandards` re-baselined (snapshot tests updated intentionally).
**Deleted in the same change:** all 8 old mode views + ready previews (incl. `TowerTrialAscentView`, `TowerTrialReadyPreview`, deck grid in `WorkoutReadyView+Blocks`), `OverallRankTrialReadinessCard`, old `RankUpCinematic` beats (share card survives restyled). `RankTrialFormat` display names become gate names.
**Migration:** persisted attempts/progress map through `legacyIds` (tolerant-decode pattern in place); no history loss.
**Watch-outs:** huge view bodies → AnyView-wrap heavy children (device metadata trap); all new copy through the xcstrings catalog; HEVC loops behind `AVPlayer` must respect Low Power Mode.

## 11. Copy & brand guardrails

Direct, earned, never negging. No "limiters/weak links/holding you back." No gym-bro jargon in user-facing copy (no EMOM/AMRAP/WOD/metcon/engine — world language: the bell, the strikes, the seals). Failure copy is resolute, not punishing ("The gate holds." / "The gate isn't going anywhere."). Art is anime-JRPG illustration, never photoreal.

## 12. Verification (executed, not just planned)

- Unit: evaluation per new station kind (cadence windows, strike floors vs bw, deck unchanged-regression, weakest-attribute resolution, key auto-clear, pull conversions). `TrialStandardsSnapshotTests` re-baselined deliberately, diff reviewed.
- Full suite green; L10n tests green (xcstrings entries for all new keys).
- Per-gate launch-arg demo harness (`--unbound-open-gate <n>` + existing `RankTrialDemoRecorderView`); **on-sim screenshots of every gate's entry, active, beat, and verdict states — read and checked before claiming done.**
- 3× launch gauntlet; sim build AND `xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` (device-arch gate); `set -o pipefail`, never two xcodebuilds concurrently.
- Asset QA: every generated still/loop/clip eyes-on before wiring.

## 13. Execution model

- Staged checkpoints: jlin signs off per-phase; balance checkpoints (below) resolved before their phase implements.
- **Codex delegation** where possible: isolated worktrees per lane (per CLAUDE.md lane table), explicit-path staging only, mechanical/parallel-safe work (per-gate visualizer plugins, GateWorld configs, asset wiring) → Codex; engine/evaluation/standards changes stay with Claude + jlin checkpoints; every Codex result re-verified (build + test + screenshot) before merge.
- Art generation runs as its own lane (Higgsfield MCP), curated by jlin per gate.

## 14. Open balance checkpoints (proposed defaults; confirm/adjust at phase start)

| # | Item | Proposed default |
|---|---|---|
| 1 | Gate V pull-up floors | Tower 20-row floors → 12 pull-ups (floor 4), 8 (floor 9 blend) |
| 2 | Gate VI POWER seal ratios | Vessel-tier `StrengthStandards` hinge+press, 3 reps each |
| 3 | Gate VI MOBILITY seal | 60s weighted deep-squat hold + 10/side cossack, 6:00 cap |
| 4 | Gate VIII landing floors | `FinalExam` budgets redistributed per §5; full table at phase start |
| 5 | Gate Keys full table (8 gates) | 2–3 keys each from pinned standards; Forge/Ascent/Seals as §7 |
| 6 | Row→pull-up conversion | ×1.5 volume everywhere it applies |
| 7 | No-gym scored loads | hinge backpack ~25% bw (III); carry %s unchanged from standards |
