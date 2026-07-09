// UNBOUND/Views/Squads/AffinityPickerSheet.swift
//
// Captain-only sheet for the squad's monthly affinity axis. Calm single-select
// rows with a radio; the selected row raises on a fill-only surface. Reached
// from the squad options menu.
import SwiftUI

struct AffinityPickerSheet: View {
    let initialAxis: AttributeKey?
    let onConfirm: (AttributeKey?) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selected: AttributeKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick the crew's focus for this month — the axis you're all rallying to train. Holding a focus advances your crew's affinity titles.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 16)

                    ForEach(AttributeKey.allCases, id: \.self) { axis in
                        axisRow(axis)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.unbound.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                UnboundButton(title: "Confirm", isEnabled: selected != nil) {
                    onConfirm(selected)
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(Color.unbound.bg.opacity(0.94))
            }
            .navigationTitle("Squad Affinity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { selected = initialAxis }
    }

    private func axisRow(_ axis: AttributeKey) -> some View {
        let isSelected = selected == axis
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = axis
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(axis.displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(axis.trainsCopy)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
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
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .squadOwnRowHighlight(isSelected, cornerRadius: 14)
    }
}

#Preview {
    AffinityPickerSheet(initialAxis: .endurance) { _ in }
}
