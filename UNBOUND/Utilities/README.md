# Utilities

App-wide constants, helpers, localization, and extensions. `Extensions/` holds design-token extensions (colors, fonts, View modifiers) and feature helpers; `Helpers/` holds UIKit utility enums; `Localization/` holds the L10n key catalog.

| File | Purpose |
|------|---------|
| `AppConstants.swift` | `AppConstants` — RevenueCat key, PostHog key, legal URLs, analytics opt-out key, API/limits constants |
| `SVGPathParser.swift` | `SVGPathParser` — minimal SVG path-data parser covering M/L/H/V/C/S/Q/T/A/Z commands (used for body-map SVG assets) |
| `UnboundSound.swift` | `SoundEffect` enum — pooled AVAudio reward/celebration SFX with rate-variable XP-tick; respects mute switch |
| `Extensions/Color+Hex.swift` | `Color(hex:)` initializer from 6- or 8-digit hex strings |
| `Extensions/Color+Unbound.swift` | `Color.unbound.*` Premium Hollow color token namespace (the single color source of truth) |
| `Extensions/Font+Unbound.swift` | `Font.unbound.*` typography token namespace (display/body/mono/monoS/etc.) |
| `Extensions/Font+Theme.swift` | Legacy `Font.headline/subheadline/bodyText/bodyMedium` convenience extensions |
| `Extensions/Date+Formatting.swift` | `Date.formatted(as:)` and `Date.timeAgo` helpers |
| `Extensions/FileManager+Documents.swift` | `FileManager.documentsDirectory` safe accessor |
| `Extensions/Image+Compression.swift` | `UIImage.compressed(maxWidth:quality:)` resize+JPEG helper |
| `Extensions/View+UnboundStyle.swift` | `UnboundCardStyle`, `unboundCard()`, and shared Premium Hollow `ViewModifier` suite |
| `Extensions/View+Loading.swift` | `View.loadingOverlay(_:)` — full-screen loading overlay modifier |
| `Extensions/UnboundNativePrimitives.swift` | `UnboundNativeDivider`, `UnboundSectionHeader`, metric rails, row buttons — Premium Hollow screen furniture |
| `Extensions/UnboundBackdrops.swift` | `BackdropPresentationRole`, backdrop art presentation, adaptive text-legibility scrims and tone analysis |
| `Extensions/UnboundNativePrimitives.swift` | Shared scroll chrome, section headers, MetaLine rows |
| `Helpers/HapticManager.swift` | `HapticManager` — `impact(_:)`, `notification(_:)`, `selection()` wrappers |
| `Helpers/ImageCompressor.swift` | `ImageCompressor.compress(image:maxWidth:quality:maxBytes:)` — iterative quality reduction to fit size budget |
| `Localization/L10n.swift` | `L10n.Key` enum of all localizable string keys + `L10n.string(_:defaultValue:)` lookup |

## Where to find X

| Task | File |
|------|------|
| Add or change a color token | `Extensions/Color+Unbound.swift` |
| Add or change a font token | `Extensions/Font+Unbound.swift` |
| Add a new localization key | `Localization/L10n.swift` + `Resources/Localizable.xcstrings` |
| Add a backdrop / scrim to a new screen | `Extensions/UnboundBackdrops.swift` |
| Use the shared card surface style | `Extensions/View+UnboundStyle.swift` |
| Trigger a haptic | `Helpers/HapticManager.swift` |
