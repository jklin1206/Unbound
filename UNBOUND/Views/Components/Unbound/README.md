# Views/Components/Unbound

Reusable UI primitives and shared component library for the UNBOUND app.
All components here are design-system level — they own look-and-feel and are
consumed by feature views across the codebase.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [`WorkoutReward/`](WorkoutReward/README.md) | Post-workout payout sequence: beat-by-beat XP / rank / badge / cosmetic reveal. |

## Flat files

> `TierBloomToast.swift` is excluded from the Xcode build by an exact-path rule in
> `project.yml` and must never be moved.

| File | Purpose |
|------|---------|
| `BlurredPreviewOverlay.swift` | Generic overlay that blurs + darkens a content preview behind a floating paywall CTA block. Used for the post-verdict "Unlock full protocol" teaser. |
| `BodyAlignmentGuide.swift` | Live-scan overlay shared by onboarding scan and re-scan / progress-photo camera. Renders the dashed alignment frame, corner brackets, HEAD/FEET labels, figure silhouette, and status chip that track the body-alignment detector's thresholds. |
| `CalmList.swift` | Calm-list frontend language primitives: plain metadata lines (`·`-joined text, no pills), active-item lift surface. Building blocks enforcing the no-card-soup design spec. |
| `EmberView.swift` | Animated ember glow in three states — dormant (cold grey), active (violet pulse), igniting. Core visual motif used across onboarding chapter cards and stage runes. |
| `InlineNumberPad.swift` | Bottom-docked numeric keypad + RPE quick-pick that auto-pops when a set value is tapped. Part of the calm-list logging redesign; replaces modal editor sheets. |
| `MultiSelectChip.swift` | Capsule chip for multi-select grids (equipment, obstacles, prior attempts). SF Symbol icon, selected state via violet border + tint + scale. |
| `MultiSelectListRow.swift` | Full-width card row for multi-select screens. Checkbox indicator variant of `SelectionListRow` for equipment / obstacle / motivation lists. |
| `NodeUnlockedOverlay.swift` | Full-screen takeover played when a skill-tree node flips to `.proven`. Hexagon bloom animation, haptic, "NODE UNLOCKED" label sequence, gains ticker, tap-to-dismiss. |
| `NumberPadEditor.swift` | Shared bottom-docked number-pad editor used by both active-workout logging and the plan/edit session editor. Stateless buffer state machine (pristine-until-keystroke, no leading zeros, decimal seeding); caller supplies cell config via `NumberPadCellConfig`. |
| `OnboardingProgressBar.swift` | Thin 2pt progress bar anchored below the back chevron on onboarding screens. Bone-white track, violet spring-animated fill. |
| `OnboardingScaffold.swift` | Shared chrome wrapper for every onboarding screen. Two modes: default (capsule progress + `UnboundButton`) and HUD (anime backdrop + tech grid + embers + HUD progress bar). |
| `PressableCardStyle.swift` | `ButtonStyle` for selectable cards / chips / primary buttons in onboarding. Uses `Button` for proper scroll-view gesture arbitration (avoids the clunky DragGesture blocks-scroll bug). |
| `RewardCelebrationView.swift` | Modal sheet shown after a logged set / session / achievement. Stacks reward cards (rank-up hero, personal record, badge unlocks, XP) in priority order; single-tap dismisses. |
| `RewardShareCard.swift` | 9:16 portrait card rendered to `UIImage` for social sharing. Layout switches between rank-up, first-set, PR, and badge modes; derives directly from `RewardSummary`. |
| `RulerPicker.swift` | Horizontal ruler picker with a fixed center needle and violet chevron marker. Major ticks carry labels + medium haptic; minor ticks fire subtle ticks. Decoupled format closure for custom value display (e.g. feet+inches). |
| `ScanLineSweep.swift` | Looping 1pt violet horizontal scan line with soft glow. Used on processing screens and Day 2 scan animation. |
| `ScrollWheelPicker.swift` | Three-row scroll wheel showing selected center + one dimmed row above/below. `ScrollViewReader`-backed for reliable initial positioning; fires haptic ticks on integer crossings. |
| `SelectionListRow.swift` | Tappable card row for single-select screens (fitness level, frequency, session length, etc.). Title + optional subtitle + optional icon; selected state via violet border + scale. |
| `SkillTreeView.swift` | Branching skill-tree visualizer. Nodes placed on a row/column grid, connecting lines drawn between prerequisites and downstream nodes, hexagon badges for locked/proven states, floating detail card on tap. |
| `SquadTitleBadge.swift` | Pill chip rendering an earned Squad Title with a `figure.2` crew icon prefix. Color scales with tier rarity (bronze / silver / gold). |
| `TierBadge.swift` | Pill chip rendering a `SkillTier` as text with its canonical badge tint and glyph. Used on skill-tree node chips and the profile rank surface. |
| `TierBloomToast.swift` | **DO NOT MOVE** — excluded by exact path in `project.yml`. Toast overlay that blooms a tier badge when a skill tier is crossed. |
| `TitleBadge.swift` | Pill chip rendering an earned `TitleID`. Bronze / silver / gold visual treatment scales with tier rarity. |
| `UnboundButton.swift` | App-wide premium button in `.primary` (filled, violet shadow on press) and `.secondary` (transparent + 1px border, inverts on press) variants. Spring press animation + heavy haptic. |
| `UnboundCard.swift` | Generic surface card for selection rows, content blocks, and modals. Optional `isPressed` and `isSelected` bindings for interactive consumers. |
| `UnboundSlider.swift` | Premium tick-mark slider for 1–10 rating questions (diet / sleep / stress / commitment). Custom `DragGesture`-backed with bone-white ticks, violet fill + thumb, floating Geist Mono readout, haptic ticks on crossings. |
