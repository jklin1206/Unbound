# UNBOUND Social Launch Trailer — Design

**Date:** 2026-05-22
**Status:** Approved

## Goal

A ~20s vertical (1080×1920) social launch trailer for the UNBOUND iOS app,
built with Remotion. Angle: **"Train like your favorite character"** —
anime-physique, identity-driven, anime×gym crossover energy.

## Constraints

- Built entirely from existing repo PNG assets (no new screen recordings).
- Renders with a music track + beat-synced cuts.
- Self-contained: lives in `trailer/`, does not touch the Swift app.

## Tech

- Remotion v4, 1080×1920 @ 30fps, ~600 frames. Output H.264 MP4.
- New `trailer/` folder: own `package.json`, `node_modules`, `public/`.
- `npm start` → Remotion Studio preview; `npm run build` → `out/unbound-trailer.mp4`.

## Structure (`<Series>`, timings centralized in `config.ts`)

| Beat | Time | Content |
|---|---|---|
| Hook | 0–3s | Black → kinetic text: "What if you could train like your favorite character?" with anime impact-frame flash. |
| Build reveal | 3–6s | `04-build-preview.png` / `21-build-seed.png` slam in — "Pick your physique." |
| Feature montage | 6–16s | ~6–7 beat-synced cuts: rank orbit (`03`), skill icons, an infographic, rank ladder badges, program/chapter screen. |
| CTA | 16–20s | UNBOUND wordmark reveal + "Train like your favorite character." + Download CTA. |

## Components

- `ScreenCard` — phone-framed screenshot, drop shadow, spring entrance.
- `KineticText` — animated text beats.
- `config.ts` — `BEAT_FRAMES` constants + per-sequence durations, so cuts
  can be re-aligned to the real track.

## Audio

`<Audio>` from `trailer/public/audio/`. Ships with a placeholder track so it
renders immediately; real track + beat frames swapped in afterward.

## Out of scope

- New screen recordings.
- App Store metadata / publishing.
