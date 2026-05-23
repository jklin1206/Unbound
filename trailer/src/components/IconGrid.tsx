import React from "react";
import {
  AbsoluteFill,
  Img,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { SKILL_ICONS, THEME } from "../config";

/**
 * A 3×3 grid of skill icons that pop in on a stagger — the
 * "UNLOCK SKILLS" montage beat, built as motion graphics.
 */
export const IconGrid: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  return (
    <AbsoluteFill
      style={{
        backgroundColor: THEME.bg,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(3, 220px)",
          gap: 36,
        }}
      >
        {SKILL_ICONS.map((src, i) => {
          const pop = spring({
            frame: frame - i * 3,
            fps,
            config: { damping: 12, mass: 0.5 },
          });
          return (
            <div
              key={src}
              style={{
                width: 220,
                height: 220,
                borderRadius: 36,
                background: "rgba(168,85,247,0.12)",
                border: "3px solid rgba(168,85,247,0.45)",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                transform: `scale(${pop})`,
                boxShadow: "0 0 50px rgba(168,85,247,0.25)",
              }}
            >
              <Img
                src={staticFile(src)}
                style={{ width: 170, height: 170, objectFit: "contain" }}
              />
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
