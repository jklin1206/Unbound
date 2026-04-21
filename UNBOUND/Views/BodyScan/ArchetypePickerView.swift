import SwiftUI

struct ArchetypePickerView: View {
    @Binding var selectedArchetype: Archetype

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Archetype")
                .font(.subheadline(18))
                .foregroundColor(.theme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Archetype.allCases) { archetype in
                        ArchetypeCard(
                            archetype: archetype,
                            isSelected: archetype == selectedArchetype,
                            onTap: { selectedArchetype = archetype }
                        )
                        .frame(width: 200)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}
