import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const exerciseCatalogPath = path.join(root, "UNBOUND/Models/ExerciseCatalog.swift");
const movementCatalogPath = path.join(root, "UNBOUND/Models/MovementCatalog.swift");
const skillTreeContentPath = path.join(root, "UNBOUND/Models/SkillTreeContent.swift");
const attributesPath = path.join(root, "UNBOUND/Resources/AttributeContributions.json");
const outputPath = path.join(root, "docs/superpowers/handoff/2026-05-20-movement-library-v1-review.html");

const exerciseSource = fs.readFileSync(exerciseCatalogPath, "utf8");
const movementSource = fs.readFileSync(movementCatalogPath, "utf8");
const skillTreeSource = fs.readFileSync(skillTreeContentPath, "utf8");
const attributes = JSON.parse(fs.readFileSync(attributesPath, "utf8")).exercises ?? {};

const slotNames = {
  legsQuad: "Squat / Quad",
  legsPosterior: "Hinge / Posterior",
  pushHorizontal: "Horizontal Push",
  pushVertical: "Vertical Push",
  pullHorizontal: "Horizontal Pull",
  pullVertical: "Vertical Pull",
  arms: "Arms",
  core: "Core",
  calves: "Calves",
};

const muscleNames = {
  legs: "Legs",
  glutes: "Glutes",
  core: "Core",
  back: "Back",
  forearms: "Forearms",
  chest: "Chest",
  shoulders: "Shoulders",
  arms: "Arms",
  lats: "Lats",
  traps: "Traps",
  calves: "Calves",
};

function bodyRegionsFor(exercise) {
  const name = normalized(exercise.name);
  const regions = new Set();
  for (const muscle of exercise.muscles) {
    if (muscle === "Chest") regions.add("Chest");
    if (muscle === "Back") ["Lats", "Traps", "Lower Back"].forEach((item) => regions.add(item));
    if (muscle === "Shoulders") regions.add("Shoulders");
    if (muscle === "Arms") ["Biceps", "Triceps"].forEach((item) => regions.add(item));
    if (muscle === "Forearms") regions.add("Forearms");
    if (muscle === "Legs") ["Quads", "Hamstrings"].forEach((item) => regions.add(item));
    if (muscle === "Glutes") regions.add("Glutes");
    if (muscle === "Core") ["Abs", "Obliques", "Lower Back"].forEach((item) => regions.add(item));
    if (muscle === "Traps") regions.add("Traps");
    if (muscle === "Lats") regions.add("Lats");
    if (muscle === "Calves") regions.add("Calves");
  }

  if (["bench", "chest press", "fly", "pushup", "dip", "pec dec"].some((term) => name.includes(term))) ["Chest", "Triceps", "Shoulders"].forEach((item) => regions.add(item));
  if (["overhead press", "arnold press", "lateral raise", "front raise", "y raise", "handstand", "pike"].some((term) => name.includes(term))) ["Shoulders", "Triceps"].forEach((item) => regions.add(item));
  if (["row", "pullup", "chin up", "pulldown", "pullover", "face pull"].some((term) => name.includes(term))) ["Lats", "Traps", "Biceps", "Forearms"].forEach((item) => regions.add(item));
  if (name.includes("curl")) {
    regions.add("Biceps");
    if (name.includes("hammer") || name.includes("rope")) regions.add("Forearms");
  }
  if (["tricep", "skull", "close grip bench"].some((term) => name.includes(term))) regions.add("Triceps");
  if (["squat", "leg press", "lunge", "step up", "leg extension", "adductor"].some((term) => name.includes(term))) ["Quads", "Glutes"].forEach((item) => regions.add(item));
  if (["deadlift", "rdl", "leg curl", "nordic", "good morning", "glute ham"].some((term) => name.includes(term))) ["Hamstrings", "Glutes", "Lower Back"].forEach((item) => regions.add(item));
  if (["hip thrust", "glute", "abductor", "kickback", "pull through", "kettlebell swing"].some((term) => name.includes(term))) ["Glutes", "Hamstrings"].forEach((item) => regions.add(item));
  if (["plank", "hollow", "l sit", "front lever", "dragon flag", "crunch", "raise", "situp", "ab wheel"].some((term) => name.includes(term))) regions.add("Abs");
  if (["pallof", "rotation", "cossack"].some((term) => name.includes(term))) regions.add("Obliques");
  if (["calf", "tibialis"].some((term) => name.includes(term))) regions.add("Calves");
  return [...regions].sort();
}

const templateNames = {
  barbellStrength: "Free Weight Strength",
  machineStrength: "Machine / Cable Strength",
  bodyweightReps: "Bodyweight Reps",
  weightedBodyweight: "Weighted Bodyweight",
  holdControl: "Hold / Control",
};

