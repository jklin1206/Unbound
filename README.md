# UNBOUND

UNBOUND is the iOS app in this repository. If you are trying to understand where code lives, start here:

- [docs/FILE_STRUCTURE.md](docs/FILE_STRUCTURE.md) - repository and app folder map, asset tracing rules, cleanup checklist.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - current progression/ranking/logging architecture map.
- [AGENTS.md](AGENTS.md) - working rules for coding agents, verification, parallel lanes, and artifact hygiene.

Local generated files, previews, screenshots, videos, and scratch research belong in `LocalArtifacts/` or `exports/`. Durable docs belong in `docs/`. Shipped app assets belong in `UNBOUND/Assets.xcassets` or `UNBOUND/Resources` only when the app can load them.

## Local Verification Bootstrap

The Xcode project is generated from the checked-in project spec. From a clean checkout, run `xcodegen generate` before invoking `xcodebuild` if `UNBOUND.xcodeproj/project.pbxproj` is missing or stale.

Dependency locks are part of the review surface: keep `UNBOUND.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` and `deno.lock` in the PR whenever SwiftPM or Supabase function dependencies change.
