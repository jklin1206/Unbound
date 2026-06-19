// UNBOUND/Views/Squads/SquadDetailView+Header.swift
import SwiftUI

extension SquadDetailView {
    var squadBackdrop: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color.unbound.accent.opacity(0.17),
                        Color.unbound.warnOrange.opacity(0.07),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 340)

                Image("SquadCrest")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(proxy.size.width * 0.74, 320))
                    .opacity(0.11)
                    .blendMode(.screen)
                    .offset(x: 78, y: -58)

                LinearGradient(
                    stops: [
                        .init(color: Color.unbound.bg.opacity(0.02), location: 0),
                        .init(color: Color.unbound.bg.opacity(0.72), location: 0.72),
                        .init(color: Color.unbound.bg, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 360)
            }
            .frame(width: proxy.size.width, height: 360, alignment: .top)
        }
        .frame(height: 360)
        .allowsHitTesting(false)
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            crestMark(size: 82, logoId: nil)
            Text("You're not in a squad.")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func crestMark(size: CGFloat, logoId: String?) -> some View {
        SquadLogoMarkView(logoId: logoId, size: size)
    }

    @ViewBuilder
    func editableCrestMark(squad: Squad, size: CGFloat) -> some View {
        if canEditSquad(squad) {
            Button {
                showLogoEditor = true
            } label: {
                crestMark(size: size, logoId: squad.logoId)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.unbound.bg)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.unbound.accent))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 1))
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(.plain)
        } else {
            crestMark(size: size, logoId: squad.logoId)
        }
    }
}
