# UNBOUND Trailer (Remotion)

A ~20s vertical (1080×1920) social launch trailer for the UNBOUND app.
Angle: **"Train like your favorite character."**

## Run

```bash
cd trailer
npm install
npm start        # Remotion Studio — preview & scrub
npm run build    # renders out/unbound-trailer.mp4
```

## Structure

`Hook → BuildReveal → Montage → CTA`, assembled in `src/UnboundTrailer.tsx`.
All timing + content lives in `src/config.ts`.

## Adding the music track

1. Drop the file at `public/audio/track.mp3`.
2. In `src/config.ts`, set `HAS_AUDIO_TRACK = true`.
3. Re-align the montage cuts to the beat by editing `SCENE.montage` /
   `MONTAGE_CUTS` (cut length is derived from them).

Until then it renders silently.

## Assets

`public/screens/` — onboarding screenshots. `public/art/` — skill icons
and rank art. Copied from the repo; swap freely.
