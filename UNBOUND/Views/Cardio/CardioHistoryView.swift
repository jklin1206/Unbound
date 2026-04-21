import SwiftUI

struct CardioHistoryView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var sessions: [CardioSession] = []
    @State private var isLoading = true
    @State private var showingLogger = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Color.unbound.accent)
            } else if sessions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Cardio History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingLogger = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.unbound.accent)
                }
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

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No cardio logged yet")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Track your runs, rides, and rows to build your Stamina stat.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            UnboundButton(title: "Log your first session", icon: "plus") {
                showingLogger = true
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }

    private func sessionRow(_ session: CardioSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: session.type.sfSymbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.unbound.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.type.displayName)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                HStack(spacing: 8) {
                    Text("\(session.durationMinutes) min")
                        .font(Font.unbound.captionS)
                    if let km = session.distanceKm {
                        Text("·")
                        Text(String(format: "%.1f km", km))
                            .font(Font.unbound.captionS)
                    }
                    Text("·")
                    Text("RPE \(session.perceivedEffort)")
                        .font(Font.unbound.captionS)
                }
                .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
            Text(relative(session.date))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        sessions = await services.cardioLog.all(userId: userId)
        isLoading = false
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            Task {
                try? await services.cardioLog.delete(id: session.id)
            }
        }
        sessions.remove(atOffsets: offsets)
    }
}