const tierNames = [
  "Initiate",
  "Novice",
  "Apprentice",
  "Forged",
  "Veteran",
  "Honed",
  "Vessel",
  "Unbound",
  "Ascendant",
];

const standardLadderPolicies = {
  barbellStrength: {
    label: "Free Weight Strength",
    values: zipStandards(
      [0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00, 2.25],
      [5, 5, 5, 5, 3, 3, 2, 1, 1],
      (ratio, reps) => `${formatRatio(ratio)}x BW x ${reps}`
    ),
  },
  machineStrength: {
    label: "Machine / Cable Strength",
    values: zipStandards(
      [0.30, 0.45, 0.60, 0.80, 1.00, 1.20, 1.45, 1.70, 2.00],
      [10, 10, 8, 8, 6, 6, 5, 3, 3],
      (ratio, reps) => `${formatRatio(ratio)}x BW x ${reps}`
    ),
  },
  bodyweightReps: {
    label: "Bodyweight Reps",
    values: [1, 3, 6, 10, 15, 20, 25, 30, 40].map((value) => `${value} clean ${value === 1 ? "rep" : "reps"}`),
  },
  weightedBodyweight: {
    label: "Weighted Bodyweight",
    values: zipStandards(
      [0.05, 0.10, 0.15, 0.25, 0.35, 0.50, 0.75, 1.00, 1.25],
      [5, 5, 5, 5, 3, 3, 2, 1, 1],
      (ratio, reps) => `+${formatRatio(ratio)}x BW x ${reps}`
    ),
  },
  holdControl: {
    label: "Hold / Control",
    values: [10, 20, 30, 45, 60, 75, 90, 120, 180].map((value) => `${value}s clean hold`),
  },
};

const loggerNames = {
  strengthSets: "Strength set logger",
  bodyweightSets: "Bodyweight set logger",
  hold: "Hold timer",
};

function normalized(value) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[–—]/g, "-")
    .split(/[^a-z0-9]+/g)
    .filter(Boolean)
    .join(" ");
}

function slug(value) {
  return normalized(value).replaceAll(" ", "-");
}

function titleCase(value) {
  return value.replace(/\b[a-z]/g, (match) => match.toUpperCase());
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function zipStandards(values, reps, render) {
  return values.map((value, index) => render(value, reps[index]));
}

function formatRatio(value) {
  return value.toFixed(2).replace(/\.?0+$/, "");
}

function parseVariantMap() {
  const match = movementSource.match(/private static let variantRankStandardNames: \[String: String\] = \[([\s\S]*?)\n    \]/);
  if (!match) return {};
  return Object.fromEntries(
    [...match[1].matchAll(/"([^"]+)":\s*"([^"]+)"/g)].map((entry) => [entry[1], entry[2]])
  );
}

function parseExercises() {
  const exercises = [];
  let currentSlot = null;

  for (const line of exerciseSource.split("\n")) {
    const slotMatch = line.match(/^\s*\.(\w+): \[/);
    if (slotMatch) {
      currentSlot = slotMatch[1];
      continue;
    }

    const initMatch = line.match(/\.init\((.*)\),?$/);
    if (!initMatch || !currentSlot) continue;

    const args = initMatch[1];
    const name = args.match(/name: "([^"]+)"/)?.[1];
    const displayName = args.match(/displayName: "([^"]+)"/)?.[1];
    if (!name || !displayName) continue;

    const muscles = [...args.matchAll(/\.(legs|glutes|core|back|forearms|chest|shoulders|arms|lats|traps|calves)/g)]
      .map((match) => muscleNames[match[1]] ?? match[1]);
    const defaultSubstitute = args.match(/defaultSubstitute: "([^"]+)"/)?.[1] ?? null;
    const progressionFamily = args.match(/progressionFamily: "([^"]+)"/)?.[1] ?? null;
    const progressionTier = Number(args.match(/progressionTier: (\d+)/)?.[1] ?? NaN);

    exercises.push({
      id: `exercise.${slug(name)}`,
      name,
      displayName,
      slotKey: currentSlot,
      slot: slotNames[currentSlot] ?? currentSlot,
      muscles,
      defaultSubstitute,
      progressionFamily,
      progressionTier: Number.isNaN(progressionTier) ? null : progressionTier,
    });
  }

  return exercises;
}

