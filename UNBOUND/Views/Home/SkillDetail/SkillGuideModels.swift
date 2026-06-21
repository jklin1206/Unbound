import SwiftUI

struct SkillGuide {
    let standard: String
    let scoringNote: String?
    let assistance: [SkillGuideAssistance]
    var tips: [SkillGuideTip] = []
    let mistakes: [SkillGuideMistake]
}

// MARK: - Shared guide layer

struct SkillGuideLayerCue: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let detail: String
}

struct SkillGuideLayer: Hashable {
    let title: String
    let standard: String
    let metric: String?
    let cues: [SkillGuideLayerCue]
    let scale: SkillGuideLayerCue?

    static func skill(title: String, guide: SkillGuide) -> SkillGuideLayer {
        SkillGuideLayer(
            title: "How to perform",
            standard: guide.standard,
            metric: guide.scoringNote == nil ? nil : "STANDARD",
            cues: cues(from: guide),
            scale: guide.assistance.first.map {
                SkillGuideLayerCue(
                    id: "scale-\($0.name)",
                    icon: $0.icon,
                    title: $0.name,
                    detail: $0.detail
                )
            }
        )
    }

    static func rankExercise(definition: MovementDefinition) -> SkillGuideLayer {
        if let skillId = definition.skillId,
           let guide = SkillGuideLibrary.guide(for: skillId) {
            return SkillGuideLayer(
                title: "How to perform",
                standard: "\(guide.standard) \(proofStandard(for: definition))",
                metric: metricLabel(for: definition.rankTemplate),
                cues: cues(from: guide),
                scale: guide.assistance.first.map {
                    SkillGuideLayerCue(
                        id: "scale-\($0.name)",
                        icon: $0.icon,
                        title: $0.name,
                        detail: $0.detail
                    )
                }
            )
        }

        return SkillGuideLayer(
            title: "How to perform",
            standard: "\(slotStandard(for: definition.movementSlot)) \(proofStandard(for: definition))",
            metric: metricLabel(for: definition.rankTemplate),
            cues: fallbackCues(for: definition.movementSlot),
            scale: nil
        )
    }

    private static func cues(from guide: SkillGuide) -> [SkillGuideLayerCue] {
        guide.tips.prefix(3).enumerated().map { offset, tip in
            SkillGuideLayerCue(
                id: "tip-\(offset)-\(tip.title)",
                icon: tip.icon.isEmpty ? "lightbulb.fill" : tip.icon,
                title: tip.title,
                detail: tip.detail
            )
        }
    }

    private static func metricLabel(for template: MovementRankTemplate) -> String? {
        switch template {
        case .barbellStrength, .machineStrength, .weightedBodyweight:
            return "1RM"
        case .bodyweightReps:
            return "REPS"
        case .holdControl, .mobilityDuration:
            return "HOLD"
        case .carrySled, .cardioPerformance:
            return "TIME"
        case .routineCompletion:
            return "PROOF"
        case .unranked:
            return nil
        }
    }

    private static func proofStandard(for definition: MovementDefinition) -> String {
        switch definition.rankTemplate {
        case .barbellStrength:
            return "For the rank, log the heaviest clean full-range rep you can repeat with the same stance and control."
        case .machineStrength:
            return "For the rank, keep the same seat, pad, handle, and range, then log the heaviest clean full-range rep."
        case .weightedBodyweight:
            return "For the rank, log added external load. Bodyweight-only is +0, so the number should mean extra weight you controlled."
        case .bodyweightReps:
            return "For the rank, log one clean max-rep set and stop when the next rep would need a different shape."
        case .holdControl:
            return "For the rank, start the timer once the position is locked and stop when the line or brace breaks."
        case .carrySled, .cardioPerformance:
            return "For the rank, use the exact completed timed proof from the same setup each time."
        case .mobilityDuration:
            return "For the rank, hold only active, pain-free range and stop when the position has to be forced."
        case .routineCompletion:
            return "For the rank, log the one proof this movement asks for and keep the setup repeatable."
        case .unranked:
            return "Log only the clean proof this movement asks for."
        }
    }

