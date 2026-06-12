# Views/Components/HUD

HUD-styled (sci-fi chrome) form controls and surfaces, used heavily by Onboarding and Calibration: chamfered panels, buttons, pickers, sliders, and inputs sharing one visual language.

## Files

| File | What it is |
|---|---|
| `ChamferedShape.swift` | `ChamferedRectangle` + `HUDHexagon` shapes — the base geometry of the language. |
| `HUDPanel.swift` | `HUDPanel<Content>` — chamfered container panel. |
| `HUDButton.swift` | `HUDButton` — primary HUD action button. |
| `HUDCallout.swift` | `HUDCallout` — callout/notice element. |
| `HUDSelectRow.swift` | `HUDSelectRow` — single-select row. |
| `HUDMultiSelectRow.swift` | `HUDMultiSelectRow` + generic `HUDMultiSelectGroup<T>`. |
| `HUDScrollPicker.swift` | `HUDScrollPicker<V>` — generic scroll-wheel value picker. |
| `HUDSlider.swift` | `HUDSlider` — styled slider. |
| `HUDProgressBar.swift` | `HUDProgressBar` — progress bar. |
| `HUDTextInput.swift` | `HUDTextInput` — text field. |
| `TechGridBackground.swift` | `TechGridBackground` — grid backdrop. |

## Where to find X

- **The chamfered-corner look** → `ChamferedShape.swift` (shapes) + `HUDPanel.swift` (container).
- **Single vs multi selection rows** → `HUDSelectRow.swift` / `HUDMultiSelectRow.swift`.
- **Numeric/value wheel picking** → `HUDScrollPicker.swift`.
- **Who uses these** → primarily `UNBOUND/Views/Onboarding/` (17 files) and `UNBOUND/Views/Calibration/` (5 files).
