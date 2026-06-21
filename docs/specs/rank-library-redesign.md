# Spec: Rank Library + Rank Detail Redesign

Status: SPECIFY (awaiting review). Branch: `worktree-claude+rank-library-redesign` (off `origin/main`).

## Objective

Redesign two screens so the rank experience feels premium and navigable instead of chunky.

1. The **Rank Library** (browse every ranked exercise/skill) becomes a real full-screen destination with clean push navigation, not a sheet with a full-screen cover stacked on top.
2. The **Rank Detail** (one exercise/skill) becomes a single unified, tabbed screen that surfaces far more of the data we already compute, organized by best-practice information architecture rather than a wall of capsule pills.

Who it is for: a user browsing what they can rank up, drilling into one movement to understand it, log it, and see their progression.

Success looks like: no double-modal, no capsule-as-navigation, one consistent detail screen for both skills and exercises, and richer stats surfaced cleanly.

This is a presentation-layer redesign only. No changes to rank sources, data models, or progression math. We reuse the existing single rank source (SkillStandards / node `tierCriteria` / StrengthStandards) and the existing logging, chart, and muscle-map components.

## Current State (diagnosed)

- Library is a `.large` sheet from Home (`UnboundHomeView.swift:333`); each row opens a `.fullScreenCover` (`ProgramRankLibraryView.swift:75`) that hosts its own `NavigationStack` with a custom `xmark` dismiss. Two modal layers, two dismiss affordances, nothing pushes.
- Filter rail and skill-guide tabs are `Capsule` chips; the skill rank-path uses 6 `Capsule()`s (the "bunch of pills").
- Two divergent detail screens: `ProgramRankExerciseDetailView` (ruler + chart, no tabs) vs `SkillDetailView` (expandable rank-path + 4 guide sub-tabs). A skill row and an exercise row feel like different apps.
- Heavy bordered-card chrome on every block; a 4-tile stat header eats the top of the library.
- Computed-but-hidden data: all-9-tier criteria (only "next" shows), full history list (`historyCard` is dead code), PRs/bests, distance, calories, per-movement AP, cleared/achievable counts.

## Decisions (locked with the user)

### Library navigation: full-screen push list

- Promote the library out of the sheet into a real full-screen destination reached by a push from Home, with one native back.
- Lead with the user's earned ranks: a "Your Ranks" section showing every movement they hold a tier on, sorted by tier descending (best at top, Unbound down to Initiate), recency as the tiebreak. This is the trophy case.
- Below that, the rest of the catalog they can browse and chase, grouped by category (Pull/Push skills, movement slots, Skill Drills, Other Standards) so a specific movement stays findable.
- The calm filter control flips scope (All / Earned / Skills / Exercises); "Earned" collapses to just the ranked section.
- Rows tap to **push** the detail onto the same `NavigationStack`. Remove the `.fullScreenCover`, the nested `NavigationStack`, and the custom `xmark`.
- De-chunk the rows: drop the heavy bordered-card-plus-right-band treatment for a calmer row with a tier glyph and typographic metadata.
- Replace the capsule filter rail with a calmer, non-pill control (proposed: a single quiet segmented/underline control or a menu). Search stays.
- Shrink or fold the 4-tile stat header so it does not dominate above search.

### Rank detail: one unified screen, four tabs

Unify `ProgramRankExerciseDetailView` and `SkillDetailView` into one screen used for both skills and exercises. Tabs:

1. **Overview** - understand and use this movement now.
   - Identity (art, name), current rank + next gate at a glance.
   - Logging (the metric ruler + reveal-rank action) lives here, per your note.
   - Muscle map (front/back figures + region strip).
   - Equipment needed (equipment asset strip).
   - Guide / technique (form cues, phases, tips, fixes).
2. **Rank** - the full 9-tier ladder.
   - Every tier with its criteria (today only "next" is shown), your cleared/achievable position, and the path to the next gate.
3. **Stats** - your numbers.
   - Bests/PRs (1RM, best reps, best hold seconds, distance, calories where the movement supports them), total AP, last logged.
4. **History** - what you have done over time.
   - Chronological log entries (revive the dead `historyCard`) plus the trend chart with its range selector.

Tab switcher is a calm underline/segment control, never capsule pills. Per-tier tint comes from `rewardTextTint`.

### Visual direction: hybrid

