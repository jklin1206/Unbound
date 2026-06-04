# Green-Screen Asset Regeneration

UNBOUND movement assets should be regenerated through one consistent path:

1. Use the legacy or Jot image as the pose/reference source.
2. Regenerate in the current UNBOUND movement style.
3. Force a flat chroma-green background.
4. Convert the green background to alpha.
5. Install only the transparent result into the target asset catalog imageset.

## Generation Prompt Standard

Use this structure for single exercise visuals:

```text
Regenerate this UNBOUND exercise visual in the current UNBOUND movement style.
Use the reference image only for pose, apparatus, and camera angle.

Style lock: anime/webtoon male-presenting athlete, sharp messy black hair, lean calisthenics build, low-detail face, black sleeveless training top, black pants, black shoes, wrist wraps, cyan/teal rim light, subtle teal motion trails. No purple accents.

Subject: [EXERCISE NAME].
Camera and pose: match the reference image as closely as possible.
Output: one centered full-body exercise figure, 1024x1024 PNG.
Background: perfectly flat chroma green #00FF00 only. No shadows, gradients, texture, text, logos, UI, decorative symbols, or scenery on the background.
Keep the athlete and apparatus fully inside the frame with clean readable silhouette.
```

For four-panel form slides, keep the same UNBOUND style lock and require:

```text
Background in every panel: perfectly flat chroma green #00FF00 only.
No dark panel backgrounds, no white background, no transparent background, no gradients.
```

## Why Green First

Generated transparent backgrounds are inconsistent. A strict green background makes the pipeline deterministic: the generator handles style and pose, then the local script handles alpha.

Because the UNBOUND style uses cyan/teal rim lighting, the key color must stay pure green. Do not use green accents in the character, arrows, equipment, or motion trails.

## Install Transparent Outputs

Name generated PNGs after their final asset names:

```text
exercise_visual_exercise_pushup.png
exercise_visual_exercise_chin-up.png
pp_pullup_phase1.png
```

Preview the key before installing:

```bash
python3 scripts/chromakey_generated_assets.py /path/to/generated/pngs --size 1024
```

Install into the matching `.imageset` directories:

```bash
python3 scripts/chromakey_generated_assets.py /path/to/generated/pngs --install --size 1024
```

The script preserves cyan/teal rim light by targeting saturated green only. If a generated image has green spill around the character, increase `--feather`; if it removes too much detail, lower `--tolerance`.

## Batch Order

Use small batches instead of regenerating everything at once:

1. Exercise visuals used by the routine player and program views.
2. Skill-tree visuals that still fall back to legacy/Jot.
3. Form slideshow phase panels.
4. Cardio, carry, and mobility visuals.

After each batch:

```bash
python3 scripts/audit_exercise_visual_backgrounds.py
xcodebuild -quiet -project UNBOUND.xcodeproj -scheme UNBOUND -destination 'generic/platform=iOS Simulator' -derivedDataPath .derivedData-asset-check CODE_SIGNING_ALLOWED=NO build
```
