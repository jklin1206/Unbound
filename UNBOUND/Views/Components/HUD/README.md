# Views/Components/HUD

HUD-flavored input and layout primitives used throughout onboarding and calibration: chamfered-edge panels, buttons, row selectors, scroll pickers, sliders, progress bars, and the ambient tech-grid background.

| File | Purpose |
|------|---------|
| `HUDPanel.swift` | `HUDPanel<Content>` — chamfered active/inactive container panel with optional breathing pulse animation |
| `HUDButton.swift` | `HUDButton` — animated glove-friendly button with optional icon; pulses on tap |
| `HUDCallout.swift` | `HUDCallout` — eyebrow + message info block with optional hex icon; used for context explanations |
| `HUDSelectRow.swift` | `HUDSelectRow` — single-select row wrapping `HUDPanel`; pulses when selected |
| `HUDMultiSelectRow.swift` | `HUDMultiSelectRow` — multi-select row with optional subtitle and icon |
| `HUDScrollPicker.swift` | `HUDScrollPicker<V>` — 3-visible-item drum scroll picker with snapped selection |
| `HUDSlider.swift` | `HUDSlider` — stepped or continuous horizontal slider with semantic descriptors and anchor labels |
| `HUDProgressBar.swift` | `HUDProgressBar` — mono-tile progress bar with step category eyebrow (onboarding progress indicator) |
| `HUDTextInput.swift` | `HUDTextInput` — monospace-styled text field with eyebrow label and focus-state accent |
| `ChamferedShape.swift` | `ChamferedRectangle` — `Shape` with chamfered (cut) corners; foundation for the HUD visual language |
| `TechGridBackground.swift` | `TechGridBackground` — slow-drifting grid lines canvas for the HUD ambient background |

## Where to find X

| Task | File |
|------|------|
| Build a selection list (onboarding question) | `HUDSelectRow.swift` or `HUDMultiSelectRow.swift` |
| Add a drum scroll picker for numeric input | `HUDScrollPicker.swift` |
| Use the chamfered container panel | `HUDPanel.swift` |
| Add the drifting tech-grid to a background | `TechGridBackground.swift` |
| Show onboarding step progress | `HUDProgressBar.swift` |
