import SwiftUI

struct SquadRoutineDropCard: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.warnOrange.opacity(0.14))
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.unbound.warnOrange)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(drop.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)

                    Text("\(isMine ? "You" : authorName) dropped this \(Self.relativeFormatter.localizedString(for: drop.createdAt, relativeTo: .now))")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if let note = drop.note {
                Text(note)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                metaPill(icon: "list.bullet", value: "\(drop.exerciseCount) EX")
                metaPill(icon: "clock.fill", value: "\(drop.estimatedMinutes)M")
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(action: onSave) {
                    Label("Save", systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SquadRoutineDropButtonStyle(tint: Color.unbound.accent))

                Button(action: onUseToday) {
                    Label("Today", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SquadRoutineDropButtonStyle(tint: Color.unbound.warnOrange))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.warnOrange.opacity(0.09),
                            Color.unbound.surface.opacity(0.90),
                            Color.unbound.bg.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.warnOrange.opacity(0.24), lineWidth: 1)
        )
    }

    private func metaPill(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(value)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(0.8)
        }
        .foregroundStyle(Color.unbound.textTertiary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.unbound.surfaceElevated.opacity(0.82)))
    }
}

struct SquadRoutineDropButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(tint)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.18 : 0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.28), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SquadConsoleBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surfaceElevated,
                            Color.unbound.surface,
                            Color.unbound.bg.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            SquadSignalLines()
                .stroke(Color.white.opacity(0.035), lineWidth: 1)

            SquadDiagonalAccentShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.30),
                            tint.opacity(0.08),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 218)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct SquadDiagonalAccentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.34, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SquadSignalLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 34
        var x = -rect.height
        while x < rect.width + rect.height {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}

struct SquadPanelStyle: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.surfaceElevated.opacity(0.92),
                                Color.unbound.surface.opacity(0.86),
                                Color.unbound.bg.opacity(0.64)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                tint.opacity(0.24),
                                Color.unbound.borderSubtle
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func squadPanel(cornerRadius: CGFloat = 18, tint: Color = Color.unbound.accent) -> some View {
        modifier(SquadPanelStyle(cornerRadius: cornerRadius, tint: tint))
    }
}

#Preview {
    NavigationStack {
        SquadDetailView()
            .environmentObject(ServiceContainer.mock)
    }
}
