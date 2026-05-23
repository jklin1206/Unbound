import React from "react";
import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
} from "remotion";
import { KineticText } from "../components/KineticText";
import { THEME } from "../config";

/**
 * 0–3s opening hook. Black screen, staged kinetic lines, then a hard
 * white impact-frame flash on the last word to slam into the app.
 */
export const Hook: React.FC = () => {
  const frame = useCurrentFrame();

  // anime impact-frame flash near the end of the scene
  const flash = interpolate(frame, [74, 80, 90], [0, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: THEME.bg,
        justifyContent: "center",
        alignItems: "center",
        gap: 18,
      }}
    >
      <KineticText delay={4} size={66} weight={700} color="#B9A8D6">
        WHAT IF YOU COULD
      </KineticText>
      <KineticText delay={20} size={132} color={THEME.accent}>
        TRAIN LIKE
      </KineticText>
      <KineticText delay={40} size={72} weight={800}>
        your favorite character?
      </KineticText>

      <AbsoluteFill
        style={{ backgroundColor: "#FFFFFF", opacity: flash }}
      />
    </AbsoluteFill>
  );
};
