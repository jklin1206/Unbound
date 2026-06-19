# Rank Gates — Art-Generation Lane (jlin-curated)

The Crossing (Plan 3) ships fully functional on the existing rank banners + Ken Burns + native
particles — that is the spec's own offline/reduced-motion fallback. This doc is the **optional,
jlin-curated** lane that replaces those fallback stills with bespoke per-gate threshold art and,
later, motion. Claude does **not** run this lane autonomously (it spends credits + needs curation per
spec §13); jlin drives it per gate. The asset resolver picks up curated art the moment it lands — no
code change.

## Two pipelines

| Asset | Tool | Cost | Why |
|---|---|---|---|
| Threshold still (×8) | **Codex `image_gen`** (`.banner-gen/gen_tiers.sh` pattern) | zero credits ([[codex-image-gen-pipeline]]) | stills are what the Crossing needs first; Codex does them free |
| Ambient loop + Crossing clip (×8) | **Higgsfield / Seedance i2v** | credits | only video tool; jlin-curated, last |

Generate stills first; wire + screenshot; only then spend i2v credits on the gates that earn it.

## The Color Design Check (mandatory gate on every asset)

Before any generated asset is trimmed into the catalog, eyes-on confirm ([[visual-qa-deck-hero-before-schedule]], [[banner-art-is-anime-jrpg]]):
1. **Dominant accent == the destination rank hex** (table below) — the Crossing's UI tint is that rank's token, so the art must agree or it reads "off."
2. **Anime-JRPG illustration, never photoreal** (original cinematic banners were rejected "too realistic").
3. **Vertical-safe / full-bleed** — the Crossing still is portrait and full-screen, *not* the banner's 16:9-with-left-dead-space composition. Keep the focal threshold centered-upper; keep the lower third quiet for the title stack.
4. **No baked text, letters, numbers, logos, watermark, people, faces, UI.** Pure environment.
5. **Legible negative space** behind where "RANK GATE n" + the rank title + dwell line + minted card sit (center + lower third).

A still that fails the check is regenerated, not wired.

## Per-gate threshold-still briefs (Codex `image_gen`)

One accent color per gate = the destination rank's spec §3 hex. World descriptions are spec §5/§3.
Style-lock each gen to the matching shipped banner so the world stays consistent
(`--image .banner-gen/<rank>_v1.png`, [[codex-image-ref-flag]]). Output `gate_threshold_<token>.png`.

| Gate | Dest rank | token | Accent hex | Threshold subject (the gate *into* the world) |
|---|---|---|---|---|
| I First Light | Novice | `novice` | `#8D94FF` indigo | the dark dojo door opening onto a moonlit night courtyard — striking posts + one lit lantern beyond the threshold |
| II The Count | Apprentice | `apprentice` | `#C79D46` antique gold | the dojo hall entry — a great bronze bell above the doorway, weapon rack + tatami + lantern past it |
| III The Forging | Forged | `forged` | `#F05A28` ember | the mouth of a blacksmith forge — anvil, glowing blade, fire-glow spilling out of the dark |
| IV Deck of Proof | Veteran | `veteran` | `#64C475` jade | moss-covered shrine steps rising into deep forest — a vine-wrapped stone gate, jade emblem |
| V The Ascent | Master | `master` | `#2C90BB` glacial cyan | temple gate at the cloudline at dawn — stairs vanishing up into a sea of clouds |
| VI The Seven Seals | Vessel | `vessel` | `#B27AF4` violet | the violet inner-sanctum doorway — floating ritual circles + a chalice past the threshold |
| VII The Threshold | Ascendant | `ascendant` | `#D861DF` magenta | a colossal magenta portal-spire splitting open — heaven's-gate light breaking through dark vaulted stone |
| VIII The Last Gate | Unbound | `unbound` | `#FFC857` gold | the foot of a golden stairway climbing into a sky temple — gold light flooding down the steps |

Runnable block (mirrors `.banner-gen/gen_tiers.sh`, but **portrait / vertical-safe**). Run from `.banner-gen`:

