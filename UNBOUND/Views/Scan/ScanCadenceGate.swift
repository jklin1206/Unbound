import SwiftUI

/// Pure value describing the home-tile + gate appearance at a given moment.
struct ScanCadenceState: Equatable {
    let isUnlocked: Bool
    let daysUntilNext: Int
    let urgencyPulse: Bool

    static func compute(lastScanAt: Date?, now: Date) -> ScanCadenceState {
        guard let last = lastScanAt else {
            return ScanCadenceState(isUnlocked: true, daysUntilNext: 0, urgencyPulse: false)
        }
        let elapsed = Int(now.timeIntervalSince(last) / 86400)
        if elapsed >= 30 {
            return ScanCadenceState(isUnlocked: true, daysUntilNext: 0, urgencyPulse: false)
        }
        let remaining = max(0, 30 - elapsed)
        let pulse = remaining <= 7
        return ScanCadenceState(isUnlocked: false, daysUntilNext: remaining, urgencyPulse: pulse)
    }
}

