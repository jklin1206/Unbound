// UNBOUND/Views/Squads/SquadMissionPickSheet.swift
//
// Captain-only sheet listing the 5 co-op mission kinds.
// Tap a kind → calls onPick and dismisses.
import SwiftUI

struct SquadMissionPickSheet: View {
    let memberCount: Int
    let onPick: (SquadMission.Kind) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        CalmSectionHeader(title: "PICK THIS WEEK'S MISSION")
                        Text("Choose a co-op goal for your crew.")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(SquadMission.Kind.allCases, id: \.self) { kind in
                                kindRow(kind: kind)
                                if kind != SquadMission.Kind.allCases.last {
                                    Divider()
                                        .background(Color.unbound.surfaceElevated)
                                        .padding(.leading, 64)
                                }
                            }
                        }
                        .background(Color.unbound.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }

    private func kindRow(kind: SquadMission.Kind) -> some View {
        Button {
            onPick(kind)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.surfaceElevated)
                        .frame(width: 42, height: 42)
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(kind.subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text(kind.progressText(SquadMissionCatalog.target(for: kind, memberCount: memberCount)))
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SquadMissionPickSheet(memberCount: 4) { kind in
        print("Picked: \(kind)")
    }
}
