import SwiftUI

// MARK: - EquipmentSettingsView
//
// Lets the user declare what equipment they have access to. Informational
// only — never hides nodes on the Skill Map. Feeds:
//   - The "what to work on next" recommender
//   - Adaptive program generation (routes around missing equipment)
//
// Persistence: the real source of truth is `UserProfile.equipment` (the same
// value set during onboarding that program generation and trial readiness
// read). Edits here write straight through `UserService.updateProfile`.

struct EquipmentSettingsView: View {
    @EnvironmentObject private var services: ServiceContainer

    @State private var selection: Set<Equipment> = []
    @State private var isLoaded = false
    @State private var saveError: String?

    // Toggle rows: every equipment option minus the full-gym umbrella (its own
    // toggle above), legacy `.homeWeights`, and implicit `.bodyweight` (an
    // empty pick means bodyweight-only, matching onboarding).
    private static let individualItems: [Equipment] =
        Equipment.allCases.filter { $0 != .fullGym && $0 != .homeWeights && $0 != .bodyweight }

    private static let togglable: Set<Equipment> =
        Set(individualItems).union([.fullGym])

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let saveError {
                    Text(saveError)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.alert)
                        .fixedSize(horizontal: false, vertical: true)
                }
                fullGymToggle
                individualEquipmentList
                footer
            }
            .padding(20)
            .disabled(!isLoaded)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you have")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("We use this to recommend what to work on next and build your program. Nothing on the Skill Map is hidden — every node stays visible.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fullGymToggle: some View {
        toggleRow(
            title: Equipment.fullGym.displayName,
            subtitle: "Barbells, racks, rings, everything. Toggling ON implies everything below.",
            glyph: Equipment.fullGym.icon,
            isOn: binding(for: .fullGym)
        )
    }

    private var individualEquipmentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INDIVIDUAL ITEMS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2)
                .foregroundStyle(Color.unbound.textSecondary)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(Self.individualItems) { eq in
                toggleRow(
                    title: eq.displayName,
                    subtitle: subtitleFor(eq),
                    glyph: eq.icon,
                    isOn: binding(for: eq)
                )
            }
        }
    }

    private func toggleRow(title: String, subtitle: String, glyph: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: glyph)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(subtitle)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.unbound.accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("Every skill still appears on your map. Equipment toggles only tune what we recommend.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    // MARK: Data

    @MainActor
    private func load() async {
        guard !isLoaded else { return }
        let userId = services.auth.currentUserId ?? "anonymous"
        if let profile = try? await services.user.fetchProfile(userId: userId) {
            selection = Set(profile.equipment ?? []).intersection(Self.togglable)
        }
        isLoaded = true
    }

    private func binding(for equipment: Equipment) -> Binding<Bool> {
        Binding(
            get: { selection.contains(equipment) },
            set: { isOn in setEquipment(equipment, isOn: isOn) }
        )
    }

    private func setEquipment(_ equipment: Equipment, isOn: Bool) {
        let previous = selection
        var updated = selection
        if isOn {
            updated.insert(equipment)
        } else {
            updated.remove(equipment)
        }
        selection = updated
        saveError = nil
        Task { await persist(updated, rollbackTo: previous) }
    }

    @MainActor
    private func persist(_ updated: Set<Equipment>, rollbackTo previous: Set<Equipment>) async {
        // An empty selection means bodyweight-only — stored the same way
        // onboarding records it so downstream generation reads it as before.
        let payload = updated.isEmpty ? [Equipment.bodyweight] : Array(updated)
        do {
            try await services.user.updateProfile(
                userId: services.auth.currentUserId ?? "anonymous",
                fields: ["equipment": payload.map(\.rawValue)]
            )
        } catch {
            if selection == updated {
                selection = previous
            }
            saveError = "Couldn't save your equipment. Check your connection and try again."
        }
    }

    // MARK: Helpers

    private func subtitleFor(_ eq: Equipment) -> String {
        switch eq {
        case .machines:     return "Cable stacks and selectorized machines for presses and rows."
        case .barbell:      return "Squat · deadlift · bench — the strength backbone."
        case .dumbbells:    return "Weighted pullups, presses, goblet squats, carries."
        case .bench:        return "Pressing support and box work like Bulgarian split squats."
        case .pullupBar:    return "For pullups, muscle-ups, hangs, toes-to-bar."
        case .dipStation:   return "Dips, L-sits, and straight-bar leg raises."
        case .rings:        return "Unlocks iron cross, ring MU, and advanced mythic moves."
        case .bands:        return "Assistance and resistance for scaling hard skills."
        case .fullGym, .bodyweight, .homeWeights: return ""
        }
    }
}

#Preview("Equipment settings") {
    NavigationStack {
        EquipmentSettingsView()
            .environmentObject(ServiceContainer.mock)
    }
    .preferredColorScheme(.dark)
}
