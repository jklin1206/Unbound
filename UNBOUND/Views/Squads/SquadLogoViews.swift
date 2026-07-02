import SwiftUI

struct SquadLogoMarkView: View {
    let logoId: String?
    let size: CGFloat
    var showsBorder = true

    private var preset: SquadLogoPreset {
        SquadLogoCatalog.preset(for: logoId)
    }

    var body: some View {
        ZStack {
            Image(preset.assetName)
                .resizable()
                .scaledToFit()
                .shadow(color: Color.black.opacity(0.58), radius: size * 0.09, y: size * 0.05)
                .shadow(color: preset.palette.primary.opacity(0.32), radius: size * 0.07)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .overlay {
            if showsBorder {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                preset.palette.primary.opacity(0.70),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, size * 0.014)
                    )
                    .scaleEffect(0.96)
            }
        }
    }
}

struct SquadLogoPicker: View {
    @Binding var selectedLogoId: String

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SquadLogoMarkView(logoId: selectedLogoId, size: 96)
                VStack(alignment: .leading, spacing: 4) {
                    CalmSectionHeader(title: "SQUAD MARK")
                    Text(SquadLogoCatalog.preset(for: selectedLogoId).title)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(SquadLogoCatalog.presets) { preset in
                    SquadLogoOptionButton(
                        preset: preset,
                        isSelected: selectedLogoId == preset.id
                    ) {
                        selectedLogoId = preset.id
                    }
                }
            }
        }
    }
}

struct SquadLogoEditSheet: View {
    let initialLogoId: String?
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLogoId: String

    init(initialLogoId: String?, onSave: @escaping (String) -> Void) {
        self.initialLogoId = initialLogoId
        self.onSave = onSave
        _selectedLogoId = State(initialValue: SquadLogoCatalog.resolvedId(initialLogoId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                SquadLogoPicker(selectedLogoId: $selectedLogoId)
                    .padding(20)
                    .padding(.bottom, 88)
            }
            .background(Color.unbound.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                UnboundButton(title: "Save Mark") {
                    onSave(selectedLogoId)
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color.unbound.bg)
            }
            .navigationTitle("Squad Mark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct SquadLogoOptionButton: View {
    let preset: SquadLogoPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SquadLogoMarkView(logoId: preset.id, size: 82, showsBorder: isSelected)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.unbound.bg, preset.palette.primary)
                            .offset(x: 5, y: -5)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.unbound.surface.opacity(isSelected ? 0.9 : 0.0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            isSelected ? preset.palette.primary.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(preset.title) squad mark"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension SquadLogoPreset.Palette {
    var primary: Color {
        switch self {
        case .forge: Color(red: 0.12, green: 0.80, blue: 0.92)
        case .ember: Color(red: 1.00, green: 0.38, blue: 0.15)
        case .volt: Color(red: 0.93, green: 0.88, blue: 0.20)
        case .crown: Color(red: 0.98, green: 0.66, blue: 0.20)
        case .steel: Color(red: 0.56, green: 0.64, blue: 0.72)
        case .pulse: Color(red: 0.94, green: 0.20, blue: 0.44)
        case .nova: Color(red: 0.72, green: 0.38, blue: 1.00)
        case .glacier: Color(red: 0.42, green: 0.82, blue: 1.00)
        case .neon: Color(red: 0.32, green: 0.95, blue: 0.42)
        case .prism: Color(red: 0.20, green: 0.54, blue: 1.00)
        case .dusk: Color(red: 0.42, green: 0.40, blue: 0.86)
        case .signal: Color(red: 0.00, green: 0.78, blue: 0.58)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .forge:
            [Color(red: 0.03, green: 0.12, blue: 0.18), Color(red: 0.08, green: 0.58, blue: 0.72), primary]
        case .ember:
            [Color(red: 0.20, green: 0.04, blue: 0.04), Color(red: 0.72, green: 0.12, blue: 0.06), primary]
        case .volt:
            [Color(red: 0.12, green: 0.12, blue: 0.04), Color(red: 0.40, green: 0.50, blue: 0.08), primary]
        case .crown:
            [Color(red: 0.25, green: 0.12, blue: 0.03), Color(red: 0.70, green: 0.36, blue: 0.08), primary]
        case .steel:
            [Color(red: 0.06, green: 0.08, blue: 0.10), Color(red: 0.22, green: 0.30, blue: 0.38), primary]
        case .pulse:
            [Color(red: 0.18, green: 0.02, blue: 0.10), Color(red: 0.58, green: 0.06, blue: 0.24), primary]
        case .nova:
            [Color(red: 0.08, green: 0.05, blue: 0.20), Color(red: 0.36, green: 0.15, blue: 0.70), primary]
        case .glacier:
            [Color(red: 0.02, green: 0.12, blue: 0.22), Color(red: 0.08, green: 0.44, blue: 0.72), primary]
        case .neon:
            [Color(red: 0.02, green: 0.16, blue: 0.08), Color(red: 0.05, green: 0.48, blue: 0.18), primary]
        case .prism:
            [Color(red: 0.05, green: 0.08, blue: 0.22), Color(red: 0.10, green: 0.28, blue: 0.72), Color(red: 0.82, green: 0.24, blue: 0.92)]
        case .dusk:
            [Color(red: 0.06, green: 0.06, blue: 0.18), Color(red: 0.22, green: 0.20, blue: 0.46), primary]
        case .signal:
            [Color(red: 0.02, green: 0.16, blue: 0.15), Color(red: 0.02, green: 0.48, blue: 0.38), primary]
        }
    }
}
