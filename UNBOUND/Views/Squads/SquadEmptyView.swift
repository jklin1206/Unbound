// UNBOUND/Views/Squads/SquadEmptyView.swift
import SwiftUI

struct SquadEmptyView: View {
    var onSquadChanged: (() -> Void)?

    @State private var showingCreate = false
    @State private var showingJoin = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.unbound.accent.opacity(0.16),
                    Color.unbound.warnOrange.opacity(0.06),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 340)
            .ignoresSafeArea(edges: .top)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 34)

                    ZStack {
                        Image("SquadCrest")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 244, height: 244)
                            .opacity(0.92)
                            .accessibilityHidden(true)

                        Circle()
                            .stroke(Color.unbound.accent.opacity(0.20), lineWidth: 1)
                            .frame(width: 210, height: 210)
                    }
                    .frame(height: 248)

                    VStack(spacing: 10) {
                        Text("Train with your crew.")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        Text("3-8 athletes. Linked workouts earn XP boosts. Real friends only.")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 8) {
                        emptyMetric("3-8", "CREW")
                        emptyMetric("XP", "BOOSTS")
                        emptyMetric("LIVE", "CHAT")
                    }

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

    private func emptyMetric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.unbound.surface.opacity(0.74)))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }
}

#Preview {
    SquadEmptyView()
        .background(Color.unbound.bg)
}
