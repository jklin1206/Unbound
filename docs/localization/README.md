# Localization

UNBOUND uses a small localization boundary so UI copy, model display names,
notifications, errors, and generated user-facing copy can move to translation
incrementally.

## Source Files

- `UNBOUND/Resources/Localizable.xcstrings` is the English source catalog.
- `UNBOUND/Resources/en.lproj/InfoPlist.strings` localizes system strings such
  as camera and photo library permission prompts.
- `UNBOUND/Utilities/Localization/L10n.swift` is the app-facing helper.
- `scripts/localization_audit.sh` lists the next hardcoded strings and manual
  date/number formatting sites to migrate.

## Rules

1. Keep persistence and analytics identifiers as raw stable strings.
2. Put user-visible copy behind `L10n.string(_:defaultValue:)`.
3. Add typed `L10n.Key` cases for strings used from models, services,
   notifications, errors, and shared components. For large repeated catalogs
   such as onboarding answer enums, use structured dynamic keys through
   helpers like `L10n.onboardingAnswer(...)` and cover the key shape in tests.
4. Use dotted keys by domain, for example
   `notification.workout.morning.title` or `cardio.type.run.displayName`.
5. For strings with runtime values, add a key with placeholders and call
   `L10n.format(_:defaultValue:_:)`.
6. Prefer Foundation locale-aware formatters over manual `String(format:)`
   when rendering numbers, dates, measurements, or currency.

## Migration Order

Move copy in this order so the app becomes localizable without a risky
all-at-once rewrite:

1. App/system strings: Info.plist permissions, subscription/paywall, settings.
2. Scheduled/offline copy: local notifications, errors, empty states.
3. Core product flows: onboarding, scan, program, workout logging.
4. Reusable content: exercise names, routine names, badge/reward copy.
5. Generated content prompts and fallback text.

SwiftUI literal `Text("...")` values can be migrated gradually. When copy must
also be used outside SwiftUI, prefer `L10n.string` so views and services share
the same key.

## Current Coverage

The first migration pass covers:

1. App/system strings and permission prompts.
2. Subscription hard gate, paywall placeholder, package picker, and restore
   purchase states.
3. Auth shell, Apple sign-in, email sign-in, and legal links.
4. Release-facing settings and notification preferences.
5. App errors, scheduled workout/rescan notifications, cardio type names,
   weekday short labels, workout time labels, and training weight unit labels.
6. Onboarding answer catalogs for shared enum-backed options.
7. Primary scan/photo capture flow copy, scan consent, cadence gate, first
   scan payoff, and later-scan evolution cards.
8. Shared build attribute vocabulary, build identity display/tagline templates,
   and deterministic scan narrative fallbacks.
9. Compact onboarding screen copy: welcome/how-it-works, RPE loop demo,
   name, notifications, training-day selection, onboarding paywall, arc intro,
   early arc problem/path screens, onboarding scan live/review/analyzing, and
   social proof.
10. Additional onboarding story screens: problem opening/restart loop/fix,
    skill-tree preview, and projected trajectory.
11. Onboarding container chrome, results snapshot, plan-ready card,
    obstacle-fix paths, and the Day Zero verdict/dossier surface.

The next high-value areas are remaining story cards, program/workout copy,
live AI prompt localization strategy, and reusable content catalogs such as
exercises, routines, badges, cosmetics, and skill tree nodes. The onboarding
audit should now mostly show numeric/date formatting residues rather than
English copy.

Run the audit from the repository root with:

```sh
UNBOUND/scripts/localization_audit.sh
```
