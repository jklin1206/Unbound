import Foundation

/// Overall mode the progression engine runs in.
/// - `advance`: default — bump weights and tiers when criteria met.
/// - `preserve`: cut mode — hold weights, still record sessions. Tier unlocks
///   still fire (user can still hit reps/skill targets). Used when the user
///   has Cut mode enabled on their profile — preserves strength while in a
///   calorie deficit.
enum ProgressionMode {
    case advance
    case preserve
}
