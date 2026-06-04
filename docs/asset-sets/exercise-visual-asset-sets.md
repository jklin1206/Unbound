# Exercise Visual Asset Sets

The app has three exercise visual modes:

- `jot`: prefers `exercise_visual_jot_*` assets, then falls back to the root `exercise_visual_*` asset.
- `legacy`: prefers `exercise_visual_legacy_*` assets, then falls back to the root `exercise_visual_*` asset.
- `current`: uses only the root `exercise_visual_*` asset names.

`jot` is the default. DEBUG builds can switch this in Settings -> Dev Player Tools -> Exercise Visuals. Schemes can override the picker with:

```sh
UNBOUND_EXERCISE_VISUAL_SET=jot
UNBOUND_EXERCISE_VISUAL_SET=legacy
UNBOUND_EXERCISE_VISUAL_SET=current
```

Run this after a new generated exercise-visual batch:

```sh
python3 scripts/organize_exercise_visual_sets.py
```

The script writes:

- `UNBOUND/Assets.xcassets/ExerciseVisualsJot/`
- `UNBOUND/Assets.xcassets/ExerciseVisualsLegacy/`
- `docs/asset-sets/exercise-visual-asset-sets.json`

The root asset names stay in place for compatibility with existing runtime paths.
