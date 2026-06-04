# Attributes

Attributes are the six-axis hex. They answer "what kind of athlete is this user becoming?"

## Active Model

Each axis is one XP-backed value with a level curve and a hex fill. Movement work fans out through movement attribute weights. Catch-up multipliers make neglected axes rewarding without pretending every user should be perfectly balanced.

## Owners

- `UNBOUND/Models/AttributeValue.swift`: stored axis value.
- `UNBOUND/Models/AttributeProfile.swift`: profile view of all axes.
- `UNBOUND/Services/Attributes/AttributeIngest.swift`: XP fan-out math.
- `UNBOUND/Services/Attributes/AttributeService.swift`: persistence and reward deltas.
- `UNBOUND/Views/Components/AttributeHex.swift`: visual hex rendering.

## Cleanup Notes

Avoid old 0-100 score language and duplicate rank titles. Display should come from level/XP, not a parallel scale.
