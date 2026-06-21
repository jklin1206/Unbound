import SwiftUI

// MARK: - Calm List primitives
//
// Shared building blocks for the "calm list" frontend language (see
// docs/superpowers/specs/2026-06-08-program-frontend-redesign-design.md).
//
// The rules these enforce:
//   - no per-item cards / borders / shadows
//   - metadata is plain `·`-joined text, never pills
//   - only the *active* item is visually lifted (left accent spine + faint wash)

/// Plain `·`-joined metadata line. Replaces bordered "pill" rows everywhere.
/// Pass the pieces already formatted (e.g. `["3×8", "RPE 8", "rest 1:30"]`);
/// empty/blank pieces are dropped so callers can pass optionals freely.
struct MetaLine: View {
    let parts: [String]
    var emphasized: Bool = false

    init(_ parts: [String?], emphasized: Bool = false) {
        self.parts = parts.compactMap { piece in
            guard let piece, !piece.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return piece
        }
        self.emphasized = emphasized
    }

    var body: some View {
        Text(parts.joined(separator: "  ·  "))
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(emphasized ? Color.unbound.textSecondary : Color.unbound.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// The single emphasis treatment in a calm list: the active row/section sits on
/// a fill-only `surfaceElevated` panel (the brightest surface in the dark
/// palette) — no border, no shadow, no accent bar. Everything not-active stays
/// flat on `bg`. The fill alone is the lift; whitespace around it does the rest.
struct ActiveSurfaceModifier: ViewModifier {
    let isActive: Bool
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                }
            }
    }
}

extension View {
    /// Marks a row/section as the currently-active one in a calm list — a
    /// fill-only raised surface, never a bar or border.
    func activeSurface(_ isActive: Bool, cornerRadius: CGFloat = 16) -> some View {
        modifier(ActiveSurfaceModifier(isActive: isActive, cornerRadius: cornerRadius))
    }
}

/// Small tracked-caps section header for calm lists. No border, no background —
/// just label text in `textTertiary` with heavy tracking, optionally paired with
/// a trailing meta string.
struct CalmSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }
}

struct ExerciseEquipmentAssetItem: Identifiable, Hashable {
    let id: String
    let label: String
    let assetName: String
}

struct ExerciseEquipmentAssetStrip: View {
    let definition: MovementDefinition
    var maxItems: Int = 3
    var itemSize: CGFloat = 30
    var showsLabels: Bool = false

    private var items: [ExerciseEquipmentAssetItem] {
        Array(Self.items(for: definition).prefix(maxItems))
    }

    private var overflowCount: Int {
        max(0, Self.items(for: definition).count - maxItems)
    }

    var body: some View {
        if !items.isEmpty {
            HStack(spacing: showsLabels ? 8 : 6) {
                ForEach(items) { item in
                    if showsLabels {
                        labeledBadge(item)
                    } else {
                        imageBadge(item)
                    }
                }

                if overflowCount > 0 {
                    Text("+\(overflowCount)")
                        .font(Font.unbound.captionS.weight(.bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    static func items(for definition: MovementDefinition) -> [ExerciseEquipmentAssetItem] {
        let equipment = Set(definition.equipment)
        var items: [ExerciseEquipmentAssetItem] = []

        func append(_ id: String, _ label: String, _ assetName: String) {
            guard !items.contains(where: { $0.id == id }) else { return }
            items.append(ExerciseEquipmentAssetItem(id: id, label: label, assetName: assetName))
        }

        if !equipment.isDisjoint(with: [.machine, .cable, .smithMachine]) {
            let label: String
            if equipment.contains(.cable), !equipment.contains(.machine), !equipment.contains(.smithMachine) {
                label = "Cable"
            } else if equipment.contains(.smithMachine), !equipment.contains(.machine), !equipment.contains(.cable) {
                label = "Smith"
            } else {
                label = "Machine"
            }
            append("machine", label, "equipment_machines")
        }
        if equipment.contains(.barbell) { append("barbell", "Barbell", "equipment_barbell") }
        if equipment.contains(.dumbbell) { append("dumbbell", "Dumbbell", "equipment_dumbbells") }
        if equipment.contains(.kettlebell) { append("kettlebell", "Kettlebell", "equipment_kettlebell") }
        if equipment.contains(.pullupBar) { append("pullupBar", "Pull-Up Bar", "equipment_pullup_bar") }
        if equipment.contains(.dipStation) { append("dipStation", "Dip Station", "equipment_dip_station") }
        if equipment.contains(.rings) { append("rings", "Rings", "equipment_rings") }
        if equipment.contains(.bench) { append("bench", "Bench", "equipment_bench") }
        if equipment.contains(.box) { append("box", "Box", "equipment_elevated_surface") }
        if equipment.contains(.parallettes) { append("parallettes", "Parallettes", "equipment_parallettes") }
        if equipment.contains(.band) { append("band", "Band", "equipment_bands") }
        if equipment.contains(.sled) { append("sled", "Sled", "equipment_sled") }
        if equipment.contains(.cardioMachine), definition.cardioType == .row {
            append("rower", "Rower", "equipment_rower")
        }

        if items.isEmpty, equipment.contains(.bodyweight) || definition.blockKind == .bodyweight {
            append("bodyweight", "Bodyweight", "equipment_bodyweight")
        }

        return items
    }

    private var accessibilityLabel: String {
        "Equipment: " + items.map(\.label).joined(separator: ", ")
    }

    private func imageBadge(_ item: ExerciseEquipmentAssetItem) -> some View {
        equipmentImage(item)
            .frame(width: itemSize, height: itemSize)
            .background(
                RoundedRectangle(cornerRadius: max(7, itemSize * 0.24), style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(7, itemSize * 0.24), style: .continuous)
                    .strokeBorder(Color.unbound.coachCyan.opacity(0.18), lineWidth: 1)
            )
    }

    private func labeledBadge(_ item: ExerciseEquipmentAssetItem) -> some View {
        HStack(spacing: 7) {
            equipmentImage(item)
                .frame(width: itemSize, height: itemSize)
            Text(item.label.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.72))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.16), lineWidth: 1)
        )
    }

    private func equipmentImage(_ item: ExerciseEquipmentAssetItem) -> some View {
        Image(item.assetName)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(max(1, itemSize * 0.06))
    }
}
