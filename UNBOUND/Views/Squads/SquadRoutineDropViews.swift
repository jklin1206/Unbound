// UNBOUND/Views/Squads/SquadRoutineDropViews.swift
//
// A routine a crewmate shared, as a calm list row: title, author + facts as
// a MetaLine, and two quiet text actions (Save / Today). No cards-in-cards,
// no tinted panels.
import SwiftUI

struct SquadRoutineDropRow: View {
    let drop: SquadRoutineDrop
    let authorName: String
    let isMine: Bool
    let onSave: () -> Void
    let onUseToday: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// "now" under a minute — the formatter says "in 0s" for just-shared drops.
    private var relativeTime: String {
        if abs(drop.createdAt.timeIntervalSinceNow) < 60 { return "now" }
        return Self.relativeFormatter.localizedString(for: drop.createdAt, relativeTo: .now)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(Color.unbound.surfaceElevated)
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(drop.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)

                MetaLine([
                    isMine ? "You" : authorName,
                    relativeTime,
                    drop.exerciseCount > 0 ? "\(drop.exerciseCount) exercises" : nil,
                    drop.estimatedMinutes > 0 ? "\(drop.estimatedMinutes)m" : nil
                ])

                if let note = drop.note, !note.isEmpty {
                    Text(note)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            if !isMine {
                HStack(spacing: 4) {
                    quietAction("Save", action: onSave)
                    quietAction("Today", emphasized: true, action: onUseToday)
                }
            }
        }
        .padding(.vertical, 9)
    }

    private func quietAction(_ label: String, emphasized: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(emphasized ? Color.unbound.accent : Color.unbound.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(drop.title)")
    }
}

#Preview {
    let squadId = UUID()
    let workout = SavedWorkout(title: "Pull Density 30", blocks: [])
    VStack(spacing: 0) {
        SquadRoutineDropRow(
            drop: SquadRoutineDrop(
                squadId: squadId,
                authorUserId: UUID(),
                authorDisplayName: "Mara",
                title: "Pull Density 30",
                note: "Strict rest. Stop one rep before form breaks.",
                workout: workout,
                createdAt: Date().addingTimeInterval(-5400)
            ),
            authorName: "Mara",
            isMine: false,
            onSave: {},
            onUseToday: {}
        )
        SquadRoutineDropRow(
            drop: SquadRoutineDrop(
                squadId: squadId,
                authorUserId: UUID(),
                authorDisplayName: "You",
                title: "Hotel Upper",
                note: nil,
                workout: workout,
                createdAt: Date().addingTimeInterval(-86400)
            ),
            authorName: "You",
            isMine: true,
            onSave: {},
            onUseToday: {}
        )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