function parseSkillTargets() {
  const nodes = [];
  for (const match of skillTreeSource.matchAll(/\.simple\(\s*id: "([^"]+)",\s*title: "([^"]+)",([\s\S]*?)(?=\n\s*\),)/g)) {
    const [, id, title, body] = match;
    if (id.startsWith("co.")) continue;
    const cluster = body.match(/cluster: \.(\w+)/)?.[1] ?? "";
    const tier = Number(body.match(/tier: (\d+)/)?.[1] ?? NaN);
    const type = body.match(/type: \.(\w+)/)?.[1] ?? "";
    const target = body
      .match(/target: ([\s\S]*?),\n\s*(?:prereqs|isKeystone|isMythic|equipment|primary|secondary|subtitle|description|formCues|commonMistakes|timeline|glyph|position|rank|levels|subChapter|isParallelToParent|tierCriteria):/)?.[1]
      ?.replace(/\s+/g, " ")
      .trim() ?? "";
    const prereqs = [...body.matchAll(/PrerequisiteGroup\(([^)]*)\)/g)]
      .flatMap((entry) => [...entry[1].matchAll(/"([^"]+)"/g)].map((item) => item[1]));

    nodes.push({
      id,
      movementId: `skill.${id}`,
      title,
      cluster,
      tier: Number.isNaN(tier) ? null : tier,
      type,
      target,
      prereqs,
    });
  }
  return nodes;
}

const variantMap = parseVariantMap();
const exercises = parseExercises();
const skillTargets = parseSkillTargets();
const byId = Object.fromEntries(exercises.map((exercise) => [exercise.id, exercise]));

const bodyweightNames = new Set([
  "incline pushup", "pushup", "diamond pushup", "decline pushup",
  "pseudo planche pushup", "archer pushup", "pike pushup", "wall handstand pushup",
  "negative pullup", "assisted pullup band", "assisted pullup machine",
  "chin up", "pullup", "wide grip pullup", "weighted pullup", "chest to bar pullup",
  "straight bar dip", "dip",
  "banded muscle up", "low bar muscle up transition", "assisted turnover freeze", "muscle up",
  "plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
  "advanced tuck front lever", "dragon flag", "hanging knee raise", "hanging leg raise",
  "captains chair knee raise", "captains chair leg raise", "bodyweight squat",
  "walking lunge", "step up", "cossack squat", "pistol squat", "shrimp squat",
  "nordic curl", "inverted row", "ab wheel", "decline situp", "roman chair situp",
  "hollow rock", "jump squat", "assisted pistol squat", "assisted shrimp squat",
]);

function blockKind(exercise) {
  return bodyweightNames.has(normalized(exercise.name)) ? "bodyweight" : "strength";
}

function equipment(exercise) {
  const name = normalized(`${exercise.displayName} ${exercise.name}`);
  const out = new Set();

  if (name.includes("smith")) out.add("Smith Machine");
  if (
    name.includes("barbell") || name.includes("deadlift") || name.includes("back squat") ||
    name.includes("front squat") || name.includes("safety bar") || name.includes("bench press") || name.includes("overhead press") ||
    name.includes("good morning") || name.includes("hip thrust") || name.includes("landmine") ||
    name.includes("t bar row")
  ) out.add("Barbell");
  if (name.includes("dumbbell") || name.includes("arnold press") || name.includes("goblet") || name.includes("hammer curl") || name.includes("lateral raise") || name.includes("fly")) out.add("Dumbbell");
  if (name.includes("kettlebell")) out.add("Kettlebell");
  if (name.includes("cable") || name.includes("pulldown") || name.includes("pushdown") || name.includes("face pull") || name.includes("pallof")) out.add("Cable");
  if (
    name.includes("machine") || name.includes("plate loaded") || name.includes("hammer strength") ||
    name.includes("converging") || name.includes("leg press") || name.includes("hack squat") ||
    name.includes("pendulum") || name.includes("v squat") || name.includes("pec deck") ||
    name.includes("leg curl") || name.includes("leg extension") || name.includes("reverse hyper") ||
    name.includes("glute ham") || name.includes("captain")
  ) out.add("Machine");
  if (name.includes("pullup") || name.includes("chin up") || name.includes("hanging")) out.add("Pull-Up Bar");
  if (name.includes("dip")) out.add("Dip Station");
  if (name.includes("ring")) out.add("Rings");
  if (name.includes("bench") || name.includes("incline") || name.includes("decline") || name.includes("chest supported")) out.add("Bench");
  if (name.includes("box") || name.includes("step up")) out.add("Box");
  if (name.includes("band")) out.add("Band");

  if (out.size === 0 || blockKind(exercise) === "bodyweight") out.add("Bodyweight");
  return [...out].sort();
}

