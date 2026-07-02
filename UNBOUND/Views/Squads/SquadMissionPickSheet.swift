// UNBOUND/Views/Squads/SquadMissionPickSheet.swift
//
// Captain-only sheet listing the 5 co-op mission kinds, each with its
// generated emblem and a tinted weekly target. Tap a kind → onPick + dismiss.
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
                        Text("One co-op goal for the crew. Every logged session pushes the bar; clearing it pays \(SquadRewardPolicy.missionArcs) Arcs.")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(SquadMission.Kind.allCases, id: \.self) { kind in
                                kindRow(kind: kind)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
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
        .preferredColorScheme(.dark)
    }

    private func kindRow(kind: SquadMission.Kind) -> some View {
        Button {
            onPick(kind)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                emblem(kind: kind)

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(kind.subtitle)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(kind.progressText(SquadMissionCatalog.target(for: kind, memberCount: memberCount)))
                        .font(Font.unbound.monoS)
                        .foregroundStyle(kind.tint)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                    Text("this week")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.displayName), target \(kind.progressText(SquadMissionCatalog.target(for: kind, memberCount: memberCount)))")
    }

    @ViewBuilder
    private func emblem(kind: SquadMission.Kind) -> some View {
        if UIImage(named: kind.emblemAssetName) != nil {
            Image(kind.emblemAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
        } else {
            ZStack {
                Circle().fill(kind.tint.opacity(0.16))
                Image(systemName: kind.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(kind.tint)
            }
            .frame(width: 52, height: 52)
        }
    }
}

// MARK: - Preview

#Preview {
    SquadMissionPickSheet(memberCount: 4) { kind in
        print("Picked: \(kind)")
    }
}
