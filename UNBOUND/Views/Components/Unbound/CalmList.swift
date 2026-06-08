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

/// The single emphasis treatment in a calm list: a 3pt left accent spine plus a
/// faint surface wash behind the active row/section. Everything not-active stays
/// flat on `bg`.
struct ActiveAccentModifier: ViewModifier {
    let isActive: Bool
    var tint: Color = Color.unbound.coachCyan
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.unbound.surface.opacity(0.55))
                }
            }
            .overlay(alignment: .leading) {
                if isActive {
                    Capsule()
                        .fill(tint)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
            }
    }
}

extension View {
    /// Marks a row/section as the currently-active one in a calm list.
    func activeAccent(
        _ isActive: Bool,
        tint: Color = Color.unbound.coachCyan,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(ActiveAccentModifier(isActive: isActive, tint: tint, cornerRadius: cornerRadius))
    }
}
