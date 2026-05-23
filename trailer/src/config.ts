/**
 * Central timing + content config for the UNBOUND trailer.
 * All durations are in frames at FPS. Tweak BEAT_FRAMES + cut lengths
 * here once the real music track is dropped in.
 */

export const FPS = 30;
export const WIDTH = 1080;
export const HEIGHT = 1920;

// ---- Scene durations (frames) -------------------------------------------
export const SCENE = {
  hook: 90, // 0–3s
  build: 90, // 3–6s
  montage: 300, // 6–16s
  cta: 120, // 16–20s
} as const;

export const TOTAL_FRAMES =
  SCENE.hook + SCENE.build + SCENE.montage + SCENE.cta; // 600

// ---- Theme --------------------------------------------------------------
export const THEME = {
  bg: "#0B0710",
  accent: "#A855F7",
  accent2: "#E0218A",
  text: "#F5F0FF",
  fontFamily:
    '"Helvetica Neue", "Arial Black", system-ui, -apple-system, sans-serif',
};

// ---- Montage cuts -------------------------------------------------------
// type "screen": a phone-framed screenshot. type "icons": animated skill grid.
export type MontageCut =
  | { type: "screen"; src: string; label: string }
  | { type: "icons"; label: string };

export const MONTAGE_CUTS: MontageCut[] = [
  { type: "screen", src: "screens/03-rank-orbit.png", label: "RANK UP" },
  { type: "screen", src: "screens/21-build-seed.png", label: "PICK YOUR BUILD" },
  { type: "icons", label: "UNLOCK SKILLS" },
  { type: "screen", src: "screens/30-chapter-scan.png", label: "SCAN YOUR BODY" },
  {
    type: "screen",
    src: "screens/05-chapter-mapping.png",
    label: "FOLLOW THE PATH",
  },
  {
    type: "screen",
    src: "screens/23-entry-map.png",
    label: "EVERY SESSION COUNTS",
  },
];

// Frames within the montage where a cut/beat lands. Evenly spaced for the
// placeholder track — re-align to real beats later.
export const CUT_LENGTH = Math.floor(SCENE.montage / MONTAGE_CUTS.length); // 50

// Skill icons shown in the "UNLOCK SKILLS" grid scene.
export const SKILL_ICONS = [
  "art/icons/cal.5-dips.transparent.png",
  "art/icons/cal.archer-pushup.transparent.png",
  "art/icons/cal.bench-dip.transparent.png",
  "art/icons/cal.bent-arm-press.transparent.png",
  "art/icons/cal.clapping-handstand-pushup.transparent.png",
  "art/icons/cal.clapping-pushup.transparent.png",
  "art/icons/cal.decline-pushup.transparent.png",
  "art/icons/cal.diamond-pushup.transparent.png",
  "art/icons/cal.elevated-pike-pushup.transparent.png",
];

// ---- Audio --------------------------------------------------------------
// Drop the real track at trailer/public/audio/track.mp3 and set this true.
export const HAS_AUDIO_TRACK = false;
export const AUDIO_SRC = "audio/track.mp3";
