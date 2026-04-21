# UNBOUND Illustration Assets

Generated via Gemini "nano banana" image editing. Until these land in the bundle, the onboarding screens render SF Symbol silhouette fallbacks (functional but not premium).

## Style directive (use for every generation)

> Bone-white (#F5F5F4) silhouette on transparent background. Premium fitness-app body illustration with subtle anatomy shading. ~1024 px tall PNG @ 2x and 3x. No character likenesses or IP. Anime-inspired build cues through hair silhouette and stance only — insiders clock the reference, outsiders see a fitness archetype.

## Assets needed

### `Archetypes/` — Screen 4 (5 cards)

Asset name in code: `Archetype_<NAME>` (already referenced by `ArchetypePickerCard`).

| File                    | Build cue             | Hair / stance reference           |
| ----------------------- | --------------------- | --------------------------------- |
| `Archetype_BRUTE.png`   | Tall, dense muscle    | Toji — spiky short black hair, hands in pockets stance |
| `Archetype_UNIT.png`    | Mass monster, broad   | Zoro — green spiky hair, wide stance, arms crossed |
| `Archetype_LEANCUT.png` | Balanced hero athlete | Goku — spiky medium hair, power-stance |
| `Archetype_CALISTHENIC.png`  | Compact, shredded     | Levi — medium hair side-part, precise stance |
| `Archetype_VTAPER.png`  | Tall, broad → narrow  | Jin-Woo — clean silhouette, aesthetic ideal |

### `BodyTypes/` — Screen 10 (3 cards)

| File                       | Reference                 |
| -------------------------- | ------------------------- |
| `BodyType_Skinny.png`      | Lean frame, low muscle    |
| `BodyType_SkinnyFat.png`   | Soft look without density |
| `BodyType_AlreadyLifting.png` | Training experience present |

### `BodyMap/` — Screen 27 + Day 2 verdict

- `BodyMap_Front.png` — bone-white front silhouette, full body
- `BodyMap_Back.png` — bone-white back silhouette, full body
- Region masks (for violet tint overlays): `BodyMap_Region_Chest.png`, `BodyMap_Region_Back.png`, `BodyMap_Region_Shoulders.png`, `BodyMap_Region_Arms.png`, `BodyMap_Region_Core.png`, `BodyMap_Region_Legs.png`

## Bundling

After generation:
1. Drop the PNGs into an `Assets.xcassets` image set (or keep them in `Resources/` as raw files — both work with `UIImage(named:)`)
2. Run `xcodegen generate` to pick up new file references
3. `UIImage(named:)` in `ArchetypePickerCard.swift` / body-type screens will automatically use the real assets when present, falling back to SF Symbols otherwise
