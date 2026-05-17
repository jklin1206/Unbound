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
        VStack(spacing: 14) {
            TabView(selection: $index) {
                ForEach(Array(phases.enumerated()), id: \.element.id) { i, phase in
                    phaseCard(phase: phase, number: i + 1, total: phases.count)
                        .tag(i)
                        .padding(.horizontal, 4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 420)

            pageDots
        }
    }

    @ViewBuilder
    private func phaseCard(phase: FormPhase, number: Int, total: Int) -> some View {
        VStack(spacing: 16) {
            // Hero silhouette for this phase.
            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.18))
                    .frame(width: 180, height: 180)
                    .blur(radius: 38)

                Group {
                    if let asset = phase.assetName, UIImage(named: asset) != nil {
                        Image(asset)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: phase.fallbackSymbol)
                            .font(.system(size: 100, weight: .regular))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }
                .frame(width: 200, height: 200)
                .shadow(color: Color.unbound.accent.opacity(0.45), radius: 22)
            }
            .frame(width: 220, height: 220)

            // Step badge + title.
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: 26, height: 26)
                    Text("\(number)")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.unbound.bg)
                }
                Text(phase.title.uppercased())
                    .font(.system(.title3).weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text("\(number) / \(total)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            // Cue bullets.
            VStack(alignment: .leading, spacing: 8) {
                ForEach(phase.cues.prefix(4), id: \.self) { cue in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.unbound.accent)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(cue)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
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
                    title: "Set",
                    cues: [
                        "Start from an active hang",
                        "Ribs down, legs quiet",
                        "Keep the bar close from the first pull"
                    ],
                    assetName: "pp_muscle-up",
                    fallbackSymbol: "figure.strengthtraining.functional"
                ),
                FormPhase(
                    id: "phase2",
                    title: "High Pull",
                    cues: [
                        "Pull toward the lower chest",
                        "Elbows drive down and back",
                        "Do not start pressing from a low pull"
                    ],
                    assetName: "pp_muscle-up_f2",
                    fallbackSymbol: "figure.strengthtraining.functional"
                ),
                FormPhase(
                    id: "phase3",
                    title: "Turnover",
                    cues: [
                        "Chest travels over the bar",
                        "Wrists roll around the bar",
                        "Both elbows arrive together"
                    ],
                    assetName: "pp_muscle-up_f2",
                    fallbackSymbol: "arrow.triangle.branch"
                ),
                FormPhase(
                    id: "phase4",
                    title: "Support",
                    cues: [
                        "Press to straight arms",
                        "Shoulders down, torso tall",
                        "Finish stable before lowering"
                    ],
                    assetName: "pp_muscle-up",
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
