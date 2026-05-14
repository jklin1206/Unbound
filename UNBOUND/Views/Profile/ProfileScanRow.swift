import SwiftUI

// MARK: - ProfileScanRow
//
// Profile page entry point for the scan flow. Shows last-scan date or
// first-scan CTA. Tapping opens PhotoCaptureFlow via the parent's
// showScanCaptureFlow presentation state.
//
// If the cadence window hasn't opened yet and a scan exists, the parent
// shows a confirmationDialog before presenting the flow.

struct ProfileScanRow: View {
    let lastScanDate: Date?
    let cadenceState: ScanCadenceState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(detailText)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private var detailText: String {
        if lastScanDate == nil { return "Capture your starting line." }
        if cadenceState.isUnlocked { return "Ready" }
        return "Next window in \(cadenceState.daysUntilNext) days"
    }
}
