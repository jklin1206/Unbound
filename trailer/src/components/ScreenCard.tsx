import React from "react";
import {
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

/**
 * A phone-framed app screenshot with a spring entrance and a slow
 * Ken-Burns drift, so static PNGs feel alive.
 */
export const ScreenCard: React.FC<{
  src: string;
  duration: number;
}> = ({ src, duration }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = spring({
    frame,
    fps,
    config: { damping: 16, mass: 0.7 },
  });
  const scale = interpolate(enter, [0, 1], [0.78, 1]);
  // slow drift across the cut
  const drift = interpolate(frame, [0, duration], [0, -34], {
    extrapolateRight: "clamp",
  });
  const zoom = interpolate(frame, [0, duration], [1, 1.08], {
    extrapolateRight: "clamp",
  });
  const exitFade = interpolate(frame, [duration - 8, duration], [1, 0], {
    extrapolateLeft: "clamp",
  });

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        opacity: exitFade,
      }}
    >
      <div
        style={{
          transform: `scale(${scale * zoom}) translateY(${drift}px)`,
          borderRadius: 56,
          overflow: "hidden",
          border: "5px solid rgba(168,85,247,0.55)",
          boxShadow:
            "0 40px 120px rgba(0,0,0,0.7), 0 0 80px rgba(168,85,247,0.35)",
        }}
      >
        <Img
          src={staticFile(src)}
          style={{ width: 760, display: "block" }}
        />
      </div>
    </div>
  );
};
