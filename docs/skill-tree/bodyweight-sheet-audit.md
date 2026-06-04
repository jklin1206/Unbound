# Bodyweight Sheet Skill-Tree Audit

**Source:** Google Sheet `1VU3jJ2Sy5FZ9u0O0Gv1NVwB7OjaSwUW-8L_jm88c4H4`, exported to `/private/tmp/bodyweight_progressions.csv` during the audit.

**Goal:** convert the sheet into an extremely strong UNBOUND skill tree without turning every temporary progression into a fake prestige node.

## Product Policy

The three-lane audit converged on one rule:

| Type | App home | Rule |
| --- | --- | --- |
| Anchor Node | `SkillGraph` | Ownable milestone, worth maintaining, can support real mastery tiers, visible in the tree. |
| Drill Rail | skill dossier, tier criteria, training plan | Temporary scaffold or proof step for an anchor skill. |
| Catalog Exercise | `MovementCatalog` / `ExerciseCatalog` | Loggable and prescribable, but not a tree achievement. |
| Warmup / Mobility | routines, prep flows | Tissue tolerance, movement prep, or activation. |

The tree should show the world map. Locks should gate claiming, rewards, proof, and safe auto-programming; they should not hide knowledge.

## Architecture Guardrails

Use current structures only:

- `SkillGraph.shared` remains the visible tree source of truth.
- `SkillNode` remains the only visible tree unit.
- 9-tier criteria remain generated or authored through the existing family tier tables.
- Dossiers stay in `SkillGuideLibrary`.
- Form phases stay in `FormPhaseLibrary`.
- Training drills stay in `SkillTrainingPlanLibrary`.
- Catalog names are added only when a drill needs to be logged/prescribed distinctly.

Request a principal architect review before any plan tries to:

- Add a new ladder/rank/progression state system.
- Add OR semantics to `TierCriterion`.
- Make the spreadsheet a runtime data source.
- Create a new `DrillRail` model before exhausting existing dossier/training-plan sections.
- Change lock-state semantics.
- Add a large batch of nodes in one pass.
- Integrate dozens of generated assets without movement review.

## Current Incorporation

This branch promotes one high-confidence missing anchor:

| Anchor | Change | Why |
| --- | --- | --- |
| `cl.tuck-back-lever` | Added as a live `SkillGraph` node and CL seconds anchor. | The sheet and existing app copy both treat tuck back lever as the canonical first horizontal back-lever pause. It is not a temporary assist like a banded drill. |

No drill-only movements were promoted.

## Family Decisions

### Pull

| Sheet movement / family | Classification | Current app state | Next action |
| --- | --- | --- | --- |
| Pull-Up, Chin-Up, Weighted Pull-Up, Archer Pull-Up | Anchor Node | Present under `pp.*` | Keep. |
| Chest-to-Bar / High Pull-Up | Anchor candidate | `chest-to-bar pullup` exists as catalog/proof token, not a node | Add only if product wants a visible muscle-up bridge node. |
| Muscle-Up, Ring Muscle-Up, Strict Muscle-Up | Anchor Node | Present | Keep; audit tier criteria before changing. |
| Scapular Pull, Arch Hang, Pull-Up Negative | Drill Rail | Training-plan/cata­log style content | Keep out of tree. |
| False-Grip Row, Banded Ring Muscle-Up, Negative Muscle-Up, Typewriter Pull-Up | Drill Rail / Catalog Exercise | Some missing or orphan-only | Add as catalog/loggable drill tokens before using in criteria. |
| Iron Cross | Priority 2 Anchor | Not in active tree | Defer until ring-specialty branch is designed. |

### Push / Ring Support

| Sheet movement / family | Classification | Current app state | Next action |
| --- | --- | --- | --- |
| Push-Up, Diamond Push-Up, Archer Push-Up, One-Arm Push-Up | Anchor Node | Present | Keep. |
| Dip, Ring Dip | Anchor Node | Present | Keep. |
| Ring Support / RTO Support | Priority 1 Anchor candidate | Mostly drill/proof content | Add only if ring pathway needs a visible support gate. |
| Dip Negative, Support Hold, RTO Support Hold | Drill Rail | Not all catalog-backed | Keep as drills; add catalog tokens if used in programs/proof. |
| Pike Push-Up, Elevated Pike, HSPU | Anchor Node | Present | Clarify wall HSPU versus freestanding HSPU before adding nodes. |
| Clapping / triple-clap / clapping HSPU | Challenge / cosmetic candidate | Some present as nodes | Do not expand this branch until core tree is cleaner. |

### Planche / Arm Balance

| Sheet movement / family | Classification | Current app state | Next action |
| --- | --- | --- | --- |
| Crow / Crane / Elbow Lever | Anchor Node | Present as `hs.*` arm-balance nodes | Keep. |
| Planche Lean | Drill Rail or foundation node | Present as drill alias to planche path | Keep out of tree unless foundation branch is redesigned. |
| Tuck Planche | Anchor Node | Present | Keep. |
| Advanced Tuck Planche | Priority 0 Anchor | Missing visible node | Add in a later focused pass. |
| Straddle / Half-Lay / Full Planche | Anchor Node | Present | Keep. |
| Band-Assisted Planche, planche push-up intermediates | Drill Rail / Catalog | Partially present | Avoid node bloat. |
| Maltese, Ring Planche | Priority 2 Anchor | Missing | Defer to specialty endgame. |