    private static func slotStandard(for slot: MovementSlot) -> String {
        switch slot {
        case .squat:
            return "Set a stable tripod foot, brace before you descend, and move through the deepest range you can own without the knees or chest collapsing."
        case .hinge:
            return "Start with the load close, send the hips back first, keep the spine long, then finish tall without turning the last inch into a back arch."
        case .horizontalPush:
            return "Match the handles or hands to mid-chest, set the shoulders slightly back and down, then press without bouncing or rolling forward."
        case .verticalPush:
            return "Stack ribs over hips, press from a quiet shoulder, and finish tall with arms by the ears while the low back stays calm."
        case .horizontalPull:
            return "Brace the trunk, pull elbows toward the ribs, briefly own the squeeze, then return without dumping the shoulders forward."
        case .verticalPull:
            return "Start from a long body, pull the shoulders away from the ears, drive elbows down, then control the return to the same start."
        case .arms:
            return "Park the upper arm, keep the wrist stacked, move through the target joint, and end the set when momentum becomes the main engine."
        case .core:
            return "Lock ribs to pelvis before the effort, breathe behind the brace, and stop as soon as the body line changes."
        case .calves:
            return "Keep pressure centered through the forefoot, rise straight up, pause at the top, then lower into a controlled stretch."
        case .carry:
            return "Stand tall before the clock starts, keep quiet steps, and stop before grip or posture turns the carry into a stagger."
        case .cardio:
            return "Use the same machine, route, incline, or resistance setting, then record the exact completed effort."
        case .mobility:
            return "Enter the range slowly, keep active tension, breathe, and exit with control before pain or numbness appears."
        case .routine, .skill:
            return "Use the same start shape every attempt and count only reps or seconds that still look repeatable."
        }
    }

    private static func fallbackCues(for slot: MovementSlot) -> [SkillGuideLayerCue] {
        switch slot {
        case .squat:
            return [
                cue("squat-tripod", "shoeprints.fill", "Tripod foot", "Feel big toe, little toe, and heel stay heavy so the knee has a clear track."),
                cue("squat-knees", "target", "Knees follow toes", "Send each knee along the same line as the toes instead of letting them cave inward."),
                cue("squat-brace", "shield.fill", "Ribs stacked", "Brace ribs over pelvis before the first bend, then keep that shape as depth changes.")
            ]
        case .hinge:
            return [
                cue("hinge-hips", "arrow.left.and.right", "Hips move first", "Push the hips back like closing a car door while the shins stay quiet."),
                cue("hinge-spine", "ruler.fill", "Long spine", "Keep the line from tailbone to crown long; stop higher if the back rounds."),
                cue("hinge-load", "hand.raised.fill", "Weight stays close", "Let the load travel near the body so the back does not have to rescue the rep.")
            ]
        case .horizontalPush:
            return [
                cue("hpush-shoulders", "arrow.down.circle.fill", "Shoulders set", "Slide shoulder blades slightly down and back before the first press."),
                cue("hpush-ribs", "shield.fill", "Ribs quiet", "Keep the trunk organized so the press does not become a big rib flare."),
                cue("hpush-return", "arrow.uturn.backward.circle.fill", "Own the return", "Lower deliberately to the same depth; bouncing changes the standard.")
            ]
        case .verticalPush:
            return [
                cue("vpush-stack", "shield.fill", "Zip ribs to hips", "Keep the front ribs pulled toward the pelvis so the press does not become a backbend."),
                cue("vpush-line", "arrow.up.circle.fill", "Press tall", "Drive up until the arms finish by the ears without jamming the neck."),
                cue("vpush-clear", "eye.fill", "Head through late", "Let the head move through only after the load has cleared the face.")
            ]
        case .horizontalPull:
            return [
                cue("hpull-pencil", "pencil", "Pinch the pencil", "Briefly squeeze as if holding a pencil between the shoulder blades, then release slowly."),
                cue("hpull-elbows", "arrow.backward.circle.fill", "Elbows to ribs", "Pull elbows toward lower ribs or back pockets so the back leads the rep."),
                cue("hpull-neck", "arrow.down.circle.fill", "No shrug finish", "Finish with shoulders away from the ears instead of climbing into the neck.")
            ]
        case .verticalPull:
            return [
                cue("vpull-pocket", "arrow.down.circle.fill", "Shoulders down", "Begin by pulling shoulders away from the ears before the elbows bend hard."),
                cue("vpull-elbows", "arrow.down", "Elbows drive down", "Think elbows to ribs instead of chin reaching forward for the target."),
                cue("vpull-return", "arrow.uturn.down.circle.fill", "Control the reach", "Lower to the same long start without dropping out of position.")
            ]
        case .arms:
            return [
                cue("arms-park", "pin.fill", "Upper arm parked", "Keep the upper arm quiet unless the exercise specifically asks it to move."),
                cue("arms-wrist", "ruler.fill", "Wrist stacked", "Line the wrist with the forearm so force does not leak through the joint."),
                cue("arms-squeeze", "bolt.fill", "Squeeze, do not swing", "Finish with the target muscle, not a torso swing that starts the rep for you.")
            ]
        case .core:
            return [
                cue("core-ribs", "shield.fill", "Ribs down", "Pull ribs toward pelvis before the timer or rep starts."),
                cue("core-breathe", "wind", "Breathe behind brace", "The trunk should be firm without turning the hold into a panic breath."),
                cue("core-stop", "timer", "Stop on shape break", "End the proof when pelvis, low back, shoulders, or breathing changes the position.")
            ]
        case .calves:
            return [
                cue("calves-foot", "shoeprints.fill", "Foot stays centered", "Keep the ankle from rolling out as fatigue builds."),
                cue("calves-rise", "arrow.up.circle.fill", "Rise through big toe", "Push tall through the big-toe side without collapsing the arch."),
                cue("calves-pause", "timer", "Pause at the top", "Hold the highest point for a beat so the rep is not just a bounce.")
            ]
        case .carry:
            return [
                cue("carry-tall", "arrow.up.circle.fill", "Stand tall first", "Begin the clock after the load is controlled and posture is set."),
                cue("carry-zipper", "ruler.fill", "Zipper forward", "Keep the front of the body pointed forward instead of leaning away from the load."),
                cue("carry-steps", "shoeprints.fill", "Quiet steps", "Short, smooth steps help the trunk stay stacked while grip gets tired.")
            ]
        case .cardio:
            return [
                cue("cardio-setup", "slider.horizontal.3", "Same setup", "Use the same machine, route, damper, incline, or resistance when comparing ranks."),
                cue("cardio-rhythm", "waveform.path.ecg", "Repeatable rhythm", "Hold a pace or cadence you can measure instead of random surges."),
                cue("cardio-record", "checkmark.seal.fill", "Record exact proof", "Use the number the machine or timer actually gives you.")
            ]
        case .mobility:
            return [
                cue("mobility-edge", "target", "Edge, not pain", "The range should feel loaded and specific, never sharp or numb."),
                cue("mobility-active", "bolt.fill", "Hold active tension", "Own the shape with muscle instead of sinking passively into it."),
                cue("mobility-exit", "arrow.uturn.backward.circle.fill", "Exit clean", "Come out slowly so the end range is controlled all the way through.")
            ]
        case .routine, .skill:
            return [
                cue("skill-repeat", "arrow.clockwise", "Repeatable setup", "Use the same hands, feet, grip, or body line every attempt."),
                cue("skill-quality", "checkmark.seal.fill", "Quality before speed", "Move fast only while the rep still looks clear and countable."),
                cue("skill-reset", "timer", "Reset when rhythm breaks", "End the proof when balance turns into a chase or reps become blurry.")
            ]
        }
    }

