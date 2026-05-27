#!/usr/bin/env node
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const assetsRoot = join(repoRoot, "UNBOUND", "Assets.xcassets");
const generatedRoot =
  "/Users/jlin/.codex/generated_images/019e6044-2655-7da2-a86a-520ede89db75";

const sheets = [
  {
    id: "pp_chin-up",
    source: "ig_0f23cad095f3449d016a163a01713c81988d74a4536491b5ac.png"
  },
  {
    id: "pp_strict-chin-up",
    source: "ig_0f23cad095f3449d016a163a9d38608198a5b7f3e54fbb1511.png"
  },
  {
    id: "pp_weighted-chin-up",
    source: "ig_0f23cad095f3449d016a163af4e85c8198a933a709077a5836.png"
  },
  {
    id: "pp_l-sit-chin-up",
    source: "ig_0f23cad095f3449d016a163b4ad56c8198bcba9997ed6f8aad.png"
  },
  {
    id: "pp_heighted-chin-up",
    source: "ig_0f23cad095f3449d016a163b9bdbdc819881042343d5844769.png"
  },
  {
    id: "pp_one-arm-chin-up",
    source: "ig_0f23cad095f3449d016a163bee05c8819899ac8824d19350d3.png"
  }
];

const crops = {
  phase1: "625x625+0+0",
  phase2: "625x625+629+0",
  phase3: "625x625+0+629",
  phase4: "625x625+629+629"
};

function run(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed`);
  }
}

function imagePath(folder, id, filename) {
  return join(assetsRoot, folder, `${id}.imageset`, filename);
}

function ensureParent(path) {
  mkdirSync(dirname(path), { recursive: true });
}

function crop(source, geometry, output, resize) {
  ensureParent(output);
  const args = [source, "-crop", geometry, "+repage"];
  if (resize) args.push("-resize", resize);
  args.push(output);
  run("magick", args);
}

for (const sheet of sheets) {
  const source = join(generatedRoot, sheet.source);
  if (!existsSync(source)) {
    throw new Error(`Missing generated sheet: ${source}`);
  }

  const infoPath = imagePath(
    "SkillInfographics",
    `${sheet.id}_info`,
    `${sheet.id}_info.png`
  );
  ensureParent(infoPath);
  copyFileSync(source, infoPath);

  for (const [phase, geometry] of Object.entries(crops)) {
    const phasePath = imagePath(
      "SkillIcons",
      `${sheet.id}_${phase}`,
      `${sheet.id}_${phase}.png`
    );
    if (!existsSync(dirname(phasePath))) continue;
    crop(source, geometry, phasePath);
  }
}

console.log("Integrated generated UNBOUND chin-up slideshow assets.");
