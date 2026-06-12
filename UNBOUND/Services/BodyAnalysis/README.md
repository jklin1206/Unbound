# Services/BodyAnalysis

Provides two distinct analysis surfaces: on-device body-shape inference via Apple's Vision framework (`LocalBodyInsightsService`), and flavor-copy generation for a user's earned Build Identity via `BodyAnalysisService`. The old LLM-based body grading pipeline has been fully removed; this module never grades or scores the user's body.

| File | Purpose |
|------|---------|
| `BodyAnalysisServiceProtocol.swift` | Protocol declaring the single `flavorCopy(for:)` method; enforces the "AI never grades the body" rule in the type system |
| `BodyAnalysisService.swift` | Production conformer that delegates to `ScanPayoffFlavorService.shared` to generate one-line Build Identity flavor copy backed by Anthropic Haiku |
| `MockBodyAnalysisService.swift` | Test-only conformer that returns a fixed placeholder string; used to inject into previews and unit tests |
| `LocalBodyInsightsService.swift` | On-device Vision-based analyzer that extracts shoulder/hip ratio, torso/leg ratio, frame category, and posture flags from a front-facing photo; gracefully returns `nil` if keypoints are below confidence threshold |
| `BodyAnalysisPrompt.swift` | Empty enum stub retained for source compatibility; the old LLM grading prompt has been removed and flavor copy is now fully handled by `ScanPayoffFlavorService` |

## Where to find X

| Task | File |
|------|------|
| Generate flavor copy for a Build Identity | `BodyAnalysisService.swift` |
| Run on-device body-shape inference from a photo | `LocalBodyInsightsService.swift` |
| Inject a mock for tests or previews | `MockBodyAnalysisService.swift` |
| Add a new method to the body analysis contract | `BodyAnalysisServiceProtocol.swift` |
