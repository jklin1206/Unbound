// UNBOUND/Views/Squads/SquadEmptyView.swift
import SwiftUI

struct SquadEmptyView: View {
    @State private var showingCreate = false
    @State private var showingJoin = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 60)
                Image(systemName: "figure.2")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.unbound.accent)
                Text("Train with your crew.")
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("3–8 athletes. Linked workouts earn XP boosts. Real friends only.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button { showingCreate = true } label: {
                        Text("Create a squad").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    Button { showingJoin = true } label: {
                        Text("Join with invite code").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                Spacer()
            }
        }
        .sheet(isPresented: $showingCreate) { CreateSquadSheet() }
        .sheet(isPresented: $showingJoin) { JoinSquadSheet() }
    }
}

#Preview {
    SquadEmptyView()
        .background(Color.unbound.bg)
}
