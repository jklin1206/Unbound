import React from "react";
import { Composition } from "remotion";
import { UnboundTrailer } from "./UnboundTrailer";
import { FPS, HEIGHT, TOTAL_FRAMES, WIDTH } from "./config";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="UnboundTrailer"
      component={UnboundTrailer}
      durationInFrames={TOTAL_FRAMES}
      fps={FPS}
      width={WIDTH}
      height={HEIGHT}
    />
  );
};
