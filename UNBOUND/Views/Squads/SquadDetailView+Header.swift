// UNBOUND/Views/Squads/SquadDetailView+Header.swift
import SwiftUI

extension SquadDetailView {
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
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.unbound.surfaceElevated))
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change squad crest")
        } else {
            crestMark(size: size, logoId: squad.logoId)
        }
    }
}
