import SwiftUI

struct ProgramOverviewTopBar: View {
    var body: some View {
        HStack {
            Text("QUEST BOARD")
                .font(Font.unbound.titleS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

struct ProgramOverviewTabSelector: View {
    @Binding var selectedTab: ProgramOverviewView.Tab

    var body: some View {
        HStack(spacing: 0) {
            tabChip(.program, label: "DAILY")
            tabChip(.myWorkouts, label: "LOADOUTS")
            tabChip(.routines, label: "DUNGEONS")
        }
    }

    private func tabChip(_ tab: ProgramOverviewView.Tab, label: String) -> some View {
        let isActive = selectedTab == tab
        return Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 0) {
                Text(label)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textPrimary.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                Rectangle()
                    .fill(isActive ? Color.unbound.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProgramRecoveryCompletionOverlay: View {
    var body: some View {
        ZStack {
            Color.unbound.bg.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(Color.unbound.rankGold)
                    .scaleEffect(1.12)
                Text("LOCKING RECOVERY")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.rankGold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.rankGold.opacity(0.32), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("program.recoveryCompleting")
    }
}

struct ProgramLoadingStateView: View {
    var body: some View {
        ProgressView()
            .tint(Color.unbound.accent)
            .frame(maxHeight: .infinity)
    }
}

struct ProgramNoProgramState: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No daily quest yet")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Complete onboarding to forge your first training arc.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgramSubscriptionBanner: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.unbound.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock the full quest board")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Subscribe to access daily quests and recovery.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProgramErrorStateView: View {
    let error: Error?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.unbound.alert)
            Text(error?.localizedDescription ?? "Daily quest unavailable.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(Font.unbound.bodyS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(
                        Capsule()
                            .fill(Color.unbound.accent.opacity(0.22))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("program.retry")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
