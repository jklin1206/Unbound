import SwiftUI

struct StaminaCardView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var stat: StaminaStat = .empty
    @State private var hasSessions = false
    @State private var showingLogger = false
    @State private var showingHistory = false

    var body: some View {
        Group {
            if hasSessions {
                NavigationLink {
                    CardioHistoryView()
                        .environmentObject(services)
                } label: {
                    loadedCard
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showingLogger = true
                } label: {
                    emptyCard
                }
                .buttonStyle(.plain)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingLogger) {
            LogCardioView { _ in
                Task { await load() }
            }
            .environmentObject(services)
        }
    }

    private var loadedCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(Color.unbound.border, lineWidth: 2)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: CGFloat(stat.value) / 100.0)
                    .stroke(
                        Color.unbound.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.unbound.accent.opacity(0.5), radius: 6)
                Text("\(stat.value)")
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("STAMINA")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(stat.tier.displayName)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                trendRow
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private var trendRow: some View {
        HStack(spacing: 4) {
            if stat.weeklyTrend > 0.05 {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text(String(format: "+%d%% vs last wk", Int((stat.weeklyTrend * 100).rounded())))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.accent)
            } else if stat.weeklyTrend < -0.05 {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.alert)
                Text(String(format: "%d%% vs last wk", Int((stat.weeklyTrend * 100).rounded())))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.alert)
            } else {
                Text("Steady")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
    }

    private var emptyCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.unbound.accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text("Log your first cardio")
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Build your Stamina stat — run, bike, row.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
        )
    }

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let sessions = await services.cardioLog.all(userId: userId)
        hasSessions = !sessions.isEmpty
        stat = StaminaCalculator.compute(sessions: sessions)
    }
}
