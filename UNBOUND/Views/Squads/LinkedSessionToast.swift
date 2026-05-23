// UNBOUND/Views/Squads/LinkedSessionToast.swift
import SwiftUI

struct LinkedSessionToast: View {
    let participantDisplayNames: [String]
    let xpBonus: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("LINKED WITH \(participantDisplayNames.joined(separator: ", ").uppercased())")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("+\(xpBonus) XP")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.3), radius: 14)
    }
}

/// View modifier that listens for .linkedSessionDetected and slides up
/// the toast for 3 seconds.
struct LinkedSessionToastModifier: ViewModifier {
    @State private var visible: LinkedSessionToastData?

    private struct LinkedSessionToastData: Identifiable {
        let id = UUID()
        let participantDisplayNames: [String]
        let xpBonus: Int
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = visible {
                    LinkedSessionToast(
                        participantDisplayNames: toast.participantDisplayNames,
                        xpBonus: toast.xpBonus
                    )
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .linkedSessionDetected)) { note in
                let info = note.userInfo ?? [:]
                let names = info["participantDisplayNames"] as? [String] ?? []
                let xp = info["xpBonus"] as? Int ?? 0
                withAnimation(.easeOut(duration: 0.3)) {
                    visible = LinkedSessionToastData(participantDisplayNames: names, xpBonus: xp)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeIn(duration: 0.25)) {
                        visible = nil
                    }
                }
            }
    }
}

extension View {
    func linkedSessionToast() -> some View {
        modifier(LinkedSessionToastModifier())
    }
}

#Preview {
    LinkedSessionToast(participantDisplayNames: ["Alex", "Maya"], xpBonus: 10)
        .padding(24)
        .background(Color.unbound.bg)
}
