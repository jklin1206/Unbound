# Post-Workout Photo + Workout-Tagged Gallery — Design

Date: 2026-06-19
Branch: `worktree-post-workout-photo`

## Goal

1. **Capture:** After finishing a workout, offer an opt-in "Add a photo" button on the
   final beat of the reward sequence. Tapping it takes a photo (camera; library fallback
   when no camera, e.g. simulator) and saves it tagged with the workout just finished.
2. **Display:** In the existing Profile photo library, a photo taken after a workout shows
   **the workout you accomplished** alongside it — workout name, date · duration, and the
   exercises/sets done. **No XP / gamification framing.**

Photos stay **device-local**, consistent with the entire existing photo subsystem
(`progressPhotos` is unmapped in `SyncCollectionMap`, so it never upserts to Supabase).
Cloud/Supabase Storage upload remains a separate, out-of-scope task.

## The one real gap

There is no link today between a `ProgressPhoto` and a workout. We close it by storing a
small **denormalized snapshot** of the workout on the photo at capture time — no foreign
key, no fetch/join at gallery time, and resilient to the source workout later being edited
or deleted (the photo is a moment-in-time record).

## Data model

`WorkoutPhotoSummary` (new, `Models/Body/WorkoutPhotoSummary.swift`):

```swift
struct WorkoutPhotoSummary: Codable, Equatable, Hashable, Sendable {
    var title: String
    var completedAt: Date
    var durationMinutes: Int?
    var exercises: [String]   // compact "what you did", e.g. "Bench Press · 3×5"
}
```

- Factory `init(performanceLog:)` builds it from a `PerformanceLog`: title, completedAt,
  duration from `startedAt…completedAt`, and one compact line per non-skipped exercise
  (`Name · {workingSets}×{reps}`, `…×{holds}s`, or `… · {n} sets`; light cardio fallback).
  Weight is intentionally omitted to avoid kg/lb unit complexity.

`ProgressPhoto` (extend, `Models/Body/ProgressPhoto.swift`):

- Add `case workout` to `Source`.
- Add `var workout: WorkoutPhotoSummary?` (new init param, default `nil`).
- Migration-free: Codable decodes the absent key as `nil` on old rows. Local-only, so no
  server migration needed.

## Capture flow

- `WorkoutRewardSequenceSummary` gains `var workoutPhotoContext: WorkoutPhotoSummary? = nil`.
  Only the program training-completion path populates it; all other reward presenters
  (skill, cardio, routine, quick-log, demos) leave it nil → no photo button there in v1.
- `WorkoutRewardSequenceView` gains `var onAddWorkoutPhoto: ((UIImage) -> Void)? = nil`.
  When `summary.workoutPhotoContext != nil && onAddWorkoutPhoto != nil`, the `finalYield`
  beat shows an "Add a photo" button. The view stays decoupled from `ServiceContainer`
  (other call sites don't inject it) — it only presents the picker and hands the image back.
- Tap → camera (`CameraPicker`, `UIImagePickerController`) when available, else
  `PhotosPicker` library fallback. On pick, button flips to "Photo added" and the image is
  handed to the presenter.
- `ActiveWorkoutContainerView` owns the save (it has `services` + the `PerformanceLog`):
  build `workoutPhotoContext` from the log in `complete()`, pass `onAddWorkoutPhoto` that
  calls a new `saveWorkoutPhoto(_:context:)` (extension file). Save mirrors the established
  `PhotoCaptureFlow.savePhotoToDatabase` pattern: JPEG → `Documents/progress_<id>.jpg` →
  `ProgressPhoto(source: .workout, workout: context)` via `services.database.create`, then
  posts `.photoCaptured` so the gallery refreshes.

## Gallery display (existing photo library, no new screen)

Workout photos are `ProgressPhoto`s, so they already appear in `PhotoCalendarView`'s grid.

- `PhotoPreviewSheet`: when `photo.workout != nil`, render the workout under the image —
  title, `date · duration` meta line, and the exercise lines (bounded/scrollable). Keep the
  existing "Set as profile photo" / delete actions.
- Calendar cell + preview: a small workout glyph (dumbbell) for `source == .workout`,
  mirroring how `.scan` shows a sparkle badge.

## Permissions

`NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` already exist in `project.yml`.
Reword the camera string to cover progress/workout photos, not just "body scan".

## Testing

- `ProgressPhoto` Codable round-trips with and without `workout` (old-row decode → nil).
- `WorkoutPhotoSummary(performanceLog:)` produces correct title/duration/exercise lines,
  skips skipped exercises and warmup-only counting.
- Build (sim) + screenshot the reward final beat (button present) and the preview sheet.

## Out of scope (YAGNI)

Cloud/Supabase photo sync; a dedicated "Workout Photos" timeline screen; XP/gamification on
the gallery; sharing/export; offering the photo on skill/cardio/routine completion (v1 is the
program training path only).
