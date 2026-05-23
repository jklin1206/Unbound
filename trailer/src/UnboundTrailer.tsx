import React from "react";
import { AbsoluteFill, Audio, Series, staticFile } from "remotion";
import { Hook } from "./scenes/Hook";
import { BuildReveal } from "./scenes/BuildReveal";
import { Montage } from "./scenes/Montage";
import { CTA } from "./scenes/CTA";
import { AUDIO_SRC, HAS_AUDIO_TRACK, SCENE, THEME } from "./config";

/**
 * The full ~20s UNBOUND launch trailer: Hook → BuildReveal → Montage → CTA.
 * Drop a track at public/audio/track.mp3 and flip HAS_AUDIO_TRACK in
 * config.ts to render with audio.
 */
export const UnboundTrailer: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: THEME.bg }}>
      {HAS_AUDIO_TRACK ? <Audio src={staticFile(AUDIO_SRC)} /> : null}

      <Series>
        <Series.Sequence durationInFrames={SCENE.hook}>
          <Hook />
        </Series.Sequence>
        <Series.Sequence durationInFrames={SCENE.build}>
          <BuildReveal />
        </Series.Sequence>
        <Series.Sequence durationInFrames={SCENE.montage}>
          <Montage />
        </Series.Sequence>
        <Series.Sequence durationInFrames={SCENE.cta}>
          <CTA />
        </Series.Sequence>
      </Series>
    </AbsoluteFill>
  );
};