function rankTemplate(exercise) {
  const name = normalized(exercise.name);
  const display = normalized(exercise.displayName);
  if (display.includes("weighted") || name.includes("weighted")) return "weightedBodyweight";
  if (name === "hollow rock") return "bodyweightReps";
  const holdControlNames = new Set([
    "plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
    "advanced tuck front lever", "dragon flag", "hanging leg raise",
  ]);
  if (display.includes("plank") || display.includes("hang") || display.includes("hold") || display.includes("hollow") || holdControlNames.has(name)) return "holdControl";
  if (blockKind(exercise) === "bodyweight") return "bodyweightReps";
  if (equipment(exercise).some((item) => ["Machine", "Cable", "Smith Machine"].includes(item))) return "machineStrength";
  return "barbellStrength";
}

function difficulty(exercise) {
  if (normalized(exercise.name) === "l sit tucked") return "Beginner";

  if (exercise.progressionTier != null) {
    if (exercise.progressionTier < 2) return "Beginner";
    if (exercise.progressionTier <= 4) return "Intermediate";
    if (exercise.progressionTier <= 6) return "Advanced";
    return "Elite";
  }

  const name = normalized(`${exercise.displayName} ${exercise.name}`);
  if (["one arm", "planche", "nordic", "pistol", "shrimp", "handstand"].some((term) => name.includes(term))) return "Advanced";
  if (["deadlift", "barbell", "front squat", "overhead press", "dip", "pullup"].some((term) => name.includes(term))) return "Intermediate";
  return "Beginner";
}

function skillAssociations(exercise) {
  const name = normalized(exercise.name);
  const skills = new Set();
  const verticalPullSkillNames = new Set([
    "negative pullup", "assisted pullup band", "assisted pullup machine",
    "chin up", "pullup", "wide grip pullup", "weighted pullup", "chest to bar pullup",
    "lat pulldown neutral", "wide grip lat pulldown", "close grip lat pulldown",
    "reverse grip lat pulldown", "lat pulldown", "single arm pulldown",
  ]);
  if (verticalPullSkillNames.has(name)) {
    skills.add("pp.pullup");
    skills.add("pp.strict-pullup");
  }
  if (name === "dip" || name === "straight bar dip") skills.add("pp.muscle-up");
  if (name.includes("pike") || name.includes("handstand") || name.includes("overhead press")) {
    skills.add("hs.wall-handstand-30");
    skills.add("cal.handstand-pushup");
  }
  if (name.includes("pushup") || name.includes("bench") || name.includes("chest press")) skills.add("cal.pushup");
  if (name.includes("pistol") || name.includes("shrimp") || name.includes("split squat") || name.includes("step up")) skills.add("ld.pistol-squat");
  if (name.includes("nordic") || name.includes("leg curl")) skills.add("ld.nordic-curl");
  if (name.includes("plank") || name.includes("hollow") || name.includes("leg raise") || name.includes("knee raise") || name.includes("situp")) skills.add("cl.hollow-body-30");
  return [...skills].sort();
}

function contraindications(exercise) {
  const name = normalized(`${exercise.displayName} ${exercise.name}`);
  const tags = new Set();
  if (["squat", "lunge", "leg press", "step up", "pistol"].some((term) => name.includes(term))) tags.add("knee-sensitive");
  if (["deadlift", "good morning", "row", "back extension"].some((term) => name.includes(term))) tags.add("low-back-sensitive");
  if (["overhead", "dip", "handstand", "upright row", "pullover"].some((term) => name.includes(term))) tags.add("shoulder-sensitive");
  if (["wrist", "pushup", "planche"].some((term) => name.includes(term))) tags.add("wrist-sensitive");
  return [...tags].sort();
}

function attrString(exercise) {
  const dict = attributes[exercise.name] ?? {};
  const entries = Object.entries(dict)
    .filter(([, value]) => value > 0)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([key, value]) => `${titleCase(key)} ${Math.round(value * 100)}%`);
  return entries.join(" / ") || "Needs weights";
}

function loggerMode(exercise) {
  return rankTemplate(exercise) === "holdControl" ? "hold" : (blockKind(exercise) === "bodyweight" ? "bodyweightSets" : "strengthSets");
}

const enriched = exercises.map((exercise) => {
  const variantBaseName = variantMap[normalized(exercise.name)] ?? null;
  const rankStandardMovementId = variantBaseName ? `exercise.${slug(variantBaseName)}` : exercise.id;
  return {
    ...exercise,
    equipment: equipment(exercise),
    rankTemplate: rankTemplate(exercise),
    rankTemplateName: templateNames[rankTemplate(exercise)],
    loggerMode: loggerNames[loggerMode(exercise)],
    difficulty: difficulty(exercise),
    skillAssociations: skillAssociations(exercise),
    contraindications: contraindications(exercise),
    attributeSummary: attrString(exercise),
    bodyRegions: bodyRegionsFor(exercise),
    variantOfMovementId: variantBaseName ? `exercise.${slug(variantBaseName)}` : null,
    rankStandardMovementId,
  };
});

