# Views/Scan

The progress-photo / scan ceremony: capture flow (daily photo or monthly checkpoint scan), consent gating, cadence gating, and the payoff cards (first-scan arc vs Nth-scan evolution). Scans are ceremonial proof — they never grade the body or feed program generation.

## Files

| File | What it is |
|---|---|
| `PhotoCaptureFlow.swift` | Enum-driven fullScreenCover from Home/Profile: `.photo` daily ritual (camera → review → confirm → save `ProgressPhoto` → +5 LVL XP deduped per day) and the checkpoint scan path; also posts scan notifications. |
| `ScanConsentModal.swift` | One-time consent before the first monthly checkpoint (photo saved as proof, never body-graded); persisted in `@AppStorage("unbound.scanConsentGranted")`. |
| `ScanCadenceGate.swift` | `ScanCadenceState` pure value — computes when the next checkpoint window opens (consumed by Home + Profile scan entry points). |
| `FirstScanArcCard.swift` | First-scan payoff: photo + seeded hex + narrative + 30-day cadence anchor; NO grading or strengths/weaknesses. |
| `NthScanEvolutionCard.swift` | Nth-scan payoff: before/after split + delta card + evolution narrative; regressions show as quiet "Watch signal" pills, never negative numbers. |
| `ScanBuildDeltaCard.swift` | `ScanBuildDeltaCard` — the per-axis build delta card used by the Nth-scan payoff. |
| `ScanPayoffView.swift` | `ScanPayoffView` host + `ScanPhotoLoader` + `AttributeProfile` helpers — routes to the right payoff card. |

## Where to find X

- **The capture → review → save pipeline** → `PhotoCaptureFlow.swift`.
- **When the scan tile/CTA unlocks** → `ScanCadenceGate.swift`.
- **First scan vs later scans presentation** → `ScanPayoffView.swift` routing into `FirstScanArcCard.swift` / `NthScanEvolutionCard.swift`.
- **Consent prompt logic** → `ScanConsentModal.swift`.
- **Entry points** → `UNBOUND/Views/Profile/ProfileScanRow.swift` and `PhotoCalendarView.swift`.
