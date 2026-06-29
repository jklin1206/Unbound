# Exercise Art Regeneration Workflow

One command to regenerate an exercise visual and install it where the app actually reads it.
Codifies the pipeline (and the bugs we hit) so future generation is repeatable.

## TL;DR

```bash
python3 scripts/regen_exercise_art.py \
  --name "Seated Leg Curl" --id exercise.leg-curl-seated \
  --movement "Seated on a leg-curl machine, thighs under the lap pad, curling the shins DOWN and back (knee flexion, hamstrings). NOT a leg extension." \
  --rebuild-html
```

Then verify: `python3 scripts/audit_exercise_visual_backgrounds.py` and run `ExerciseVisualCoverageTests`.

## What it does

1. **Builds a style-locked prompt** - anime by default (avatar character lock), or `--style realistic` for the legacy 3D-anatomy look.
2. **Generates on flat chroma green** via `codex exec --image <ref>` (built-in `image_gen`). Output lands in `~/.codex/generated_images/<uuid>/`.
3. **Chroma-keys** the green to transparent via `scripts/chromakey_generated_assets.py` (teal rim light survives).
4. **Frame-fill crops** to the alpha bbox + ~6% margin (matches the shipped set; non-square is fine).
5. **Installs to every existing asset-slug variant** for the movement (see the slug trap below), or creates a fresh `.imageset` if none exists.

The shipped/active set is **root** `exercise_visual_exercise_<slug>` (transparent). Jot is suppressed; legacy is the realistic set. See [[exercise-art-set-and-regen-pipeline]].

## The two hard-won lessons baked in

### 1. The slug-mismatch trap (why "the explosive pull-up never changed")

A skill node resolves its art through `SkillTraditionalVisualResolver`, which tries candidate slugs **in order**: the slug of the node **title** first, then the node id tail, then tier-criterion exercise names - and uses whichever asset **exists**.

`pp.explosive-pullup` has title "Explosive Pull-Up" -> slug `explosive-pull-up` (hyphenated), which existed as old art and won. Regens written to the id-tail slug `explosive-pullup` (no hyphen) were never read.

**The script defends against this by installing to *all* existing slug variants** (display-name slug, id-tail slug, raw-id slug) across the `exercise`/`mobility`/`carry` prefixes. Whichever one the resolver picks, it gets the new art. After a batch, sanity-check by extracting the embedded thumbnail from `docs/movement-library.html` and comparing - or just trust the multi-slug install.

### 2. Hard poses need a reference, not just words

The model resists some poses (e.g. a compact tuck handstand - it kept kicking the legs up). Two fixes that worked:
- **Pose reference:** pass `--pose-ref <image>` (a clean photo or line-art of the exact pose). The prompt then says "copy this exact pose, render as the UNBOUND character." This cracked the tuck handstand (a GymnasticBodies line-art) and the lateral raise (the legacy asset as the pose source).
- **Explicit biomechanics in `--movement`:** name the joint actions ("knee FLEXION, shins move down/back", "hips bent ~90 deg, thighs fold forward"), and what it is NOT ("not a leg extension", "not kicked up").

## Flags

| Flag | Meaning |
|---|---|
| `--name` | Display name (required). Drives the primary slug. |
| `--id` | Movement/skill id (e.g. `exercise.leg-curl-seated`, `hs.tuck-handstand`). Adds id-tail slug variants for the multi-install. **Pass it** for skill nodes. |
| `--movement` | Explicit pose/movement description. Strongly recommended. |
| `--pose-ref <img>` | Reference image of the exact pose; copies the pose, renders the UNBOUND character. For hard poses. |
| `--ref <img>` | Character reference (default: the UNBOUND avatar). |
| `--style anime\|realistic` | Anime (default) or realistic legacy-set look. |
| `--reuse <green.png>` | Skip codex; re-key/crop/install an existing flat-green render. |
| `--preview` | Stage only (writes a `/tmp/PREVIEW_*.png`), do not touch `Assets.xcassets`. |
| `--rebuild-html` | Regenerate `docs/movement-library.html` after install. |

## Reviewing in the HTML

`docs/movement-library.html` embeds base64 thumbnails, so opening it via `file://` can show a **cached** copy. Either hard-refresh (Cmd+Shift+R) or serve it cache-busted:

```bash
python3 -m http.server 8000 --directory docs   # then http://localhost:8000/movement-library.html
```

## Verify after a batch

```bash
python3 scripts/audit_exercise_visual_backgrounds.py    # every regen must be transparent
xcodebuild test -project UNBOUND.xcodeproj -scheme UNBOUND \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:UNBOUNDTests/ExerciseVisualCoverageTests CODE_SIGNING_ALLOWED=NO
```

`ExerciseVisualCoverageTests` only checks that names resolve and load, so replacing PNG content can't break it - but it catches a missing/orphaned slug. (The pre-existing `testProgressionVariantVisualsAreNotExactDuplicateAssets` failure is unrelated - byte-identical aliased variant art.)
