import SwiftUI

// MARK: - FormPhase
//
// One slide in the Form Breakdown slideshow. Each phase is a discrete pose
// in the skill's rep cycle (or a setup/sticking-point/finish for static
// holds). The slideshow lets the user pause on any single phase and study
// the form without the visual noise of a stitched infographic.

struct FormPhase: Identifiable, Hashable {
    let id: String              // unique within a skill (e.g. "phase1")
    let title: String           // short label, e.g. "DEAD HANG"
    let cues: [String]          // 2–4 short cue lines
    var instruction: String? = nil // longer "how to do it" text for this slide
    let assetName: String?      // imageset name in Assets.xcassets, nil → fallback glyph
    let fallbackSymbol: String  // SF Symbol if asset is missing
}

// MARK: - FormPhaseSlideshow
//
// Swipeable card stack of phases. One big silhouette per slide, step number
// + label + cue list below. Page dots at the bottom. Auto-advance is OFF by
// default — the whole point is letting the user pause and study each phase.

struct FormPhaseSlideshow: View {
    let phases: [FormPhase]
    let skillTitle: String

    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $index) {
                ForEach(Array(phases.enumerated()), id: \.element.id) { i, phase in
                    phaseCard(phase: phase, number: i + 1, total: phases.count)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 500)

            pageDots
        }
    }

    @ViewBuilder
    private func phaseCard(phase: FormPhase, number: Int, total: Int) -> some View {
        let usesGeneratedPanel = phase.assetName?.contains("_phase") == true

        VStack(spacing: 12) {
            if let asset = phase.assetName, UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: usesGeneratedPanel ? 0 : 14, style: .continuous))
            } else {
                fallbackPhaseArt(phase: phase)
            }

            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.bg)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.unbound.accent))

                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.title.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)

                    Text(phase.instruction ?? phase.cues.prefix(3).joined(separator: " • "))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("\(number)/\(total)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func fallbackPhaseArt(phase: FormPhase) -> some View {
        ZStack {
            Circle()
                .fill(Color.unbound.accent.opacity(0.18))
                .frame(width: 180, height: 180)
                .blur(radius: 38)

            Image(systemName: phase.fallbackSymbol)
                .font(.system(size: 100, weight: .regular))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 200, height: 200)
                .shadow(color: Color.unbound.accent.opacity(0.45), radius: 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<phases.count, id: \.self) { i in
                Capsule()
                    .fill(
                        i == index
                            ? Color.unbound.accent
                            : Color.unbound.border
                    )
                    .frame(width: i == index ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
            }
        }
    }
}

// MARK: - FormPhaseLibrary
//
// V1 in-memory authoring of per-skill phase data. Hardcoded for the pilot
// (Pull-Up). Skills not present here fall back to the numbered cue list —
// no slideshow, no broken behavior.

enum FormPhaseLibrary {
    static func phases(
        for skillId: String,
        fallbackTitle: String,
        formCues: [String]
    ) -> [FormPhase] {
        switch skillId {

        case "pp.muscle-up":
            return [
                FormPhase(
                    id: "phase1",
                    title: "Grip",
                    cues: [
                        "Knuckles sit high over the bar",
                        "Start in an active hang",
                        "Ribs down, legs together"
                    ],
                    instruction: "Use a slightly false or high wrist grip if you can hold it: knuckles sit more on top of the bar so the wrist is already ready for the dip. Start in an active hang with shoulders engaged, ribs down, legs together, and eyes forward.",
                    assetName: "pp_muscle-up_phase1",
                    fallbackSymbol: "figure.strengthtraining.functional"
                ),
                FormPhase(
                    id: "phase2",
                    title: "Swing",
                    cues: [
                        "Move hollow to arch under control",
                        "Keep the body long",
                        "Use hip drive, not a knee kick"
                    ],
                    instruction: "Move through a controlled hollow-to-arch swing. Legs stay long and together. The legs help by creating rhythm and hip drive, not by bicycling, knee-tucking, or kicking one side over the bar.",
                    assetName: "pp_muscle-up_phase2",
                    fallbackSymbol: "figure.strengthtraining.functional"
                ),
                FormPhase(
                    id: "phase3",
                    title: "Pull",
                    cues: [
                        "Pull the bar toward low chest",
                        "Drive elbows down and back",
                        "Begin moving around the bar"
                    ],
                    instruction: "Pull explosively toward the lower chest or upper stomach while keeping the bar close. Think elbows down and back first, then chest forward. A low pull forces the transition to become a fight instead of a path.",
                    assetName: "pp_muscle-up_phase3",
                    fallbackSymbol: "arrow.triangle.branch"
                ),
                FormPhase(
                    id: "phase4",
                    title: "Turnover",
                    cues: [
                        "Chest passes over the hands",
                        "Both elbows roll through together",
                        "Press to a stable lockout"
                    ],
                    instruction: "At the top of the pull, lean the chest over the hands and roll both wrists forward. Both elbows should pass through together into the bottom of a straight-bar dip, then press down until the elbows lock and the top position is stable.",
                    assetName: "pp_muscle-up_phase4",
                    fallbackSymbol: "figure.strengthtraining.functional"
                ),
            ]

        case "pp.pullup":
            return [
                FormPhase(
                    id: "phase1",
                    title: "Dead Hang",
                    cues: [
                        "Grip slightly wider than shoulders",
                        "Arms fully extended",
                        "Engage core, body straight",
                        "Shoulders packed down"
                    ],
                    assetName: "pp_pullup_phase1",
                    fallbackSymbol: "figure.climbing"
                ),
                FormPhase(
                    id: "phase2",
                    title: "Pulling",
                    cues: [
                        "Drive elbows down and back",
                        "Pull with the lats, not the biceps",
                        "Keep body tight and vertical"
                    ],
                    assetName: "pp_pullup_phase2",
                    fallbackSymbol: "figure.climbing"
                ),
                FormPhase(
                    id: "phase3",
                    title: "Top Position",
                    cues: [
                        "Chin clearly over the bar",
                        "Squeeze shoulder blades",
                        "No swinging or kipping"
                    ],
                    assetName: "pp_pullup_phase3",
                    fallbackSymbol: "figure.climbing"
                ),
                FormPhase(
                    id: "phase4",
                    title: "Lower Down",
                    cues: [
                        "Lower with control",
                        "Full extension at the bottom",
                        "Stay tight — no relaxing into the hang"
                    ],
                    assetName: "pp_pullup_phase4",
                    fallbackSymbol: "figure.climbing"
                ),
            ]

        default:
            return []  // fallback to numbered cue list
        }
    }
}
