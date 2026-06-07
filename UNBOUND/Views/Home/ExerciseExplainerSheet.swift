import SwiftUI

struct ExplainerPayload: Identifiable, Equatable {
    let name: String
    let description: String?    // AI-supplied 1-line description, when present
    let cues: [String]?         // for helper rows we already have cues
    let notes: String?          // for prescriptions, we have the rx note
    var id: String { name }

    init(name: String, description: String? = nil, cues: [String]? = nil, notes: String? = nil) {
        self.name = name
        self.description = description
        self.cues = cues
        self.notes = notes
    }
}

// MARK: - ExerciseExplainerSheet

struct ExerciseExplainerSheet: View {
    let payload: ExplainerPayload
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EXERCISE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(payload.name)
                    .font(.system(.title2).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let desc = payload.description ?? ExerciseExplainerLibrary.description(for: payload.name) {
                Text(desc)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let cues = payload.cues, !cues.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("FORM")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    ForEach(Array(cues.enumerated()), id: \.offset) { _, cue in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.unbound.accent.opacity(0.7))
                                .frame(width: 5, height: 5)
                                .padding(.top, 8)
                            Text(cue)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let notes = payload.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOTES")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(notes)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            UnboundButton(title: "Close", variant: .secondary) {
                onClose()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
