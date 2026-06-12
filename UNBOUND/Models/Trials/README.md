## Models/Trials

Weekly Vow system: the card selection, state tracking, capstone evaluation, theme/axis flavoring, and kind enumeration for the weekly commitment feature.

| File | Purpose |
|------|---------|
| `Trial.swift` | `WeeklyVow` — the user's committed weekly vow; holds the chosen card, capstone state, and completion timestamp |
| `TrialsState.swift` | `WeeklyVowCompletionLedgerEntry` — per-performance-log record of a vow step completion and its bonus payload |
| `TrialCard.swift` | `WeeklyVowPrescription` — placement and rep/set prescription that defines what the user must do to satisfy a vow |
| `TrialCardKind.swift` | `WeeklyVowKind` enum — the three vow slots in the weekly trio (ember / overdrive / apex) |
| `TrialCapstone.swift` | `WeeklyVowProof` and `WeeklyVowProofEvaluation` — the proof attached to a vow and how it is verified |
| `TrialTheme.swift` | `WeeklyVowTheme` — axis-locked or wildcard flavor that defines which attribute a vow targets |

### Where to find X

- **Add or change vow slot types** → `TrialCardKind.swift`
- **Change how a vow is verified** → `TrialCapstone.swift`
- **Change vow axis targeting** → `TrialTheme.swift`
- **Read the user's current active vow** → `Trial.swift`
- **Record a completed vow step** → `TrialsState.swift`