- Calm restrained chrome to browse: luminance ladder, `MetaLine`-style typographic stats, fill-only raised surfaces, no box-soup, no left-edge accent spine, no capsule navigation.
- Cinematic tier-colored moments where they earn it: the detail hero and the existing rank-up reveal overlay.

## Tech Stack

- SwiftUI, existing UNBOUND iOS app. No new dependencies.
- Tokens: `Color.unbound`, per-tier `RankTitle.rewardTint`/`rewardTextTint`, `Font.unbound`, shield art `rank_title_*`.
- Reused components: `ProgramRankMetricRuler`, `ProgramRankProofHistoryLineGraph`, `ProgramRankTargetBodyFigure`/`ProgramRankTargetRegionStrip`, `ExerciseEquipmentAssetStrip`, `SkillGuideLayerView`/`FormPhaseSlideshow`, `TierBadge`, `MetaLine`.

## Commands

- Sim build: `xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17'` (set `-o pipefail`, grep `BUILD SUCCEEDED`).
- Device-arch gate: `xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`.
- Project regen after adding files: `xcodegen generate` (pbxproj is gitignored).
- Targeted tests when files move: `-only-testing:ReadmeFreshnessTests`, plus rank/skill suites.

## Project Structure

- Library screen: `UNBOUND/Views/Program/ProgramRankLibraryView.swift` + `UNBOUND/Views/Program/RankLibrary/`.
- Detail (today): `RankLibrary/ProgramRankExerciseDetailView*.swift` and `UNBOUND/Views/Home/SkillDetail/SkillDetailView*.swift`.
- New unified detail will live under `RankLibrary/` (one tab container + per-tab section files, kept to one responsibility per file, ~150-400 lines each).
- Each touched directory README updated (README freshness contract).

## Code Style

Match surrounding SwiftUI: tokens only, small composable views, no inline hex.

```swift
// Calm row: tier glyph + typographic meta, no bordered card, no capsule.
HStack(spacing: 12) {
    TierGlyph(tier: row.tier)
    VStack(alignment: .leading, spacing: 2) {
        Text(row.title).font(.unbound.bodyLStrong).foregroundStyle(Color.unbound.textPrimary)
        MetaLine(parts: [row.subtitle, row.metric])   // not pills
    }
    Spacer()
    Image(systemName: "chevron.right").foregroundStyle(Color.unbound.textTertiary)
}
.contentShape(Rectangle())
```

## Testing Strategy

- Logic is unchanged, so the gate is mostly visual + build.
- Sim screenshots of the real integrated screens via launch-arg harness (`--unbound-open-ranks`, extend with a detail arg), Read the PNGs.
- Device-arch build green (AnyView-wrap heavy bodies if metadata depth bites).
- Pixel-council color check before done (tokens, AA on true-black, per-rank palette, reduced-motion).
- Run `-only-testing:ReadmeFreshnessTests` and existing rank/skill suites after file moves.

## Boundaries

- Always: tokens only, stage explicit paths (shared tree), update dir READMEs, screenshot before claiming done, device-arch build before claiming done.
- Ask first: deleting the old detail screens (do it in the same change that replaces them, not as a tombstone), any change to logging behavior, any change to the browsing axis.
- Never: `git add -A`, new rank source/ladder, inline hex, capsule pills as navigation, left-edge accent spine.

## Success Criteria

1. Library is a full-screen push destination; zero `.fullScreenCover` and zero nested `NavigationStack` in the rank flow; one dismiss/back. It leads with earned ranks sorted best-first, with the rest of the catalog browsable below.
2. Detail is one screen for both skills and exercises with tabs Overview/Rank/Stats/History via a non-capsule switcher.
3. Rank tab shows all 9 tiers with criteria; History shows the chronological list (not just the chart); Stats surfaces bests/AP/last-logged.
4. No capsule pill is used for navigation on either screen.
5. Sim screenshots of both screens read clean; device-arch build green; color check passed.

## Resolved Defaults (override any at this gate)

1. **Logging placement.** Lives inside the Overview tab (per your note). I will also keep the rank-up reveal overlay firing on a successful log. No separate sticky bar unless you want one.
2. **Tab switcher style.** A quiet underline segment (non-capsule).
3. **Library filter control.** Replace the capsule filter rail (All/Earned/Skills/Exercises/Top) with one calm segmented/underline control; search kept.
4. **Home entry point.** The same Home button now opens the full-screen push destination instead of presenting a sheet; no new entry point.
