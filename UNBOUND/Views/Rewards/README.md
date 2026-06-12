# Views/Rewards

Rewards vault and Arc Shop: browse earned/locked cosmetics, purchase shop items with Arc currency, equip backdrops, and preview skill-tree skins.

| File | Purpose |
|------|---------|
| `RewardsVaultView.swift` | Read-only rewards map: all titles, skins, profile cosmetics, and badges with earned/locked state and "Next up" hooks |
| `ShopView.swift` | Arc Shop: category tabs (backdrop, border, title, skin), wallet balance, purchase and equip flow |
| `ShopItemCard.swift` | Single shop item card: preview artwork, owned/equipped/can-afford states, action button |
| `BackdropPickerView.swift` | Backdrop picker for home-poster vs profile-banner surfaces via `ShopBackdropSurface` |
| `ShopSkillTreePreview.swift` | `ShopPreviewLinework` — decorative linework canvas used in shop item preview cards |

## Where to find X

| Task | File |
|------|------|
| Change the rewards vault layout or "Next up" logic | `RewardsVaultView.swift` |
| Modify shop item card appearance or purchase flow | `ShopItemCard.swift` + `ShopView.swift` |
| Edit the backdrop picker (home vs profile surface) | `BackdropPickerView.swift` |
| Adjust shop category tabs or wallet display | `ShopView.swift` |
