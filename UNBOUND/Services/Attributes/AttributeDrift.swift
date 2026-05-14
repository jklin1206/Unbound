import Foundation

enum AttributeDrift {
    static let graceDays: Double = 7
    static let decayWindowDays: Double = 30

    /// Project `profile` forward to `date`, applying gentle drift per axis.
    /// Pure — no IO, no persistence.
    static func project(_ profile: AttributeProfile, to date: Date) -> AttributeProfile {
        var out = profile
        for key in AttributeKey.allCases {
            let v = out.value(for: key)
            let floor = v.floor
            let daysIdle = max(0.0, date.timeIntervalSince(v.lastContributionAt) / 86_400.0)
            let effective = max(0.0, daysIdle - graceDays)
            let progress = min(1.0, effective / decayWindowDays)
            var updated = v
            updated.current = floor + (v.current - floor) * (1.0 - progress)
            // Lower clamp (`max(floor, ...)`) is load-bearing: AttributeValue has no
            // constructor invariant preventing `current < floor`, so a profile arriving
            // with sub-floor `current` would otherwise be pushed further below.
            // Upper clamp (`min(..., v.current)`) is cosmetic — guards floating-point
            // overshoot only.
            updated.current = max(floor, min(updated.current, v.current))
            out.set(key, updated)
        }
        out.computedAt = date
        return out
    }
}
