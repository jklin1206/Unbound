// UNBOUND/Views/Squads/FriendChallengeCreateSheet.swift
//
// Create a 1v1 challenge: pick an opponent, pick a challenge, send. Calm
// single-select lists — flat rows with a radio, the selected row raised on
// a fill-only surface — and one primary CTA pinned at the bottom.
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
                VStack(alignment: .leading, spacing: 28) {
                    opponentSection
                    kindSection
                    if selectedKind.requiresExercisePick {
                        exerciseSection
                    }
                    if let error {
                        Text(error)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.alert)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.unbound.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                UnboundButton(
                    title: isCreating ? "Sending…" : "Send Challenge",
                    isEnabled: canCreate && !isCreating
                ) {
                    Task { await createChallenge() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(Color.unbound.bg.opacity(0.94))
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Opponent

    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            CalmSectionHeader(
                title: "OPPONENT",
                trailing: eligibleOpponents.isEmpty ? nil : (eligibleOpponents.count == 1 ? "1 crewmate" : "\(eligibleOpponents.count) crewmates")
            )
            .padding(.bottom, 6)

            if eligibleOpponents.isEmpty {
                Text("No crewmates yet — invite someone to your squad first.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(eligibleOpponents) { member in
                    opponentRow(member)
                }
            }
        }
    }

    private func opponentRow(_ member: SquadMember) -> some View {
        let isSelected = selectedOpponent?.id == member.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedOpponent = member
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.unbound.surfaceElevated)
                    Text(initials(for: member.displayName))
                        .font(Font.unbound.captionS.weight(.heavy))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                .frame(width: 34, height: 34)

                Text(member.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                radio(isSelected)
            }
            .padding(.horizontal, isSelected ? 12 : 0)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .activeSurface(isSelected, cornerRadius: 14)
    }

    // MARK: - Challenge kind

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            CalmSectionHeader(title: "CHALLENGE")
                .padding(.bottom, 6)
            ForEach(FriendChallenge.Kind.creationOptions, id: \.self) { kind in
                kindRow(kind)
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(kind.subtitle)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                radio(isSelected)
            }
            .padding(.horizontal, isSelected ? 12 : 0)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .activeSurface(isSelected, cornerRadius: 14)
    }

    // MARK: - Lift pick (heaviestLift only)

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            CalmSectionHeader(title: "PICK A LIFT")
                .padding(.bottom, 6)

            TextField("Search lifts…", text: $exerciseSearch)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .padding(.bottom, 6)

            let filtered = exerciseSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.heaviestLiftOptions
                : Self.heaviestLiftOptions.filter {
                    $0.localizedCaseInsensitiveContains(exerciseSearch)
                }

            ForEach(filtered, id: \.self) { lift in
                let isSelected = selectedExercise == lift
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedExercise = lift
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(lift)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Spacer(minLength: 8)
                        radio(isSelected)
                    }
                    .padding(.horizontal, isSelected ? 12 : 0)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .activeSurface(isSelected, cornerRadius: 12)
            }
        }
    }

    // MARK: - Shared pieces

    private func radio(_ isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.unbound.accent : Color.unbound.border,
                    lineWidth: 1.5
                )
                .frame(width: 20, height: 20)
            if isSelected {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 10, height: 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var canCreate: Bool {
        guard selectedOpponent != nil else { return false }
        if selectedKind.requiresExercisePick { return selectedExercise != nil }
        return true
    }

    private func initials(for name: String) -> String {
        let initials = name
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
        return initials.isEmpty ? "U" : initials.uppercased()
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
