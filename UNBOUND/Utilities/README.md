# Utilities

Cross-cutting helpers: app constants, sound/haptics, SVG parsing, and the `Extensions/` folder holding the Premium Hollow design-token system (colors, fonts, style modifiers, backdrops, native primitives). `Helpers/` has `HapticManager.swift` + `ImageCompressor.swift`; `Localization/` has `L10n.swift` (typed key enum over `Localizable.xcstrings`).

## Files

| File | What it is |
|---|---|
| `AppConstants.swift` | `AppConstants` — RevenueCat/PostHog keys, terms/privacy URLs, cloud-function endpoints, limits. |
| `AppStoreReviewPrompt.swift` | `AppStoreReviewPrompt` — the two sanctioned rating asks (onboarding verdict reveal + one-shot after first real workout). |
| `SVGPathParser.swift` | Minimal SVG path-data parser (M/L/H/V/C/S/Q/T/A/Z) for the body-highlighter asset paths. |
| `UnboundSound.swift` | `SoundEffect` + `UnboundSound` — pooled reward/celebration SFX players (ambient session, pitch-rising XP tick). |
| `Extensions/Color+Unbound.swift` | THE color namespace: `Color.unbound` Premium Hollow tokens (legacy `Color.theme` bridge is deleted). |
| `Extensions/Color+Hex.swift` | `Color(hex:)` initializer. |
| `Extensions/Font+Unbound.swift` | `Font.unbound` typography tokens (display/body/numbers, with fallbacks). |
| `Extensions/Font+Theme.swift` | Legacy semantic font helpers (`headline`, `bodyText`, `stat`, …). |
| `Extensions/View+UnboundStyle.swift` | Premium Hollow ViewModifiers (`UnboundCardStyle`, pressable, hero fade) + `UnboundHaptics`. |
| `Extensions/UnboundNativePrimitives.swift` | Shared screen furniture: dividers, scroll chrome, section headers, metric rails, row buttons (split from View+UnboundStyle). |
| `Extensions/UnboundBackdrops.swift` | Backdrop art presentation + adaptive text-legibility machinery (scrims, shields, tone analysis, shadows). |
| `Extensions/View+Loading.swift` | `.loadingOverlay(_:)` view helper. |
| `Extensions/Date+Formatting.swift` | `Date.formatted(as:)` + `timeAgo`. |
| `Extensions/FileManager+Documents.swift` | `documentsDirectory` convenience. |
| `Extensions/Image+Compression.swift` | `UIImage.compressed(maxWidth:quality:)`. |
| `Helpers/HapticManager.swift` | Static impact/notification/selection haptic triggers. |
| `Helpers/ImageCompressor.swift` | Iterative-quality image compression on top of `UIImage.compressed`. |
| `Localization/L10n.swift` | Typed localization keys — every key needs a real `Localizable.xcstrings` entry or `LocalizationTests` fails. |

## Where to find X

- **A color or font token** → `Extensions/Color+Unbound.swift` / `Extensions/Font+Unbound.swift`.
- **Card/pressable/hero styling modifiers** → `Extensions/View+UnboundStyle.swift`; section headers/dividers/rails → `Extensions/UnboundNativePrimitives.swift`.
- **Backdrop rendering + text legibility over art** → `Extensions/UnboundBackdrops.swift`.
- **Haptics** → `UnboundHaptics` in `Extensions/View+UnboundStyle.swift` (design-language beats) or `Helpers/HapticManager.swift` (raw UIKit triggers).
- **Sounds** → `UnboundSound.swift`.
- **Adding user-facing copy** → `Localization/L10n.swift` + `Resources/Localizable.xcstrings` (edit as text, never reformat).
