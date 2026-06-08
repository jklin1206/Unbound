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
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }
}
