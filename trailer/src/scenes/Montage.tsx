import React from "react";
import {
  AbsoluteFill,
  interpolate,
  Series,
  useCurrentFrame,
} from "remotion";
import { IconGrid } from "../components/IconGrid";
import { KineticText } from "../components/KineticText";
import { ScreenCard } from "../components/ScreenCard";
import { CUT_LENGTH, MONTAGE_CUTS, THEME } from "../config";

/** Bottom-anchored caption bar for a montage cut. */
const CutLabel: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const exit = interpolate(frame, [CUT_LENGTH - 8, CUT_LENGTH], [1, 0], {
    extrapolateLeft: "clamp",
  });
  return (
    <AbsoluteFill
      style={{ justifyContent: "flex-end", alignItems: "center", opacity: exit }}
    >
      <div
        style={{
          marginBottom: 220,
          padding: "20px 44px",
          borderRadius: 999,
          background: "rgba(11,7,16,0.82)",
          border: `2px solid ${THEME.accent}`,
        }}
      >
        <KineticText delay={4} size={62} weight={900}>
          {text}
        </KineticText>
      </div>
    </AbsoluteFill>
  );
};

/**
 * 6–16s. Beat-synced cuts through the app, each ~CUT_LENGTH frames.
 * Cuts are driven by MONTAGE_CUTS in config.ts.
 */
export const Montage: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: THEME.bg }}>
      <Series>
        {MONTAGE_CUTS.map((cut, i) => (
          <Series.Sequence
            key={i}
            durationInFrames={CUT_LENGTH}
            layout="none"
          >
            <AbsoluteFill>
              {cut.type === "screen" ? (
                <ScreenCard src={cut.src} duration={CUT_LENGTH} />
              ) : (
                <IconGrid />
              )}
              <CutLabel text={cut.label} />
            </AbsoluteFill>
          </Series.Sequence>
        ))}
      </Series>
    </AbsoluteFill>
  );
};