const standards = [...new Set(enriched.map((item) => item.rankStandardMovementId))]
  .map((id) => {
    const base = byId[id] ? enriched.find((item) => item.id === id) : null;
    const members = enriched.filter((item) => item.rankStandardMovementId === id);
    return {
      id,
      base: base ?? members[0],
      variants: members.filter((item) => item.id !== id),
      members,
    };
  })
  .sort((a, b) => a.base.slot.localeCompare(b.base.slot) || a.base.displayName.localeCompare(b.base.displayName));

const countBy = (items, getKey) => {
  const map = new Map();
  for (const item of items) map.set(getKey(item), (map.get(getKey(item)) ?? 0) + 1);
  return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
};

const standardsByTemplate = countBy(standards, (item) => item.base.rankTemplateName);
const loggableByTemplate = countBy(enriched, (item) => item.rankTemplateName);
const standardsBySlot = countBy(standards, (item) => item.base.slot);
const variants = enriched.filter((item) => item.variantOfMovementId);
const standalone = enriched.filter((item) => !item.variantOfMovementId);

const migrationRows = [
  {
    layer: "MovementDefinition",
    finalState: "Single data shape for every trainable thing: gym standard, loggable variant, skill drill, cardio, carry, mobility, routine.",
    current: "Exists in MovementCatalog, wrapping ExerciseCatalog seed data and hand-authored non-gym entries.",
    action: "Keep and expand. This becomes the app contract."
  },
  {
    layer: "MovementCatalog",
    finalState: "The source of truth used by program generation, workout builder, logging, substitutions, AP/ranks, trials, and skill links.",
    current: "New layer with executable metadata, resolver, variant roll-ups, generated skill targets, and cardio/carry/mobility/skill drill definitions.",
    action: "Promote to primary API. Add typed query surfaces: rankStandards, loggableMovements, variants, skillTargets, skillDrills, cardio, carry, mobility."
  },
  {
    layer: "ExerciseCatalog",
    finalState: "No longer a competing canonical library. Either deleted or reduced to a compatibility shim backed by MovementCatalog.",
    current: "Old gym exercise source with names, muscles, substitutions, progression families.",
    action: "Migrate fields into MovementDefinition, then replace callers. Keep only while old program/preferences code depends on it."
  },
  {
    layer: "AttributeContributions",
    finalState: "Movement stat weights are owned by MovementDefinition or a movement metadata resource keyed by movementId.",
    current: "Separate JSON keyed by exercise name.",
    action: "Migrate to movementId keys so variants can inherit or override base stat weights deliberately."
  },
  {
    layer: "Skill Trees",
    finalState: "Skill standards and drills become MovementDefinitions with skillId, rank criteria, prerequisites, and program slots.",
    current: "Every live skill node now has a generated skill-target movement. Supplemental drills remain hand-authored where they are practice variations.",
    action: "Next pass: expand each skill target into dedicated drill/progression movements while keeping unlock proof in TierCriterion."
  },
  {
    layer: "Logs + Completion",
    finalState: "Every completed block stores movementId plus rankStandardMovementId. AP/rank checks use the standard; history preserves the exact variant.",
    current: "MovementResolver now returns rankStandardMovementId, but old logs still use exerciseName paths in places.",
    action: "Migrate new completion pipeline and adapters to carry both IDs."
  }
];

const finalModelRows = [
  ["Identity", "id, displayName, aliases, role"],
  ["Ranking", "rankable, rankTemplate, rankStandardMovementId, variantOfMovementId, AP/rank criteria"],
  ["Logging", "blockKind, loggerMode, defaultMetric"],
  ["Programming", "movementSlot, equipment, substitutionGroup, progressionFamily, progressionTier"],
  ["Rewards", "attributeWeights, skillAssociations"],
  ["Safety", "contraindicationTags"],
  ["Domain Links", "canonicalExerciseName during migration, skillId, cardioType, routine IDs"]
];

const skillUnlockRows = [
  ["Skill tree owns unlocks", "MovementCatalog may link training inputs to a skill, but it must not change prerequisites, rank criteria, or unlock gates."],
  ["Movement links are credit/context", "skillAssociations are for recommendations, session context, and possible AP/support credit. They are not proof of a skill rank by themselves."],
  ["Skill proof stays strict", "Rank unlocks must read the 9-rank SkillTier/TierCriterion data: reps, hold seconds, quality, side, load, or compound criteria."],
  ["Variants roll up only within movement standards", "A lat pulldown variant can roll into Lat Pulldown. It cannot unlock Pull-Up unless the skill criterion explicitly accepts it."],
  ["Skill targets are not AP standards", "Generated skill movements are training/logging targets. They do not own exercise AP ladders; their rank proof remains the skill's TierCriterion table."],
  ["Program resolver obeys gates", "Adding a skill goal can schedule prerequisites and drills, but locked skills remain locked until their skill-tree criteria are proven."]
];

