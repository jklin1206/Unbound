# UNBOUND Onboarding Generated Image Prompts

Use these prompts with `chatgpt-image-latest` (or pinned `gpt-image-1.5`) and export PNGs.

## Asset Contract

Add outputs to your app asset catalog with these exact names:

1. `onboarding_results_snapshot_hero`
2. `onboarding_plan_ready_hero`

The onboarding screens already look for these assets and gracefully fall back if missing.

## Global Style Rules

- Anime-inspired mobile game art direction, not photoreal.
- Dark background friendly: image should read on near-black UI.
- Strong silhouette clarity at small sizes.
- High contrast, simple composition, no text baked into image.
- Keep edges clean for rounded-rectangle crop.
- No logos, no watermarks, no UI chrome mockup.

## Prompt 1 — Results Snapshot Hero

```
Anime-inspired male fitness character in a neutral front pose, standing upright, body assessment vibe, subtle glowing contour lines indicating muscle zones, dark premium background with violet and ember accents, confident but early-stage physique, clean mobile game illustration style, high contrast, centered composition, no text, no watermark, no logo
```

Recommended settings:

- Aspect ratio: `3:5` (portrait)
- Output: PNG

## Prompt 2 — Plan Ready Hero

```
Anime-inspired fitness protocol reveal artwork, character in dynamic ready stance with holographic training rings and subtle tactical overlays around the body, premium dark background, violet energy highlights and warm ember secondary glow, mobile game onboarding style, polished and compact composition, high contrast, no text, no watermark, no logo
```

Recommended settings:

- Aspect ratio: `16:9` (landscape) or `3:2`
- Output: PNG

## Optional Negative Prompt Add-on

```
photorealistic skin texture, cinematic movie still, noisy background, tiny unreadable details, text overlays, logos, watermark, low contrast
```

