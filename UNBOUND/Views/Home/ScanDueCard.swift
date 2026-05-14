import SwiftUI

// MARK: - ScanDueCard
//
// Home contextualStack card that appears when the user is due (or overdue)
// for their monthly scan, or has never scanned at all.
//
// Shown only when `cadenceState.isUnlocked || isFirstScan`.
// Tapping opens PhotoCaptureFlow via the parent's showScanCaptureFlow binding.

struct ScanDueCard: View {
    let cadenceState: ScanCadenceState
    let isFirstScan: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(subline)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var headline: String {
        isFirstScan ? "Capture your starting line." : "Time for your monthly scan."
    }

    private var subline: String {
        isFirstScan
            ? "1 photo · 30 seconds · on-device only"
            : "30 days since last scan"
    }
}