const standardPolicyRows = Object.values(standardLadderPolicies)
  .map((policy) => `<tr><td><strong>${escapeHtml(policy.label)}</strong></td>${policy.values.map((value) => `<td>${escapeHtml(value)}</td>`).join("")}</tr>`)
  .join("");

const standardPolicyTable = `<table><thead><tr><th>Template</th>${tierNames.map((tier) => `<th>${escapeHtml(tier)}</th>`).join("")}</tr></thead><tbody>${standardPolicyRows}</tbody></table>`;

function pill(text, cls = "") {
  return `<span class='pill ${cls}'>${escapeHtml(text)}</span>`;
}

function card(num, label) {
  return `<div class='card'><div class='num'>${escapeHtml(num)}</div><div class='label'>${escapeHtml(label)}</div></div>`;
}

function statGrid(entries) {
  return `<div class='grid'>${entries.map(([label, value]) => card(value, label)).join("")}</div>`;
}

function templateGrid(entries) {
  return `<div class='grid'>${entries.map(([name, count]) => card(count, name)).join("")}</div>`;
}

function standardRow(standard) {
  const base = standard.base;
  const variantNames = standard.variants.map((item) => item.displayName).sort();
  const variantText = variantNames.length ? variantNames.map((name) => pill(name)).join("") : "<span class='small'>None</span>";
  const skills = [...new Set(standard.members.flatMap((item) => item.skillAssociations))];
  const flags = [...new Set(standard.members.flatMap((item) => item.contraindications))];
  const equipmentText = [...new Set(standard.members.flatMap((item) => item.equipment))].sort().map((item) => pill(item)).join("");
  const bodyRegionText = [...new Set(standard.members.flatMap((item) => item.bodyRegions))].sort().map((item) => pill(item)).join("");
  return `<tr>
    <td><strong>${escapeHtml(base.displayName)}</strong><div class='small'>${escapeHtml(base.name)} · ${escapeHtml(standard.id)}</div></td>
    <td>${escapeHtml(base.slot)}</td>
    <td>${escapeHtml(base.rankTemplateName)}<div class='small'>${escapeHtml(base.loggerMode)} · ${escapeHtml(base.difficulty)}</div></td>
    <td>${base.muscles.map((item) => pill(item)).join("")}</td>
    <td>${bodyRegionText}</td>
    <td>${equipmentText}</td>
    <td>${escapeHtml(base.attributeSummary)}</td>
    <td>${variantText}</td>
    <td>${skills.map((item) => pill(item, "good")).join("")}</td>
    <td>${flags.map((item) => pill(item, "warn")).join("")}</td>
  </tr>`;
}

function variantRow(item) {
  const base = enriched.find((candidate) => candidate.id === item.rankStandardMovementId);
  return `<tr>
    <td><strong>${escapeHtml(item.displayName)}</strong><div class='small'>${escapeHtml(item.name)} · ${escapeHtml(item.id)}</div></td>
    <td>${escapeHtml(base?.displayName ?? item.rankStandardMovementId)}</td>
    <td>${escapeHtml(item.slot)}</td>
    <td>${escapeHtml(item.rankTemplateName)}<div class='small'>${escapeHtml(item.loggerMode)}</div></td>
    <td>${item.equipment.map((name) => pill(name)).join("")}</td>
    <td>${item.muscles.map((name) => pill(name)).join("")}</td>
    <td>${escapeHtml(item.defaultSubstitute ?? "")}</td>
  </tr>`;
}

function details(title, inner, open = false) {
  return `<details ${open ? "open" : ""}><summary>${escapeHtml(title)}</summary><div>${inner}</div></details>`;
}

const migrationTable = `<table><thead><tr><th>Layer</th><th>Final State</th><th>Current State</th><th>Migration Action</th></tr></thead><tbody>${migrationRows.map((row) => `<tr><td><strong>${escapeHtml(row.layer)}</strong></td><td>${escapeHtml(row.finalState)}</td><td>${escapeHtml(row.current)}</td><td>${escapeHtml(row.action)}</td></tr>`).join("")}</tbody></table>`;
const finalModelTable = `<table><thead><tr><th>Concern</th><th>MovementDefinition Owns</th></tr></thead><tbody>${finalModelRows.map(([concern, fields]) => `<tr><td><strong>${escapeHtml(concern)}</strong></td><td>${escapeHtml(fields)}</td></tr>`).join("")}</tbody></table>`;
const skillUnlockTable = `<table><thead><tr><th>Policy</th><th>Meaning</th></tr></thead><tbody>${skillUnlockRows.map(([policy, meaning]) => `<tr><td><strong>${escapeHtml(policy)}</strong></td><td>${escapeHtml(meaning)}</td></tr>`).join("")}</tbody></table>`;

