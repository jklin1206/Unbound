# Views/Rewards

The rewards economy surfaces: the read-only Rewards Vault (every cosmetic's earned-vs-locked state + unlock path), the Arc-currency Shop, and the backdrop picker.

## Files

| File | What it is |
|---|---|
| `ShopView.swift` | `ShopView` — the cosmetic shop screen. |
| `ShopItemCard.swift` | Shop item card + backdrop artwork preview + `ArcCurrencyAmount` price label. |
| `ShopSkillTreePreview.swift` | Miniature skill-tree map preview used to showcase tree skins in the shop (linework, rails, node models). |
| `BackdropPickerView.swift` | `BackdropPickerView` + tile — pick an owned backdrop. |

## Where to find X

- **Shop pricing/currency display** → `ShopItemCard.swift` (`ArcCurrencyAmount`).
- **Skin preview rendering in the shop** → `ShopSkillTreePreview.swift`.
- **Equipping (not browsing) cosmetics** → `UNBOUND/Views/Settings/SkinPickerView.swift` and `ProfileCosmeticsView.swift`.
- **Backdrop selection** → `BackdropPickerView.swift`; backdrop rendering machinery in `UNBOUND/Utilities/Extensions/UnboundBackdrops.swift`.
