# Components/Unbound

UNBOUND's brand component library: the buttons, cards, pickers, list rows, badges, overlays, and onboarding chrome that define the app's look and feel. Subfolder `WorkoutReward/` holds the workout-end payout sequence (see its README).

## Files

| File | What's inside |
|---|---|
| `BlurredPreviewOverlay.swift` | `BlurredPreviewOverlay` — blurs + darkens content behind a floating CTA block; the paywall teaser over the full protocol preview. |
| `CalmList.swift` | Calm-list language primitives, starting with `MetaLine` (plain `·`-joined metadata text replacing pill rows). Enforces the no-box-soup rules from the 2026-06-08 program-frontend redesign spec. |
| `EmberView.swift` | `EmberView` — animated ember glow with `.dormant` / `.active` / `.igniting` states; core onboarding visual motif (silhouette chest, chapter ignition, stage runes). |
| `InlineNumberPad.swift` | `InlineNumberPad` + `NumberPadKey` — the stateless bottom-docked numeric keypad that pops when a set value is tapped (calm-list Phase 1b); parent owns the typed buffer. |
| `MultiSelectChip.swift` | `MultiSelectChip` — capsule chip for multi-select grids (equipment, obstacles); SF Symbol icon, violet selected state. |
| `MultiSelectListRow.swift` | `MultiSelectListRow` — full-width multi-select card row with a checkbox indicator; visually matches `SelectionListRow`. |
| `NodeUnlockedOverlay.swift` | `NodeUnlockedOverlay` — full-screen takeover when a skill-tree node flips to `.proven` (scrim → hexagon bloom → labels → gains ticker); driven by `SkillProgressService.pendingUnlock`. |
| `NumberPadEditor.swift` | The shared bottom-docked keypad-editing module (Phase 2): `NumberPadFieldKind` + the editing state machine/`NumberPadCellConfig` used by BOTH active-workout logging and the session editor; callers supply seed/live-write/commit closures. |
| `OnboardingProgressBar.swift` | `OnboardingProgressBar` — thin 2pt progress bar under the back chevron on onboarding screens; violet fill springs between steps. |
| `OnboardingScaffold.swift` | `OnboardingScaffold` — shared chrome for every onboarding screen (title/subtitle, back button, progress, CTA), with a default mode and an anime-HUD mode (`hudStep != nil`). |
| `PressableCardStyle.swift` | `PressableCardStyle` — the ButtonStyle all selectable cards/chips use; defers to ScrollView gesture arbitration (fixes "can't scroll over cards") while mirroring `isPressed` into a binding so cards keep their spring/haptic feel. |
| `RewardShareCard.swift` | `RewardShareCard` — 9:16 portrait card rendered to UIImage for social sharing; layout varies by celebration type (rank-up / first-set / PR / badge) and reuses `RewardSummary`. |
| `RulerPicker.swift` | `RulerPicker` — horizontal ruler drag picker with fixed center needle, major/minor tick hierarchy, haptics, and a `format` closure for custom readouts (e.g. feet-and-inches). |
| `ScanLineSweep.swift` | `ScanLineSweep` — looping 1pt violet scan line that sweeps vertically with a glow; used on processing screens and the Day 2 scan animation. |
| `ScrollWheelPicker.swift` | `ScrollWheelPicker` — three-row wheel picker (center selected + dimmed neighbors); ScrollViewReader for reliable initial centering, haptic ticks on crossings. |
| `SelectionListRow.swift` | `SelectionListRow` — single-select card row (title + optional subtitle/icon, violet selected state) used by fitness level, experience, frequency screens, etc. |
| `SkillTreeView.swift` | `SkillTreeView` — branching skill-tree visualizer: grid-positioned hexagon nodes, prerequisite connector lines, locked/proven states, tap-for-detail callback. |
| `SquadTitleBadge.swift` | `SquadTitleBadge` — pill chip for an earned Squad Title (`figure.2` prefix); bronze/silver/gold treatment by tier. |
| `TierBadge.swift` | `TierBadge` — pill chip rendering a `SkillTier` with its badge asset + canonical tint; used on skill-tree node chips and the profile rank surface. |
| `TierBloomToast.swift` | Intentionally empty stub — the real `TierBloomToast` lives in `Views/Components/Cinematic/`. DO NOT move or delete: this exact path is excluded in project.yml. |
| `TitleBadge.swift` | `TitleBadge` — pill chip for an earned (non-squad) Title; bronze/silver/gold prominence by tier. |
| `UnboundButton.swift` | `UnboundButton` + `UnboundButtonVariant` — the brand button (.primary filled / .secondary bordered) with spring press + heavy haptic; use instead of stock `Button`. |
| `UnboundCard.swift` | `UnboundCard` — the generic surface card (corner radius, padding, optional pressed/selected states) backing selection rows and content blocks. |
| `UnboundSlider.swift` | `UnboundSlider` — custom tick-mark 1–10 slider (diet/sleep/stress/commitment) with violet thumb/fill, floating value label, haptic per integer. |
| `WorkoutReward/` | The full workout-end reward sequence (`WorkoutRewardSequenceView` + all its beats, heroes, rows, bars, XP receipt). See `WorkoutReward/README.md`. |

## Where to find X

- **Buttons / cards / sliders / pickers (brand primitives)** → `UnboundButton`, `UnboundCard`, `UnboundSlider`, `RulerPicker`, `ScrollWheelPicker`.
- **Selection rows and chips (onboarding questionnaires)** → `SelectionListRow` (single), `MultiSelectListRow` / `MultiSelectChip` (multi), all pressed via `PressableCardStyle`.
- **Onboarding chrome** → `OnboardingScaffold`, `OnboardingProgressBar`, `EmberView`, `ScanLineSweep`.
- **Set logging keypads** → `InlineNumberPad` (the dumb keypad view), `NumberPadEditor.swift` (the shared editing state machine both logging surfaces use).
- **Calm-list metadata text** → `MetaLine` in `CalmList.swift`.
- **Badges / pills** → `TierBadge` (skill tier), `TitleBadge` (earned title), `SquadTitleBadge` (squad title).
- **Skill tree rendering + node unlock moment** → `SkillTreeView`, `NodeUnlockedOverlay`.
- **Post-set/session celebration + share asset** → `RewardShareCard`.
- **Workout-end payout sequence** → `WorkoutReward/`.
- **Paywall blur teaser** → `BlurredPreviewOverlay`.