const standardGroups = Object.entries(Object.groupBy(standards, (standard) => standard.base.rankTemplateName))
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([template, group]) => details(`${template} · ${group.length} ranked standards`, `<table><thead><tr><th>Ranked Standard</th><th>Slot</th><th>Template</th><th>Targets</th><th>Body Map</th><th>Equipment</th><th>Top Stats</th><th>Loggable Variants</th><th>Skills</th><th>Flags</th></tr></thead><tbody>${group.map(standardRow).join("")}</tbody></table>`, template !== "Free Weight Strength"))
  .join("");

const variantTable = `<table><thead><tr><th>Loggable Variant</th><th>Rolls Into</th><th>Slot</th><th>Logger</th><th>Equipment</th><th>Targets</th><th>Default Sub</th></tr></thead><tbody>${variants.sort((a, b) => (enriched.find((item) => item.id === a.rankStandardMovementId)?.displayName ?? "").localeCompare(enriched.find((item) => item.id === b.rankStandardMovementId)?.displayName ?? "") || a.displayName.localeCompare(b.displayName)).map(variantRow).join("")}</tbody></table>`;

const skillLinkedRows = enriched
  .filter((item) => item.skillAssociations.length)
  .sort((a, b) => a.skillAssociations.join(",").localeCompare(b.skillAssociations.join(",")) || a.displayName.localeCompare(b.displayName))
  .map((item) => `<tr><td><strong>${escapeHtml(item.displayName)}</strong><div class='small'>${escapeHtml(item.name)}</div></td><td>${item.skillAssociations.map((skill) => pill(skill, "good")).join("")}</td><td>${escapeHtml(item.rankStandardMovementId)}</td><td>${escapeHtml(item.rankTemplateName)}</td><td>${escapeHtml(item.slot)}</td></tr>`)
  .join("");

const skillTargetRows = skillTargets
  .sort((a, b) => a.cluster.localeCompare(b.cluster) || (a.tier ?? 0) - (b.tier ?? 0) || a.title.localeCompare(b.title))
  .map((item) => `<tr><td><strong>${escapeHtml(item.title)}</strong><div class='small'>${escapeHtml(item.movementId)}</div></td><td>${pill(item.id, "good")}</td><td>${escapeHtml(item.cluster)}</td><td>${escapeHtml(item.tier ?? "")}</td><td>${escapeHtml(item.type)}</td><td>${escapeHtml(item.target)}</td><td>${item.prereqs.map((id) => pill(id)).join("") || "<span class='small'>Entry</span>"}</td></tr>`)
  .join("");

