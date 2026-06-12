// UNBOUND/Views/Squads/FriendChallengeCreateSheet.swift
//
// Sheet for creating a 1v1 friend challenge.
// Picks an opponent from the squad roster and selects a challenge kind.
import SwiftUI

struct FriendChallengeCreateSheet: View {
    @EnvironmentObject var services: ServiceContainer
    let squadId: UUID
    let roster: [SquadMember]
    var onCreated: ((FriendChallenge) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOpponent: SquadMember?
    @State private var selectedKind: FriendChallenge.Kind = .mostSessions
    @State private var selectedExercise: String?
    @State private var exerciseSearch: String = ""
    @State private var isCreating = false
    @State private var error: String?

    /// Canonical catalog keys for the curated heaviestLift picker. Display names
    /// are resolved from `ExerciseCatalog` at runtime so a future catalog rename
    /// flows through automatically (the server matches on the `displayName` that
    /// logging writes to `exercise_entries`). Locked by
    /// `FriendChallengeLiftOptionsTests`.
    private static let heaviestLiftCanonicalNames: [String] = [
        "back squat",
        "front squat",
        "bench press",
        "incline bench press",
        "overhead press",
        "deadlift",
        "romanian deadlift",
        "trap bar deadlift",
        "bent-over row",
        "weighted pullup",
        "hip thrust",
        "barbell curl"
    ]

    /// Curated compound lifts for heaviestLift — the catalog `displayName` strings
    /// that logging writes, matched (lower/trim) server-side in exercise_entries.
    static let heaviestLiftOptions: [String] = heaviestLiftCanonicalNames.compactMap {
        ExerciseCatalog.exercise(named: $0)?.displayName
    }

    private var currentUserId: UUID? {
        services.auth.currentUserId.flatMap(SquadUserIdentity.uuid(from:))
    }
    private var eligibleOpponents: [SquadMember] {
        guard let me = currentUserId else { return roster }
        return roster.filter { $0.userId != me }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    opponentSection
                    kindSection
                    if selectedKind.requiresExercisePick {
                        exerciseSection
                    }
                    if let error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(20)
            }
            .background(Color.unbound.bg.ignoresSafeArea())
            .navigationTitle("Challenge a Crewmate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await createChallenge() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canCreate ? Color.unbound.accent : Color.unbound.textSecondary)
                    .disabled(!canCreate || isCreating)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("OPPONENT", icon: "person.fill")
            if eligibleOpponents.isEmpty {
                Text("No crewmates available")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.unbound.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(eligibleOpponents) { member in
                        opponentRow(member)
                    }
                }
            }
        }
    }

    private func opponentRow(_ member: SquadMember) -> some View {
        let isSelected = selectedOpponent?.id == member.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedOpponent = isSelected ? nil : member
            }
        } label: {
            HStack {
                Text(member.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.unbound.accent)
                        .font(.system(size: 18))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.unbound.accent.opacity(0.15) : Color.unbound.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.unbound.accent : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("CHALLENGE TYPE", icon: "bolt.fill")
            VStack(spacing: 8) {
                ForEach(FriendChallenge.Kind.creationOptions, id: \.self) { kind in
                    kindRow(kind)
                }
            }
        }
    }

    private func kindRow(_ kind: FriendChallenge.Kind) -> some View {
        let isSelected = selectedKind == kind
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedKind = kind
                if !kind.requiresExercisePick {
                    selectedExercise = nil
                    exerciseSearch = ""
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textTertiary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(kind.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.unbound.accent)
                        .font(.system(size: 16))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.unbound.accent.opacity(0.15) : Color.unbound.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.unbound.accent : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercise section

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PICK A LIFT", icon: "trophy.fill")
            TextField("Search lifts…", text: $exerciseSearch)
                .font(.system(size: 14))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .foregroundStyle(Color.unbound.textPrimary)
            let filtered = exerciseSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.heaviestLiftOptions
                : Self.heaviestLiftOptions.filter {
                    $0.localizedCaseInsensitiveContains(exerciseSearch)
                }
            VStack(spacing: 6) {
                ForEach(filtered, id: \.self) { lift in
                    let isSelected = selectedExercise == lift
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedExercise = lift
                        }
                    } label: {
                        HStack {
                            Text(lift)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.unbound.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.unbound.accent)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? Color.unbound.accent.opacity(0.15) : Color.unbound.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(isSelected ? Color.unbound.accent : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        guard selectedOpponent != nil else { return false }
        if selectedKind.requiresExercisePick { return selectedExercise != nil }
        return true
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private func createChallenge() async {
        guard let opponent = selectedOpponent, currentUserId != nil else { return }
        isCreating = true
        error = nil
        do {
            let challenge = try await services.friendChallenge.createChallenge(
                challengedId: opponent.userId,
                kind: selectedKind,
                squadId: squadId,
                exerciseName: selectedKind.requiresExercisePick ? selectedExercise : nil
            )
            onCreated?(challenge)
            dismiss()
        } catch {
            self.error = "Couldn't send challenge. Try again."
        }
        isCreating = false
    }
}

// MARK: - Preview

#Preview {
    let squadId = UUID()
    let roster: [SquadMember] = [
        SquadMember(id: UUID(), squadId: squadId, userId: UUID(), joinedAt: .now, displayName: "Toji", equippedTitle: nil, buildIdentity: nil),
        SquadMember(id: UUID(), squadId: squadId, userId: UUID(), joinedAt: .now, displayName: "Gojo", equippedTitle: nil, buildIdentity: nil),
    ]
    FriendChallengeCreateSheet(squadId: squadId, roster: roster)
        .environmentObject(ServiceContainer.mock)
}
