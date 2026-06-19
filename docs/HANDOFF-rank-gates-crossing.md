# Agent Handoff — The Crossing + Art Lane (Plan 3 of 4)

Branch: `claude/rank-gates-engine` (continues engine[P1]+spine[P2]; Plan-3 commits `b2cd4f45..HEAD`)
Worktree: `/Users/jlin/Documents/toji/UNBOUND-agent-a`
Lane: A (sim iPhone 17, DerivedData `/private/tmp/unbound-dd-a`)

## Summary
*The Crossing* — the rank-up cinematic for an overall-rank gate (spec §8) — plus its asset resolver and
the jlin-curated art-generation lane. **Build-alongside** (jlin's standing call from Plan 2): the Crossing
is reachable only through the demo harness + the verdict's minted-card tap; the live cutover (presenting on
a real gate pass, replacing `RankUpCinematic` for overall ranks) and the video-clip wiring are Plan 4.

It runs **today on the existing rank banners** + a Ken Burns push-in + native rank-tinted particles — which
is also the spec's own reduced-motion/offline fallback, so it is fully functional with **zero generated
assets**. When jlin's art lane drops `gate_threshold_<token>` imagesets, the resolver prefers them
automatically (no code change).

**Every design passed the Color Design Check** (jlin's Plan-3 requirement; `memory/every-design-color-checked.md`):
all color routes through `RankTier.rewardTint`/`rewardTextTint`/`rewardGlowColors` — zero ad-hoc hex —
and was screenshot-verified per world.

9 commits (`b2cd4f45..HEAD`):
- 1 plan doc.
- 5 code (unit-tested where logic): `CrossingTier`; `GateCrossing`+`GateCrossingCatalog` (8 gates);
  `CrossingAssetResolver` (rank-banner fallback); `CrossingParticles` (native, reduced-motion safe);
  `TheCrossingView` (5-beat cinematic) + `GateWorldCatalog.allOrdered`.
- 1 demo harness (`crossing` stage + `-rankCrossingDemo`/`UNBOUND_OPEN_CROSSING` + verdict→Crossing hook).
- 2 docs (art lane + this handoff).

## What shipped (all under `UNBOUND/Views/Gates/Crossing/`)
- `CrossingTier.swift` — cadence: `short` (gates I–IV, ~7s) / `full` (V–VII, ~15s) / `finale` (VIII,
  8-card flashback montage → gold flood). Beat-duration tuples.
- `GateCrossing.swift` + `GateCrossingCatalog.swift` — per-gate config wrapping the Plan-2 `GateWorld`
  (single source for numeral/tint/banner/destination rank), adding the brand-safe dwell line + tier.
  `investitureTitle` ("FORGED.") and all color derive from the destination rank.
- `CrossingAssetResolver.swift` — resolves the best-available threshold still: bespoke
  `gate_threshold_<token>` if present, else `profile_banner_<token>`; `hasBespokeArt` flag. Video clips
  are a documented Plan-4 seam.
- `CrossingParticles.swift` — `TimelineView`/`Canvas` particle layer, tinted by the rank token; reduced-
  motion renders a single static radial glow.
- `TheCrossingView.swift` — the 5 beats: **hush** → **walk** (Ken Burns push-in on the still; finale =
  the 8-card montage) → **arrival** (dwell line) → **investiture** (rank sigil + particles, title
  springs in) → **spoils** (banner-unlock chip + minted `GateCardView` reused from Plan 2 + replay +
  share). Replayable; reduced-motion = crossfades + static glow, no Ken Burns.
- Demo: `GateExperienceDemoView` gains a `crossing` stage and wires `GateVerdictView.onMintedCardTapped`
  → full-screen `TheCrossingView`. `UNBOUND_OPEN_CROSSING=<1-8>` launches straight into the Crossing.

## Verification done
- Unit: `GateCrossingCatalogTests` (4: coverage, tier ladder, investiture title, brand-safe copy),
  `CrossingAssetResolverTests` (2: rank-banner fallback for all 8 + token naming) — 6/6 green.
- Sim build green (iPhone 17); **device-arch build green** (`generic/platform=iOS CODE_SIGNING_ALLOWED=NO`)
  — no metadata cliff on `TheCrossingView`, no type-check timeout (no AnyView wrap needed).
- Full suite: **1227 tests, 18 failures = the 3 pre-existing groups** (16 asset-PNG dupes in
  MovementResolverTests, 1 weight-rounding in ProgramAwareLoggingTests, 1 band-swap in
  DailyWorkoutResolverTests) — all in files Plan 3 never touched. **Zero new regressions.**
- On-sim screenshots, read + Color-Design-Checked: Crossing investiture **and** spoils across Gate I
  (Novice indigo), III (Forged ember), VI (Vessel violet), VIII (Unbound gold) + the finale montage
  mid-flash. Per-gate banner, rank tint on numeral/chip/stamp, investiture title = rank name, minted
  card stamped + defining number + date, no clipping.
- Scope: only `Views/Gates/Crossing/*`, `Views/Gates/GateExperienceDemoView.swift`,
  `Views/Gates/GateWorlds/GateWorldCatalog.swift`, `App/UnboundApp.swift`, `UNBOUNDTests/Views/Gates/Crossing/*`,
  2 docs + plan. Engine + Plan-2 spine untouched. Brand sweep clean. All files <225 lines.

## The art lane (ready, not run) — `docs/rank-gates-art-lane.md`
Stills via **Codex `image_gen`** (zero credits, `gen_thresholds.sh` mirrors `.banner-gen/gen_tiers.sh`,
portrait/vertical-safe, style-locked to the rank banners, spec §3 palette per gate). i2v loops/clips via
**Higgsfield/Seedance** (credits, jlin-curated, Plan-4 wiring). Every asset passes the Color Design Check
before wiring. **Claude did not run this lane** (spend + curation = jlin's call); the resolver auto-picks
up curated stills the moment they land.

## Deferred to Plan 4 (by design, not gaps)
- **Live cutover:** present `TheCrossingView` on a real overall-rank gate pass (a `.gateCrossed` path /
  the verdict's real minted-card tap), replacing the `RankUpCinematic` overall-rank beats; delete the old
  beats then.
- **Video-clip seam:** add a `.clip(URL)` case to `CrossingAssetResolver` + a `CrossingClipLayer`
  (AVPlayer, gated off reduce-motion / Low Power Mode) once `gate_crossing_<token>` clips exist.
- **L10n catalog wrapping** of the Crossing copy (literals are LocalizationTests-green today, exactly like
  Plan 2; wrap at cutover).
- 8 bespoke `GateVisualizer` plugins (Plan-2 deferral) remain Plan 4.

## Risks / notes
- The demo's bottom control bar occludes the Crossing's share/replay row in screenshots (demo-only; the
  product Crossing has no overlay) — same artifact Plan 2 noted for the BEGIN bar.
- `TheCrossingView` uses `Color.black`/`.clear` for the cinematic letterbox — true-black is the design-
  system background; all *content* color is rank-token-derived (Color Design Check clean).
- To run locally: `cd UNBOUND-agent-a && xcodegen generate`, build to iPhone 17, then
  `SIMCTL_CHILD_UNBOUND_OPEN_CROSSING=3 xcrun simctl launch booted com.unboundapp.ios` (gate 3 = Forged).
