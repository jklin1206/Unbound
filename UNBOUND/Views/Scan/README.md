# Views/Scan

Monthly checkpoint and daily photo capture flows: consent gate, camera, review, payoff cards (first scan vs Nth scan), cadence gating, and build-delta display.

| File | Purpose |
|------|---------|
| `PhotoCaptureFlow.swift` | Top-level enum-driven flow: `.photo` (daily ritual, +5 XP) vs `.scan` (monthly checkpoint, consent → camera → payoff → +25 XP) |
| `ScanCadenceGate.swift` | `ScanCadenceState` value type: computes `isUnlocked`, `daysUntilNext`, and `urgencyPulse` from `lastScanAt` |
| `ScanConsentModal.swift` | One-time consent modal (persisted via `@AppStorage("unbound.scanConsentGranted")`) |
| `ScanPayoffView.swift` | Router payoff view: shows `FirstScanArcCard` or `NthScanEvolutionCard` depending on prior checkpoint count |
| `FirstScanArcCard.swift` | First-scan payoff: "Your arc begins" — photo, seeded hex, 30-day cadence anchor |
| `NthScanEvolutionCard.swift` | Nth-scan payoff: before/after photo split + `ScanBuildDeltaCard`; regressed axes shown as "Watch signals", never negative |
| `ScanBuildDeltaCard.swift` | Axis-by-axis build delta card comparing first and latest `AttributeProfile` scans |

## Where to find X

| Task | File |
|------|------|
| Change the photo vs scan flow branching | `PhotoCaptureFlow.swift` |
| Modify cadence window length or urgency pulse | `ScanCadenceGate.swift` |
| Edit the first-scan "arc begins" payoff | `FirstScanArcCard.swift` |
| Edit the Nth-scan before/after payoff | `NthScanEvolutionCard.swift` |
| Change how axis deltas are displayed | `ScanBuildDeltaCard.swift` |
