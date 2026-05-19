# Profile Photo — Design Spec

**Date:** 2026-05-19
**Status:** Approved (user said "do the above"); proceed to plan + implement.
**Branch:** program-redesign

## Problem

The avatar circle (`CosmeticAvatar`) can render a photo (`image: UIImage?`) but
nothing ever sets it — both call sites (`ProfileView:211`, `UnboundHomeView:1371`)
hardcode `image: nil`, so it always shows a letterform. There is no way for a
user to set a profile picture. Users want to take or pick a photo as their
profile pic; absent one, the default should be a generic purple placeholder
(not a letter, not a character).

## Scope

**In:**
- Default empty state = flat UNBOUND-violet placeholder with a faint
  `person.fill` glyph. No letter.
- Tap the Profile-header avatar → confirmation dialog: **Take Photo** (camera),
  **Choose from Library** (`PhotosPicker`), **Remove Photo** (only when one is
  set).
- Picked/taken image downscaled to ≤512px, stored as JPEG locally, keyed by
  userId.
- Both Profile and Home avatars reflect the photo and update live.
- Camera + photo-library Info.plist usage strings.

**Out (deliberate, not v1):**
- Cloud sync / restore of the photo (device-local for now; later follow-up,
  consistent with the offline-first model).
- Character/archetype gallery.
- Crop/zoom UI (`CosmeticAvatar` already circle-clips with `.fill`).
- Any ad-screenshot work.

## Architecture

Single new service + one component change + two wiring points.

- **`ProfilePhotoStore`** (`@MainActor`, `ObservableObject`, `.shared`):
  - `image(userId:) -> UIImage?` — cached read of
    `Documents/ProfilePhoto/<userId>.jpg`.
  - `set(_ image: UIImage, userId:)` — downscale longest side ≤512px,
    JPEG (q≈0.85), atomic write, `@Published var revision` bump.
  - `remove(userId:)` — delete file, bump `revision`.
  - Local-only. No outbox/Storage in v1.
- **`CosmeticAvatar`** (`RankCosmetics.swift`): empty-state branch renders the
  purple placeholder instead of the letter. `letterFallback` param retained for
  source compatibility but unused by the new empty state.
- **`ProfileView`**: avatar wrapped in a `Button` → `confirmationDialog`.
  Camera via a `UIImagePickerController` `UIViewControllerRepresentable`
  (`.camera`); library via `PhotosPicker` (PhotosUI). On selection: load →
  `ProfilePhotoStore.set`. Header reads
  `ProfilePhotoStore.shared.image(userId:)` (observes `revision`).
- **`UnboundHomeView:1371`**: pass
  `ProfilePhotoStore.shared.image(userId:)`; observe the store so it refreshes.

## Data Flow

Pick/Take → `UIImage` → `ProfilePhotoStore.set` (downscale + atomic JPEG write
+ `revision++`) → Profile & Home observe `revision` → `CosmeticAvatar(image:)`
re-renders. Remove → file deleted → avatars fall back to purple placeholder.

## Error Handling

- Camera/library permission denied → iOS handles the prompt; on denial the
  dialog simply does nothing (no crash; usage strings present so no hard crash).
- Decode/scale failure → no-op, prior photo retained, logged via
  `LoggingService`.
- Corrupt/missing file on read → returns nil → purple placeholder. Never throws
  to the UI.

## Testing

- `ProfilePhotoStore`: set writes a ≤512px JPEG; image() returns it; remove()
  deletes and image() returns nil; per-userId isolation; survives re-init
  (temp dir).
- Downscale: a >512px image is scaled so max side ≤512; aspect preserved.
- `CosmeticAvatar`: with nil image renders placeholder (no letter); with image
  renders the image.

## Success Criteria

1. Fresh user: Profile + Home show the purple placeholder (no letter).
2. Take Photo or Choose from Library sets a pic; it appears immediately in both
   Profile and Home, circle-cropped, inside the rank frame.
3. Remove Photo reverts both surfaces to the purple placeholder.
4. The photo persists across app relaunch (local file).
5. No camera/library crash (Info.plist usage strings present).
6. No code path hardcodes `image: nil` at the two call sites anymore.
