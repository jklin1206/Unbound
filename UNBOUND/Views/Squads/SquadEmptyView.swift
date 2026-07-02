// UNBOUND/Views/Squads/SquadEmptyView.swift
import SwiftUI

struct SquadEmptyView: View {
    var onSquadChanged: (() -> Void)?

    @State private var showingCreate = false
    @State private var showingJoin = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 34)

                    Image("SquadCrest")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 244, height: 244)
                        .opacity(0.92)
                        .accessibilityHidden(true)
                        .frame(height: 248)

                    VStack(spacing: 10) {
                        Text("Train with your crew.")
                            .font(Font.unbound.displayM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        Text("Real friends only. Train together, push the same weekly mission, and settle 1v1 challenges.")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)

                    MetaLine(["Up to 10 crew", "linked-session XP boosts", "weekly missions"])

                    VStack(spacing: 12) {
                        UnboundButton(title: "Create a squad", icon: "plus") {
                            showingCreate = true
                        }
                        UnboundButton(title: "Join with invite code", variant: .secondary, icon: "person.badge.plus") {
                            showingJoin = true
                        }
                    }

                    Spacer().frame(height: 96)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateSquadSheet(onCompleted: onSquadChanged)
        }
        .sheet(isPresented: $showingJoin) {
            JoinSquadSheet(onCompleted: onSquadChanged)
        }
    }

}

#Preview {
    SquadEmptyView()
        .background(Color.unbound.bg)
}
