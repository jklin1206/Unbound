# Models/Trials

Weekly Vow model types (the user's committed weekly challenge). Every type here is named `WeeklyVow*`; each file also declares a `Trial*` typealias for the legacy naming, which is how this folder got its name.

| File | Contents |
| --- | --- |
| `Trial.swift` | `WeeklyVow` (the committed vow for the current week) + `WeeklyVowState`; typealiases `Trial`, `CapstoneState`. |
| `TrialCard.swift` | `WeeklyVowPrescription` (with `Placement`) + `WeeklyVowCard` — the offered card a user can commit to; typealias `TrialCard`. |
| `TrialCardKind.swift` | `WeeklyVowKind` — the kinds of vow cards (Codable + helpers); typealias `TrialCardKind`. |
| `TrialsState.swift` | `WeeklyVowsState` overall state plus completion/penalty ledger entries; typealias `TrialsState`. |
| `TrialTheme.swift` | `WeeklyVowTheme` — visual/copy theme for a vow; typealias `TrialTheme`. |

## Where to find X

- The committed vow itself and its lifecycle state → `Trial.swift`.
- The card offers shown before committing → `TrialCard.swift`; kinds in `TrialCardKind.swift`.
- Persisted weekly-vow state + completion/penalty ledgers → `TrialsState.swift`.