```zsh
#!/bin/zsh
# gen_thresholds.sh — per-gate Crossing threshold stills. Portrait, full-bleed.
cd "$(dirname "$0")"

COMMON='A premium, dark, atmospheric anime-JRPG illustration of a THRESHOLD / gateway INTO a world —
like the establishing shot before a boss arena in a high-end anime game. Hand-painted anime
illustration, NOT photoreal, NOT a 3D render. Volumetric haze, soft god-rays, restrained.

CRITICAL COMPOSITION (portrait, follow exactly):
- VERTICAL 9:16 portrait, full-bleed. The threshold/gateway is the focal point, centered and
  in the UPPER-MIDDLE of the frame.
- The CENTER and entire LOWER THIRD must be quiet, near-black atmospheric dead space — room for
  overlaid title text and a card. No busy detail low in the frame.
- One accent light color ONLY (specified below); everything else deep near-black.
- Strong vignette to near-black at the edges and bottom.

ABSOLUTELY NO text, letters, numbers, logos, watermark, people, faces, UI, frames or borders.
Pure environment art. Maximum resolution and detail, portrait 9:16 (e.g. 1024x1820 or larger).'

gen () {  # gen <token> <ref-rank-banner> <subject+accent>
  local token="$1"; local ref="$2"; local subject="$3"
  local out="gate_threshold_${token}.png"
  echo "=== $token -> $out ==="
  printf 'Generate a single vertical 9:16 anime-JRPG threshold illustration and save it to the current directory as %s.\n\nSUBJECT: %s\n\n%s' \
    "$out" "$subject" "$COMMON" \
    | codex exec --image "$ref" --sandbox workspace-write --skip-git-repo-check 2>&1 | tail -4
}

gen novice    novice_v1.png    'The dark dojo door opening onto a moonlit night courtyard — striking posts and one lit paper lantern beyond the threshold. Accent: soft indigo-blue #8D94FF only.'
gen apprentice apprentice_v1.png 'A dojo-hall entryway — a great bronze bell hung above the doorway, weapon rack, tatami and a warm lantern past it. Accent: muted antique gold #C79D46 only.'
gen forged    forged_v2.png    'The glowing mouth of a blacksmith forge — anvil, a white-hot blade, fire-glow spilling out of surrounding darkness. Accent: fiery ember red-orange #F05A28 only.'
gen veteran   veteran_v1.png   'Moss-covered ancient shrine steps rising into deep forest — a vine-wrapped stone gateway with a glowing jade emblem. Accent: jade / forest green #64C475 only.'
gen master    master_v1.png    'A temple gate at the cloudline at dawn — stone stairs vanishing upward into a sea of clouds. Accent: glacial cyan #2C90BB only.'
gen vessel    vessel_v1.png    'A violet inner-sanctum doorway — floating glowing ritual circles and a chalice past the threshold, charged haze. Accent: deep violet #B27AF4 only.'
gen ascendant ascendant_v1.png 'A colossal magenta portal-spire splitting open — heaven''s-gate light breaking through dark vaulted stone. Accent: magenta / hot pink #D861DF only.'
gen unbound   unbound_v1.png   'The foot of a radiant golden stairway climbing into a sky temple — gold light flooding down the steps from above. Accent: brilliant gold #FFC857 only.'

echo "=== DONE ==="; ls -la gate_threshold_*.png
```

## Ambient loop + Crossing clip briefs (Higgsfield / Seedance i2v)

Per gate, after the still passes the color check, optionally generate (spec §9):
- **Ambient loop** — 3–5s seamless i2v of the threshold still (drifting embers / haze / lantern flicker), HEVC ~1–2 MB. Lands as `gate_loop_<token>` (Gate Hall ambient layer; Plan 4 wiring).
- **Crossing clip** — 4–6s i2v "walk": the camera pushes *through* the threshold into the world; **end-frame matched to the rank banner composition** so it settles onto the arrival still. HEVC ~2–3 MB. Lands as `gate_crossing_<token>`.

i2v prompt seed: *"Slow cinematic push-in through the gateway into the world beyond; subtle living motion (embers/haze/light); anime illustration style preserved; end on a held wide of the world."* Same color check applies (accent stays the rank hex; no photoreal drift).

## Wire-in

1. Curated still → trim/convert → `UNBOUND/Assets.xcassets/Cosmetics/gate_threshold_<token>.imageset/` (1x/2x/3x or single-scale, match the existing `profile_banner_*` setup).
2. `CrossingAssetResolver.thresholdStill(for:)` auto-prefers `gate_threshold_<token>` over the rank banner — **no code change**; `hasBespokeArt` flips true.
3. Re-run the Crossing screenshots (`UNBOUND_OPEN_CROSSING=<n>`) and re-confirm the Color Design Check on the real composited frame.
4. Video clips (`gate_loop_*`, `gate_crossing_*`) wait for the **Plan-4 AVPlayer seam** (`.clip` case in the resolver + a `CrossingClipLayer`, gated off Low Power Mode / reduce-motion). Bundling-vs-CDN for the heavier clips = jlin infra call (spec §9), deferred.

## Status

- Threshold stills: **not generated** (Crossing runs on the rank-banner fallback today). Ready for jlin to run `gen_thresholds.sh` per gate.
- i2v loops/clips: **not generated**; Plan-4 wiring.
