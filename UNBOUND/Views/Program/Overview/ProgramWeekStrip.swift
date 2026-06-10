import SwiftUI

struct ProgramWeekStrip: View {
    let rangeLabel: String
    let tiles: [ProgramWeekStripTile]
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void
    let onSelectDate: (Date) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onPreviousWeek) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary.opacity(0.68))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(rangeLabel)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.72))

                Spacer()

                Button(action: onNextWeek) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary.opacity(0.68))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(tiles) { tile in
                    dayTile(tile)
                }
            }
        }
    }

    private func dayTile(_ tile: ProgramWeekStripTile) -> some View {
        let isActive = tile.isSelected || tile.isToday
        let calendar = Calendar.current
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let weekday = ((calendar.component(.weekday, from: tile.date) + 5) % 7)
        let dayNumber = calendar.component(.day, from: tile.date)

        return Button {
            onSelectDate(tile.date)
        } label: {
            VStack(spacing: 6) {
                Text(letters[weekday])
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textPrimary.opacity(0.58))
                Text("\(dayNumber)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(
                        tile.isToday
                            ? Color.unbound.accent
                            : (isActive ? Color.unbound.textPrimary : Color.unbound.textPrimary.opacity(0.72))
                    )
                    .monospacedDigit()
                tileStatusGlyph(status: tile.status, isActive: isActive)
                    .frame(height: 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tile.isSelected ? Color.unbound.surfaceElevated : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tileStatusGlyph(status: ProgramWeekTileStatus, isActive: Bool = false) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.accent)
        case .today:
            Circle()
                .fill(Color.unbound.accent)
                .frame(width: 6, height: 6)
        case .rest:
            Image(systemName: "moon.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textPrimary.opacity(0.54))
        case .planned:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.unbound.textPrimary.opacity(isActive ? 0.74 : 0.42))
                .frame(width: 15, height: 4)
        case .locked:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.unbound.textPrimary.opacity(isActive ? 0.68 : 0.34))
                .frame(width: 10, height: 3)
        }
    }
}