const html = `<!doctype html>
<html>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width,initial-scale=1'>
  <title>UNBOUND Movement Library v1 Review</title>
  <style>
    :root{color-scheme:dark;--bg:#070a0e;--panel:#101821;--panel2:#0c1219;--ink:#effaff;--muted:#93a9b3;--line:#22313c;--cyan:#39d7e8;--warn:#ffe0a3;--good:#bff8ca}
    body{margin:0;background:var(--bg);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}
    main{max-width:1320px;margin:0 auto;padding:34px 20px 70px}
    h1{font-size:42px;margin:0 0 8px}h2{margin:34px 0 12px;color:#d8f8ff}p{color:var(--muted);line-height:1.5;max-width:980px}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px;margin:20px 0}
    .card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}.num{font-size:30px;font-weight:850;color:var(--cyan)}.label,.small{font-size:12px;color:var(--muted)}
    .note{border:1px solid var(--warn);background:#261f10;color:#fff1bf;border-radius:8px;padding:12px 14px;margin:18px 0;font-size:14px;line-height:1.45}
    .pill{display:inline-block;padding:3px 8px;border:1px solid var(--line);border-radius:999px;margin:2px;background:var(--panel2);font-size:12px}.good{color:var(--good)}.warn{color:var(--warn)}
    details{border:1px solid var(--line);border-radius:8px;margin:12px 0;background:rgba(16,24,33,.6)}summary{cursor:pointer;padding:14px 16px;font-weight:800;color:var(--cyan)}details>div{padding:0 14px 14px}
    table{width:100%;border-collapse:collapse;font-size:12.5px}th,td{border-bottom:1px solid var(--line);padding:8px;text-align:left;vertical-align:top}th{position:sticky;top:0;background:#0b1118;color:#d8f8ff}
  </style>
</head>
<body>
<main>
  <h1>UNBOUND Movement Library Final-State Review</h1>
  <p>This page describes the target migration: one Movement Catalog becomes the app source of truth. The old ExerciseCatalog is treated as temporary gym seed data until every caller reads MovementDefinition records directly.</p>
  <div class='note'><strong>Final-state rule:</strong> the app should not have a separate canonical exercise library competing with a movement catalog. There is one catalog of trainable movement definitions. Some are ranked standards, some are loggable variants, some are skill drills, some are cardio/carry/mobility/routine entries.</div>

  ${statGrid([
    ["loggable gym exercises", enriched.length],
    ["ranked standards", standards.length],
    ["loggable variants", variants.length],
    ["standalone standards", standalone.length],
    ["generated skill targets", skillTargets.length],
    ["skill-associated loggable exercises", enriched.filter((item) => item.skillAssociations.length).length],
    ["body-map regions covered", new Set(enriched.flatMap((item) => item.bodyRegions)).size],
  ])}

  <h2>Target Architecture</h2>
  <p>Everything that can appear in a workout, count toward a rank, substitute for another movement, feed stats, or connect to a skill should be represented as a MovementDefinition.</p>
  ${finalModelTable}

  <h2>Migration Map</h2>
  <p>This is how the current split collapses into one source of truth without breaking existing program generation and logging code all at once.</p>
  ${migrationTable}

  <h2>Skill Unlock Boundary</h2>
  <p>The Movement Catalog supports skill training, but it does not replace the skill tree. Unlocks and rank proofs stay owned by the 9-rank skill criteria.</p>
  ${skillUnlockTable}

  <h2>Catalog Surfaces</h2>
  <div class='grid'>
    ${card("MovementCatalog.all", "Every trainable definition across gym, skills, cardio, carry, mobility, and routines")}
    ${card("rankStandards", "Base standards that own AP/rank ladders")}
    ${card("loggableMovements", "Everything selectable in a workout builder or logger")}
    ${card("loggableVariants", "Selectable movements that roll up to a base standard")}
    ${card("skillTargets", "One generated movement per live skill-tree node")}
    ${card("skillDrills", "Supplemental practice variations that point back to a skill target")}
    ${card("legacyExercises", "Temporary compatibility view for old ExerciseCatalog callers")}
  </div>

  <h2>Canonical Policy</h2>
  <p>A movement can be selectable/loggable without owning its own rank ladder. Grip, handle, machine-brand, angle, and single-arm versions usually roll into a base standard. A movement stays separate when the pattern changes enough that the standard should change.</p>

  <h2>AP / Rank Standard Ladders</h2>
  <p>AP is earned per logged set, but movement rank still requires proving the explicit standard. Every ranked movement standard exposes all nine tiers. Loggable variants inherit the base standard's ladder.</p>
  ${standardPolicyTable}

  <h2>Ranked Standards</h2>
  <p>These are the actual standards that should get AP/ranks. Variants shown inside each row can still appear in workouts and logs, but their results roll up to the base standard.</p>
  ${templateGrid(standardsByTemplate)}

  <h2>Loggable Exercises</h2>
  <p>This is the broader selectable library for workouts and substitutions. These counts are allowed to be larger than ranked standards.</p>
  ${templateGrid(loggableByTemplate)}

  <h2>Program Slot Standards</h2>
  ${templateGrid(standardsBySlot)}

  <h2>Full Ranked Standard Map</h2>
  ${standardGroups}

  <h2>Variant Roll-Up Data</h2>
  <p>These are not deleted. They remain loggable, but the rank standard points at the base movement.</p>
  ${details(`All loggable variants · ${variants.length}`, variantTable, true)}

  <h2>Skill Links</h2>
  <p>Skill targets come directly from the live skill tree. Gym/library movements can still feed skill context, but only the skill tree's prerequisites and 9-rank criteria can unlock or advance a skill.</p>
  ${details(`Generated skill targets · ${skillTargets.length}`, `<table><thead><tr><th>Skill Target</th><th>Skill ID</th><th>Cluster</th><th>Tier</th><th>Type</th><th>Target</th><th>Prereqs</th></tr></thead><tbody>${skillTargetRows}</tbody></table>`, true)}
  ${details(`Skill-associated gym movements · ${enriched.filter((item) => item.skillAssociations.length).length}`, `<table><thead><tr><th>Movement</th><th>Linked Skills</th><th>Rank Standard</th><th>Template</th><th>Slot</th></tr></thead><tbody>${skillLinkedRows}</tbody></table>`, false)}
</main>
</body>
</html>`;

fs.writeFileSync(outputPath, html);
console.log(`Wrote ${outputPath}`);
console.log(JSON.stringify({
  loggableExercises: enriched.length,
  rankedStandards: standards.length,
  loggableVariants: variants.length,
  standaloneStandards: standalone.length,
  generatedSkillTargets: skillTargets.length,
}, null, 2));
