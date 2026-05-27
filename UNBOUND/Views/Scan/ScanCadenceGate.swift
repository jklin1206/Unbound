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

/// Soft-lock card shown when the user opens the scan from home before
/// the 30-day cadence has elapsed. Includes a tertiary "Scan anyway"
/// override so power users aren't blocked.
struct ScanCadenceGate: View {
    let state: ScanCadenceState
    let onProceed: () -> Void
    let onOverride: () -> Void

    var body: some View {
        if state.isUnlocked {
            // Defer rendering to the parent — the parent should bypass the gate.
            Color.clear.onAppear(perform: onProceed)
        } else {
            VStack(spacing: 24) {
                Spacer()
                Text(L10n.string(.scanCadenceNextCheckpointIn, defaultValue: "NEXT CHECKPOINT IN"))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(L10n.format(.scanCadenceDaysRemaining, defaultValue: "%d DAYS", state.daysUntilNext))
                    .font(Font.unbound.displayM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .tracking(2)
                Text(L10n.string(.scanCadenceBody, defaultValue: "Monthly cadence keeps the change visible."))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button(action: onOverride) {
                    Text(L10n.string(.scanCadenceOverride, defaultValue: "Scan anyway"))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .underline()
                }
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.unbound.bg.ignoresSafeArea())
        }
    }
}
