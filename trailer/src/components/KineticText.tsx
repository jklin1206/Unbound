import React from "react";
import {
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { THEME } from "../config";

/**
 * A single line of bold kinetic text that springs up + fades in.
 * `delay` offsets the entrance; `accent` words can be tinted.
 */
export const KineticText: React.FC<{
  children: React.ReactNode;
  delay?: number;
  size?: number;
  color?: string;
  weight?: number;
}> = ({ children, delay = 0, size = 96, color = THEME.text, weight = 900 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = spring({
    frame: frame - delay,
    fps,
    config: { damping: 14, mass: 0.6 },
  });
  const opacity = interpolate(frame - delay, [0, 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const y = interpolate(enter, [0, 1], [60, 0]);

  return (
    <div
      style={{
        fontFamily: THEME.fontFamily,
        fontWeight: weight,
        fontSize: size,
        lineHeight: 1.05,
        letterSpacing: -2,
        color,
        textAlign: "center",
        opacity,
        transform: `translateY(${y}px)`,
        textShadow: "0 8px 40px rgba(0,0,0,0.6)",
        padding: "0 60px",
      }}
    >
      {children}
    </div>
  );
};