    private static func cue(_ id: String, _ icon: String, _ title: String, _ detail: String) -> SkillGuideLayerCue {
        SkillGuideLayerCue(id: id, icon: icon, title: title, detail: detail)
    }
}

struct SkillGuideLayerView: View {
    let layer: SkillGuideLayer
    let tint: Color
    var isProminent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isProminent ? 17 : 15) {
            HStack(alignment: .firstTextBaseline) {
                Text(layer.title.uppercased())
                    .font((isProminent ? Font.unbound.bodyMStrong : Font.unbound.bodyS.weight(.heavy)))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textTertiary)

                Spacer(minLength: 10)

                if let metric = layer.metric {
                    Text(metric)
                        .font(Font.unbound.monoS.weight(.black))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
            }

            Text(layer.standard)
                .font(isProminent ? Font.unbound.bodyM : Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineSpacing(isProminent ? 4 : 3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(layer.cues.enumerated()), id: \.element.id) { index, cue in
                    guideRow(cue)
                        .padding(.vertical, isProminent ? 13 : 11)

                    if index < layer.cues.count - 1 || layer.scale != nil {
                        Divider()
                            .overlay(Color.unbound.borderSubtle.opacity(0.56))
                    }
                }

                if let scale = layer.scale {
                    guideRow(scale)
                        .padding(.vertical, isProminent ? 13 : 11)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guideRow(_ cue: SkillGuideLayerCue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: cue.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(cue.title)
                    .font(isProminent ? Font.unbound.bodyMStrong : Font.unbound.bodyS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(cue.detail)
                    .font(isProminent ? Font.unbound.bodyM : Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineSpacing(isProminent ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SkillGuideAssistance {
    let name: String
    let detail: String
    let icon: String
}

struct SkillGuideTip {
    let title: String
    let detail: String
    let icon: String
}

struct SkillGuideMistake {
    let mistake: String
    let fix: String
}

enum SkillGuideTab: CaseIterable {
    case form
    case assist
    case tips
    case fixes

    var label: String {
        switch self {
        case .form: return "Form"
        case .assist: return "Assist"
        case .tips: return "Tips"
        case .fixes: return "Fixes"
        }
    }

    var icon: String {
        switch self {
        case .form: return "rectangle.stack.fill"
        case .assist: return "figure.strengthtraining.functional"
        case .tips: return "lightbulb.fill"
        case .fixes: return "wrench.and.screwdriver.fill"
        }
    }
}
