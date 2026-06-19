# Services/SkillProgress

Tracks the user's progress through the skill tree, prescribes daily training sessions via deterministic RPE math, and routes skill blocks into session drafts. `SkillProgressService` is the observable singleton that views bind to; the other files are its supporting computation and routing layer.

| File | Purpose |
|------|---------|
| `SkillProgressService.swift` | Observable singleton that computes and persists node states (locked/proven), progress fractions, bookmarks, program focuses, and weekly schedule; emits `NodeUnlockedEvent` when a node is newly proven |
| `RPESessionService.swift` | Prescribes today's skill training session using authored static plans + RPE autoregulation math (2.5% load adjustment per RPE point of headroom); caches per-skill per-day and returns `AISession`-shaped results for existing views |
| `SkillBlockRouter.swift` | Inserts a skill-derived `TrainingBlock` into a `TrainingSessionDraft` at the correct position (primer before main lifts, accessory after, mobility last); delegates region load to `SkillBlockRegionTagger` |
| `SkillBlockRegionTagger.swift` | Maps a skill node ID to a `RegionLoad` (body-region effort weights) by pattern-matching the normalized ID against pull/push/handstand/legs/core/mobility patterns |
| `AISessionGeneratorService.swift` | Retired shell with a private init; kept as a compile-time guard against accidental rewiring to the old LLM-based session generator |

## Where to find X

| Task | File |
|------|------|
| Check or update a node's proven/locked state | `SkillProgressService.swift` |
| Get today's training prescription for a skill | `RPESessionService.swift` |
| Insert a skill block into a session draft | `SkillBlockRouter.swift` |
| Look up which body regions a skill ID loads | `SkillBlockRegionTagger.swift` |
| Add or remove a program focus (active goal) | `SkillProgressService.swift` (`toggleActiveGoal`) |
