# Components/Unbound

UNBOUND's brand component library: the buttons, cards, pickers, list rows, badges, and onboarding chrome that define the app's look and feel. Subfolder `WorkoutReward/` holds the workout-end payout sequence (see its README).

## Files

| File | What's inside |
|---|---|
| `CalmList.swift` | Calm-list language primitives, starting with `MetaLine` (plain `·`-joined metadata text replacing pill rows). Enforces the no-box-soup rules from the 2026-06-08 program-frontend redesign spec. |
| `InlineNumberPad.swift` | `InlineNumberPad` + `NumberPadKey` — the stateless bottom-docked numeric keypad that pops when a set value is tapped (calm-list Phase 1b); parent owns the typed buffer. |
| `MultiSelectChip.swift` | `FlexibleWrap` — minimal tag-cloud `Layout` that wraps children onto new lines; used by the onboarding verdict chip cloud. |
| `SessionRoleAccent.swift` | `SessionRole.accentColor` + `MovementSlot.accentColor/accentLabel` (per-type pop color: push = ember amber, pull = reward blue, legs = warn orange …) + `SessionRoleChip` (● ROLE colored chip); drives tinted borders / glows / chips on loadout cards, the daily quest card, and editor exercise cards. |
| `WeightUnitHeaderToggle.swift` | `WeightUnitHeaderToggle` — "WEIGHT LB ⇄" column header that flips the app-wide lb/kg default on tap; used by the session editor and active-workout set grids. |
| `MultiSelectListRow.swift` | `MultiSelectListRow` — full-width multi-select card row with a checkbox indicator; visually matches `SelectionListRow`. |
| `NumberPadEditor.swift` | The shared bottom-docked keypad-editing module (Phase 2): `NumberPadFieldKind` + the editing state machine/`NumberPadCellConfig` used by BOTH active-workout logging and the session editor; callers supply seed/live-write/commit closures. |
| `OnboardingProgressBar.swift` | `OnboardingProgressBar` — thin 2pt progress bar under the back chevron on onboarding screens; violet fill springs between steps. |
| `OnboardingScaffold.swift` | `OnboardingScaffold` — shared chrome for every onboarding screen (title/subtitle, back button, progress, CTA), with a default mode and an anime-HUD mode (`hudStep != nil`). |
| `OnboardingBackdrop.swift` | `OnboardingBackdrop` — full-bleed scene art + a tunable 3-stop vertical scrim (dark top/bottom for text legibility) + optional accent bloom. Reserved for hero moments; currently backs the full-screen exit-intent promo with the generated `promo_locked_door` art. |
| `PressableCardStyle.swift` | `PressableCardStyle` — the ButtonStyle all selectable cards/chips use; defers to ScrollView gesture arbitration (fixes "can't scroll over cards") while mirroring `isPressed` into a binding so cards keep their spring/haptic feel. |
| `RankRow.swift` | `RankRow` — calm rank-library list row (movement art, title + `MetaLine` meta, tier shield) on a single fill-only raised surface; replaces the heavier bordered-card library row. |
| `RulerPicker.swift` | `RulerPicker` — horizontal ruler drag picker with fixed center needle, major/minor tick hierarchy, haptics, and a `format` closure for custom readouts (e.g. feet-and-inches). |
| `ScanLineSweep.swift` | `ScanLineSweep` — looping 1pt violet scan line that sweeps vertically with a glow; used on processing screens and the Day 2 scan animation. |
| `UnitToggle.swift` | `UnitToggle` — segmented cm/ft-style unit toggle used by the height/weight onboarding steps. |
| `SegmentedFilterBar.swift` | `SegmentedFilterBar` — calm underline-style segmented filter control (no pills); selection cue is luminance + a sliding accent underline. |
| `SelectionListRow.swift` | `SelectionListRow` — single-select card row (title + optional subtitle/icon, violet selected state) used by fitness level, experience, frequency screens, etc. |
| `SignaturePadView.swift` | `SignaturePadView` — finger-drawn signature capture with a glowing accent ink stroke; emits normalized (0...1) strokes so a signature re-renders at any size. Backs the onboarding pact ritual; `highPriorityGesture` so drawing wins over the scaffold's ScrollView. |
| `SkillTreeView.swift` | `SkillTreeView` — branching skill-tree visualizer: grid-positioned hexagon nodes, prerequisite connector lines, locked/proven states, tap-for-detail callback. |
| `SquadTitleBadge.swift` | `SquadTitleBadge` — pill chip for an earned Squad Title (`figure.2` prefix); bronze/silver/gold treatment by tier. |
| `TierBadge.swift` | `TierBadge` — pill chip rendering a `SkillTier` with its badge asset + canonical tint; used on skill-tree node chips and the profile rank surface. |
| `TierBloomToast.swift` | Intentionally empty stub — the real `TierBloomToast` lives in `Views/Components/Cinematic/`. DO NOT move or delete: this exact path is excluded in project.yml. |
| `TitleBadge.swift` | `TitleBadge` — pill chip for an earned (non-squad) Title; bronze/silver/gold prominence by tier. |
| `UnboundButton.swift` | `UnboundButton` + `UnboundButtonVariant` — the brand button (.primary filled / .secondary bordered) with spring press + heavy haptic; use instead of stock `Button`. |
| `UnboundCard.swift` | `UnboundCard` — the generic surface card (corner radius, padding, optional pressed/selected states) backing selection rows and content blocks. |
| `UnderlineTabBar.swift` | `UnderlineTabBar` — calm underline tab switcher (generic over a `Hashable` tab); selected label raises to `textPrimary` with a sliding accent underline (no capsules/pills). |
| `WorkoutReward/` | The full workout-end reward sequence (`WorkoutRewardSequenceView` + all its beats, heroes, rows, bars, XP receipt). See `WorkoutReward/README.md`. |

## Where to find X

- **Buttons / cards / pickers (brand primitives)** → `UnboundButton`, `UnboundCard`, `RulerPicker`, `UnitToggle` (in `UnitToggle.swift`).
- **Selection rows and chips (onboarding questionnaires)** → `SelectionListRow` (single), `MultiSelectListRow` (multi), all pressed via `PressableCardStyle`.
- **Onboarding chrome** → `OnboardingScaffold`, `OnboardingProgressBar`, `ScanLineSweep`.
- **Set logging keypads** → `InlineNumberPad` (the dumb keypad view), `NumberPadEditor.swift` (the shared editing state machine both logging surfaces use).
- **Calm-list metadata text** → `MetaLine` in `CalmList.swift`.
- **Badges / pills** → `TierBadge` (skill tier), `TitleBadge` (earned title), `SquadTitleBadge` (squad title).
- **Rank library row + tab/filter chrome** → `RankRow` (list row), `UnderlineTabBar` (tab switcher), `SegmentedFilterBar` (filter control).
- **Skill tree rendering** → `SkillTreeView`. The node-unlock moment is the in-tree reveal in `../../Home/SkillTree/ClusterStaircaseView.swift` (presented by `../Cinematic/NodeUnlock/SkillUnlockTreeReveal.swift`).
- **Workout-end payout sequence** → `WorkoutReward/`.
