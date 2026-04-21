import SwiftUI

// MARK: - EquipmentSettingsView
//
// Lets the user declare what equipment they have access to. Informational
// only — never hides nodes on the Skill Map. Feeds:
//   - The "what to work on next" recommender
//   - Adaptive program generation (routes around missing equipment)
//
// Persistence: UserDefaults-backed via EquipmentProfileStore. Lightweight;
// can migrate to DatabaseService later.

struct EquipmentSettingsView: View {
    @State private var profile: UserSkillEquipmentProfile = EquipmentProfileStore.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                fullGymToggle
                individualEquipmentList
                footer
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
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
            title: "Full commercial gym",
            subtitle: "Barbells, racks, rings, everything. Toggling ON implies everything below.",
            glyph: "building.2.fill",
            isOn: Binding(
                get: { profile.hasFullGym },
                set: {
                    profile.hasFullGym = $0
                    EquipmentProfileStore.save(profile)
                }
            )
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

            ForEach(SkillEquipment.allCases) { eq in
                if eq != .bodyweight {   // bodyweight is implicit; never a toggle
                    toggleRow(
                        title: eq.displayName,
                        subtitle: subtitleFor(eq),
                        glyph: eq.glyph,
                        isOn: Binding(
                            get: { profile.available.contains(eq) },
                            set: {
                                if $0 {
                                    profile.available.insert(eq)
                                } else {
                                    profile.available.remove(eq)
                                }
                                EquipmentProfileStore.save(profile)
                            }
                        )
                    )
                }
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

    // MARK: Helpers

    private func subtitleFor(_ eq: SkillEquipment) -> String {
        switch eq {
        case .pullupBar:        return "For pullups, muscle-ups, hangs, toes-to-bar."
        case .gymnasticRings:   return "Unlocks iron cross, ring MU, and advanced mythic moves."
        case .barbell:          return "Squat · deadlift · bench — the strength backbone."
        case .dumbbells:        return "Weighted pullup, goblet squats, carries."
        case .parallettes:      return "L-sit, tuck planche, handstand pushups."
        case .kettlebell:       return "Farmer carry, goblet squat, swings."
        case .sled:             return "Lower-body conditioning and capacity work."
        case .rower:            return "Conditioning benchmarks (400m row, etc)."
        case .elevatedSurface:  return "Bench for pressing, box for Bulgarian split squats."
        case .bodyweight:       return ""
        }
    }
}

// MARK: - EquipmentProfileStore (lightweight persistence)

enum EquipmentProfileStore {
    private static let defaultsKey = "unbound.equipmentProfile.v1"

    static func load() -> UserSkillEquipmentProfile {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let profile = try? JSONDecoder().decode(UserSkillEquipmentProfile.self, from: data)
        else {
            return .default
        }
        return profile
    }

    static func save(_ profile: UserSkillEquipmentProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

#Preview("Equipment settings") {
    NavigationStack {
        EquipmentSettingsView()
    }
    .preferredColorScheme(.dark)
}
