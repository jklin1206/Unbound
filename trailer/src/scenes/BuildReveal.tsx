import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { KineticText } from "../components/KineticText";
import { ScreenCard } from "../components/ScreenCard";
import { SCENE, THEME } from "../config";

/**
 * 3–6s. The build-preview screen slams in under a single line —
 * "Pick your physique." Opens on a white flash carried from the hook.
 */
export const BuildReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const flashOut = interpolate(frame, [0, 8], [1, 0], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: THEME.bg }}>
      <ScreenCard src="screens/04-build-preview.png" duration={SCENE.build} />

      <AbsoluteFill
        style={{ justifyContent: "flex-start", alignItems: "center" }}
      >
        <div style={{ marginTop: 150 }}>
          <KineticText delay={10} size={104} color={THEME.text}>
            PICK YOUR <span style={{ color: THEME.accent2 }}>PHYSIQUE</span>
          </KineticText>
        </div>
      </AbsoluteFill>

      <AbsoluteFill
        style={{ backgroundColor: "#FFFFFF", opacity: flashOut }}
      />
    </AbsoluteFill>
  );
};
