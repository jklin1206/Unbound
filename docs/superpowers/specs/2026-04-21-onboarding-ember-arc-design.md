# UNBOUND Onboarding — Ember Arc Redesign

**Date:** 2026-04-21
**Scope:** Onboarding flow polish — narrative frame, visual language, per-screen fixes, two reusable patterns (umbrella-select list, ember motif).
**Out of scope:** Backend wiring, paywall, post-onboarding dashboard.

---

## 1. Narrative Frame

**Rule:** The world uses arc language. The copy stays grounded.

- Structure speaks in chapters, stages, seals, embers — visually and in labels.
- Headlines and subs speak plainly to the user. No narrator voice. No "young warrior." No "your journey begins."
- Anime-literate users catch the motifs. Everyone else sees a tight premium app.
- "Break the restriction" means "start your fitness arc / become the version you want to train into." It is not a mandate to diagnose literal weak links, limiters, restrictions, or flaws in the user.
- The opening should invite the user into the arc first. Assessment, rank, protocol, and proof come after the cold open as the tutorial/mechanic layer.
- Avoid making "the loop", "weak link", "limiter", or "what is holding you back" the core pain point. The simpler pain point is: normal fitness feels random and unearned; UNBOUND makes training feel like a real arc with visible progress.

**Cringe tests** (never ship):
- "Awaken your true potential"
- "The path of the strong calls"
- Named anime characters (Toji, Itadori, Todo, Saitama) — legal/IP risk, internal shorthand only.
- "We found your weak link"
- "Your limiter is holding you back"
- "System detected your failure loop"

**Tone reference** (keep):
- `CHAPTER II · THE MAPPING` — label does the work, no narration.
- "Your training arc starts now" — "arc" carries it, rest is direct.

---

## 2. The Ember Thread

Core narrative metaphor inspired by MHA's spark → flame progression. The ember IS the mechanism of ranking up, and it threads the existing rank tier system:

| Rank | State | Ember visual |
|---|---|---|
| E | Dormant | Cold. Barely visible pulse. |
| D | Awakened | First spark catches. |
| C | Forged | Ember inside a small flame. |
| B | Sharpened | Controlled fire. |
| A | Unbound | Roaring blaze. **Brand moment.** |
| S | Ascended | Pure flame / aura released. |

Every onboarding screen reinforces the ember. It is the single through-line.

---

## 3. Per-Screen Specs

### Screen 1 — Baseline ("Your stats aren't where you want them")

**Problems addressed:** missing character asset, deadspace, framing.

- **Add neutral sealed silhouette** on the left half of the screen. Archetype-agnostic generic male body. Dim grey with barely-perceptible violet aura. A **cold ember glow at the chest center** — dim, pulsing slow (~2s cycle).
- **Stats bars** move to right half, 6 bars at E rank. Intentional pairing with silhouette — body on left, current stats on right.
- **Copy:**
  - Optional chapter label top-left (uppercase mono, low opacity): `CHAPTER I · THE BASELINE`
  - Headline: "This is where you start."
  - Sub: "Everyone begins sealed. The ones who stay — break through."
- **Animation on enter:** silhouette fades in (0.8s), ember begins pulsing, stats bars fill to their E-rank values one at a time with 80ms stagger.

### Screen 2 — Archetype Reveal (stats + SLEEPER silhouette)

**Problems addressed:** transition speed, per-user stats, stat count, deadspace, carousel hanging on HEAVYWEIGHT.

- **Carousel mode: continuous loop** (Option C chosen). All 4 archetype silhouettes rotate on a slow infinite loop in the background while stats and archetype label update live. No settle. No landing.
  - Transition between archetypes: **0.5s cross-fade**, not snap.
  - Label (`SLEEPER`, `V-TAPER`, etc) cross-fades with the silhouette.
  - Rationale: the user has ALREADY picked their archetype on the picker (Stage 12). Screen 2 is the "possibility space" moment — your class sits among equals. Settling would imply a reveal that's already happened.
- **Stats — 6 bars, per-user values:**
  - STRENGTH, STAMINA, DISCIPLINE, CONFIDENCE, FOCUS, RECOVERY
  - Each bar reads the user's computed baseline rank (E/D/C/B/A/S). No hardcoded values.
  - Stat values populate as a cascade (80ms stagger, 300ms ease-out per bar).
- **The user's selected archetype silhouette carries an active violet ember** in the chest. The other 3 (as they rotate through) show only a dim grey ember — they're "possibilities not chosen."
- **Copy stays:** "Your training arc starts now." Sub tweak: "Every rep ranked. Every arc measured." (was "week measured" — arc reinforces frame).

### Screen 3 — Stage Card (sleep / recovery benefit)

**Problems addressed:** squished hexagon shape.

- **Fix hexagon aspect ratio lock.** Current implementation is letting the parent frame squish the SVG. Force 1:1 aspect on the icon container. Regular hexagon, not stretched.
- Re-cast the hexagon as a **rune containing an ember**. Purple outline hex, a small ember inside (not the generic moon icon). Ties to the thread.
  - Stage-specific inner icons can still vary (moon for sleep, lightning for energy, etc) — but they sit INSIDE the ember glow, not replace it.
- Keep all copy. No other changes.

### Screen 4 — Chapter Card (`CHAPTER II · THE MAPPING`)

**Problems addressed:** flat entrance animation, no sense of "unlocking."

- **Ember-ignition entrance sequence (~1.2s total):**
  1. `0.0s` — Black screen. Single violet ember drifts up from bottom center, slow.
  2. `0.5s` — Ember reaches center, bursts into a spark (brief white flash).
  3. `0.7s` — Chapter label (`CHAPTER II`) emerges from the spark's light, scaling 0.9 → 1.0 with ease-out.
  4. `1.0s` — Sub-title (`THE MAPPING`) fades in below.
  5. `1.2s` — DEV·SKIP button and background grid fade in. Settled state.
