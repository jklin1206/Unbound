import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { KineticText } from "../components/KineticText";
import { THEME } from "../config";

/**
 * 16–20s outro. UNBOUND wordmark reveal, tagline, and a download CTA.
 */
export const CTA: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const mark = spring({ frame, fps, config: { damping: 13, mass: 0.7 } });
  const markScale = interpolate(mark, [0, 1], [0.6, 1]);
  const glow = interpolate(frame % 60, [0, 30, 60], [0.35, 0.7, 0.35]);

  const pill = spring({
    frame: frame - 46,
    fps,
    config: { damping: 14 },
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: THEME.bg,
        justifyContent: "center",
        alignItems: "center",
        gap: 40,
      }}
    >
      <div
        style={{
          fontFamily: THEME.fontFamily,
          fontWeight: 900,
          fontSize: 146,
          letterSpacing: 8,
          color: THEME.text,
          transform: `scale(${markScale})`,
          textShadow: `0 0 ${60 * glow}px rgba(168,85,247,${glow})`,
        }}
      >
        UNBOUND
      </div>

      <KineticText delay={24} size={56} weight={600} color="#B9A8D6">
        Train like your favorite character.
      </KineticText>

      <div
        style={{
          marginTop: 30,
          transform: `scale(${pill})`,
          opacity: pill,
          padding: "30px 70px",
          borderRadius: 999,
          background: `linear-gradient(120deg, ${THEME.accent}, ${THEME.accent2})`,
          fontFamily: THEME.fontFamily,
          fontWeight: 900,
          fontSize: 58,
          color: "#FFFFFF",
          boxShadow: "0 20px 70px rgba(168,85,247,0.55)",
        }}
      >
        DOWNLOAD ON THE APP STORE
      </div>
    </AbsoluteFill>
  );
};