### Levers / Core

| Sheet movement / family | Classification | Current app state | Next action |
| --- | --- | --- | --- |
| Tuck Front Lever | Anchor Node | Present | Keep. |
| Advanced Tuck Front Lever | Priority 0 Anchor | Catalog/art exists, no visible node | Add in a later focused pass. |
| One-Leg Front Lever | Priority 1 Anchor candidate | Missing | Decide after advanced tuck FL. |
| Straddle / Full Front Lever | Anchor Node | Present | Keep. |
| German Hang, Skin the Cat | Anchor / entry movement | Present | Keep; avoid circular gating. |
| Tuck Back Lever | Anchor Node | Added on this branch | Keep. |
| Advanced Tuck / One-Leg Back Lever | Priority 0/1 Anchor candidates | Missing | Add only after tuck BL is validated. |
| Straddle / Full Back Lever | Anchor Node | Present | Keep. |
| Foot-Supported L-Sit, Tuck L-Sit, One-Leg L-Sit | Drill Rail | Training-plan content | Keep out of tree. |
| L-Sit, Straddle L-Sit, V-Sit, Vertical L-Sit | Anchor Node | Present | Keep. |
| Manna | Priority 2 Anchor | Missing | Defer. |

### Legs

| Sheet movement / family | Classification | Current app state | Next action |
| --- | --- | --- | --- |
| Deep Squat, Split Squat, Bulgarian Split Squat | Anchor / foundation | Present | Keep, but review tree bloat later. |
| Pistol Squat, Weighted Pistol | Anchor Node | Present | Keep. |
| Box / Assisted / Negative / Partial Pistol | Drill Rail | Assisted pistol exists, others vary | Add only as drill/catalog/proof steps, not nodes. |
| Shrimp Squat | Anchor Node | Present | Keep. |
| Box / Counterbalance / Elevated / Weighted Shrimp | Drill Rail / Catalog | Mixed | Add as catalog only if programmed. |
| Nordic Hip Hinge, Advanced Nordic, Nordic Curl | Anchor Node | Present | Keep; fix duplicate/ambiguous proof names in a focused pass. |
| Band / Partial / Negative Nordic | Drill Rail | Mostly missing | Catalog/proof only, not nodes. |
| Cossack Squat | Priority 1 Anchor candidate | Catalog exercise exists | Consider as mobility-strength anchor. |
| Fire Hydrant, Flying Kickback, Leg Extensions | Accessory / Catalog | Present as nodes today | Candidate demotion, but do not remove without product review. |

### Handstand / One-Arm Handstand

| Sheet movement / family | Classification | Current app state | Next action |
| --- | --- | --- | --- |
| Wall Handstand, Freestanding Handstand | Anchor Node | Present | Keep. |
| Heel Pull, Wall Shoulder Tap, Kick-Up Practice | Drill Rail | Present as drills | Keep out of tree. |
| Tuck / Straddle / Press to Handstand | Anchor Node | Present | Keep. |
| Wall-Supported OAH | Anchor / prep node | Present | Keep. |
| OAH Prep / weight shift / fingertip assist / off-hand float | Drill Rail or single prep anchor | Present as guide/training drills | Do not add every micro-step as a node. Consider one `OAH Prep` anchor if detail UX cannot carry it. |
| One-Arm Handstand, Full OAH | Anchor Node | Present | Keep. |

### Warmup / Mobility

| Sheet movement / family | Classification | Next action |
| --- | --- | --- |
| Wrists, shoulders, bodyline work, squat sky reach, scap prep, false-grip prep | Warmup / Routine | Keep in routine/prep content, not the visible tree. |
| Pallof press, hyperextension/reverse hyperextension | Catalog / accessory | Loggable or program support only. |

## Asset Policy

- Generate full 4-panel UNBOUND art for anchor nodes.
- Reuse existing fallback phase slides for newly promoted anchors until generated art passes movement review.
- Generate simple drill visuals only for repeated high-value drills in programs.
- Do not generate a prestige image for every banded/assisted/negative spreadsheet row.

Immediate asset need from this branch:

| Skill | Need | Status |
| --- | --- | --- |
| `cl.tuck-back-lever` | Full infographic + four phase crops | Needed; fallback phases work now. |

Use the locked `unbound-skill-assets` style for the eventual image: recurring black-haired avatar, black training outfit, dark background, cyan/teal rim light, no violet, no app UI.

## Verification Targets

- Node/table parity tests.
- CL tier count and 9-tier coverage.
- Movement proof matching for new exact criterion names.
- Skill detail opens for promoted anchors.
- Simulator smoke on the skill tree and detail pages.
- Long-horizon/year-style program simulation where available.