- No chains, no cracks, no seal-breaking imagery. The ember is the restriction breaking — quieter, more elegant, less cosplay.

---

## 4. Archetype Picker (Stage 12 — "Who do you want to become?")

**Problems addressed:** anime character names in copy (IP risk), empty card silhouettes.

- **Remove taglines under archetype names.** "Toji build" / "Itadori build" / "Todo build" / "Saitama build" are all stripped. No replacement tagline — just archetype name + silhouette + number.
- **Card layout (updated):**
  - `01` hexagon slot top-left
  - Selection hex top-right (empty outline → filled purple check)
  - Silhouette fills card body (this was empty — must be populated)
  - Archetype label bottom center (`V-TAPER`, `SHREDDED`, `HEAVYWEIGHT`, `SLEEPER`)
- **Required art assets** — all 4 archetype silhouettes in the same style as the existing SLEEPER asset (dark body, purple rim light). Pose matches character energy (internal shorthand — never shipped in copy):
  - V-TAPER — lean assassin stance (hands relaxed at sides, slight shoulder drop)
  - SHREDDED — athletic ready stance (feet shoulder-width, fists loose)
  - HEAVYWEIGHT — power stance (wide feet, arms out from body for mass)
  - SLEEPER — unassuming neutral stance (already exists)
- Each silhouette card shows a **dim ember in the chest**. Selected card's ember **ignites** on tap (dim → active violet, 300ms ease).

---

## 5. Reusable Pattern — `UmbrellaSelectList`

Used on muscle group picker (Stage 13) and equipment picker (Stage 23). Generalizes to any picker where one option is a superset of the others.

**Behavior:**
- Umbrella option sits at position `01` (top).
- Tap umbrella → all sub-options auto-select. **Cascade animation**: 50ms stagger as each sub-option's check hexagon fills, top to bottom. Feels like a system response, not an instant flip.
- Tap any sub-option while umbrella is selected → umbrella deselects (no longer "all").
- Tap all sub-options manually → umbrella auto-selects (system recognizes completeness, hex fills with a brief violet pulse).

**Applied to:**

### Muscle group picker (Stage 13)
- Reorder: `Full body` moves from 08 → 01. Sub-options renumber 02–08 (Chest, Back, Shoulders, Arms, Core, Legs, Glutes).
- **Fix icons** — current Back icon (two figures) and Shoulders icon (runner) don't read. Replace with clearer glyphs:
  - Back → back-view figure with spine highlight
  - Shoulders → front-view figure with deltoid highlight
  - Others audited and fixed where unclear (Core, Legs, Glutes glyphs reviewed for muscle specificity).

### Equipment picker (Stage 23)
- `Full gym` already at 01 — no reorder needed.
- Add umbrella-select cascade behavior.

---

## 6. Global Rules (all screens)

- **DEV · SKIP button** — keep for dev builds. Hide in release builds via `#if DEBUG` gate. Out of scope for this spec's visual work, but tagged for implementation.
- **Ember as the only "magic" motif** — no chains, no cracks, no sigils unless they are ember-containing runes.
- **Chapter labels** (uppercase mono, low opacity) appear on screens that mark a narrative beat. Not every screen needs one.
- **Motion budget** — entrance animations ≤ 1.2s. Cross-fades 0.3–0.5s. Stat bar cascades 80ms stagger. No spring overshoots on text (springs fine on hex checks, buttons).

---

## 7. Component Inventory (for implementation plan)

New/modified SwiftUI views:
- `BaselineSilhouetteView` — neutral sealed body with ember (Screen 1)
- `ArchetypeCarouselView` — continuous loop, 4 archetypes, 0.5s cross-fade (Screen 2)
- `StatBarRow` — single bar with label + rank, driven by user-specific data (6 instances on Screen 2)
- `EmberIgnitionTransition` — reusable entrance animation for chapter cards (Screen 4)
- `EmberRuneIcon` — hexagon rune container with ember glow + variable inner icon (Screen 3 and beyond)
- `UmbrellaSelectList<T>` — generic multi-select with umbrella option (muscle + equipment pickers)
- `ArchetypeCard` — picker card variant with silhouette slot + selection hex

New art assets:
- 3 archetype silhouettes: V-TAPER, SHREDDED, HEAVYWEIGHT (SLEEPER exists)
- Neutral sealed silhouette (Screen 1)
- Ember particle sprite (shared across screens)
- Corrected muscle group icons: Back, Shoulders (others on audit)

Data dependencies:
- Per-user baseline stat values (E-rank defaults for new users)
- 6 stats computed: Strength, Stamina, Discipline, Confidence, Focus, Recovery
- User's selected archetype (from picker at Stage 12)

---

## 8. Open Questions (for plan phase)

- Where are the 6 stat values computed? New onboarding stat calculator, or derived from existing scan + picker answers?
- Is there already a particle-system pattern in the codebase (for the ember drift animation), or does this introduce a new visual primitive?
- Should the ember glow use a shader / Canvas drawing, or a layered PNG with opacity animation? (Plan-phase decision based on perf budget.)
- **Screen 2 carousel + stats sync:** When the background carousel rotates through non-user archetypes, do the stat bars stay pinned to the user's archetype, or sync to the currently-visible archetype? The ember diff (active vs dim) already disambiguates "yours" visually — but stats syncing could make each rotation a mini-glimpse of that archetype's baseline. Default assumption: **stats stay pinned to user's archetype**; the carousel is ambient/scenic. Revisit if it feels wrong in prototype.
