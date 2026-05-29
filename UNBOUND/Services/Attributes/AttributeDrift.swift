import Foundation

enum AttributeDrift {
    /// Idle days after which an axis is honestly flagged "stale" (a pure
    /// recency signal off `lastContributionAt` — `xp` never decays, so rank
    /// is never lost).
    static let graceDays: Double = 7

    /// Project `profile` forward to `date`. `xp` is permanent and never
    /// decays, so this only stamps `computedAt`. Pure — no IO.
    static func project(_ profile: AttributeProfile, to date: Date) -> AttributeProfile {
        var out = profile
        out.computedAt = date
        return out
    }
}
