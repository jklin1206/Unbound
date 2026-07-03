# Services/BodyAnalysis

On-device body-shape inference via Apple's Vision framework (`LocalBodyInsightsService`). The old LLM-based body grading pipeline has been fully removed; this module never grades or scores the user's body.

| File | Purpose |
|------|---------|
| `LocalBodyInsightsService.swift` | On-device Vision-based analyzer that extracts shoulder/hip ratio, torso/leg ratio, frame category, and posture flags from a front-facing photo; gracefully returns `nil` if keypoints are below confidence threshold |

## Where to find X

| Task | File |
|------|------|
| Run on-device body-shape inference from a photo | `LocalBodyInsightsService.swift` |
