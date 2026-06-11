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

    @State var index: Int = 0

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
    func phaseCard(phase: FormPhase, number: Int, total: Int) -> some View {
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

    func fallbackPhaseArt(phase: FormPhase) -> some View {
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

    var pageDots: some View {
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
// V1 in-memory authoring of per-skill phase data. Skills without generated
// bitmap phase art still get detailed instruction slides with fallback symbols.

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

        case "hs.wall-handstand-30":
            return [
                FormPhase(
                    id: "phase1",
                    title: "Walk In",
                    cues: [
                        "Start in a push-up facing away",
                        "Walk feet up the wall",
                        "Move hands only while braced"
                    ],
                    instruction: "Begin in a firm push-up position with the feet on the wall. Walk the feet upward and the hands back in small steps. Stop before the ribs flare or the elbows soften; the entry should stay deliberate, not frantic.",
                    assetName: "hs_wall-handstand-30_phase1",
                    fallbackSymbol: "arrow.up.right"
                ),
                FormPhase(
                    id: "phase2",
                    title: "Stack",
                    cues: [
                        "Hands shoulder-width",
                        "Wrists under shoulders",
                        "Toes touch the wall lightly"
                    ],
                    instruction: "Set hands about shoulder-width with fingers spread. Walk close enough that wrists, shoulders, hips, and ankles can stack. The toes should touch the wall as a reference, not as a shelf.",
                    assetName: "hs_wall-handstand-30_phase2",
                    fallbackSymbol: "line.diagonal"
                ),
                FormPhase(
                    id: "phase3",
                    title: "Push Tall",
                    cues: [
                        "Lock elbows",
                        "Shoulders cover ears",
                        "Ribs down, glutes on"
                    ],
                    instruction: "Push the floor away until the shoulders elevate and the body feels longer. Keep elbows locked, ribs tucked, glutes tight, and legs together so the wall handstand teaches the same line needed away from the wall.",
                    assetName: "hs_wall-handstand-30_phase3",
                    fallbackSymbol: "arrow.up.circle.fill"
                ),
                FormPhase(
                    id: "phase4",
                    title: "Core Lock",
                    cues: [
                        "Brace abs, ribs down",
                        "Glutes tight, legs together",
                        "Toes touch the wall lightly",
                    ],
                    instruction: "Brace the core into a hollow wall-handstand line: shoulders tall, ribs tucked, abs locked, glutes tight, legs together, and toes only lightly touching the wall. End the set before the low back arches or the shoulders sink.",
                    assetName: "hs_wall-handstand-30_phase4",
                    fallbackSymbol: "figure.core.training"
                ),
            ]

        case "hs.freestanding-hs-30":
            return [
                FormPhase(
                    id: "phase1",
                    title: "Kick-Up",
                    cues: [
                        "Hands shoulder-width",
                        "One long controlled kick",
                        "Arrive, do not crash"
                    ],
                    instruction: "Set the hands shoulder-width with fingers spread. Kick with one long lever only hard enough to arrive near vertical. A clean entry finds the line; it does not blast past the balance point and hope for a save.",
                    assetName: "hs_freestanding-hs-30_phase1",
                    fallbackSymbol: "figure.run"
                ),
                FormPhase(
                    id: "phase2",
                    title: "Stack",
                    cues: [
                        "Wrists, shoulders, hips, ankles",
                        "Elbows locked",
                        "Shoulders tall"
                    ],
                    instruction: "Build the vertical stack from the floor upward: hands grip, elbows lock, shoulders elevate, ribs tuck, hips extend, and ankles reach. The straighter the stack, the less strength the hold wastes.",
                    assetName: "hs_freestanding-hs-30_phase2",
                    fallbackSymbol: "line.diagonal"
                ),
                FormPhase(
                    id: "phase3",
                    title: "Brake",
                    cues: [
                        "Fingertips catch overbalance",
                        "Palm heel catches underbalance",
                        "Corrections stay tiny"
                    ],
                    instruction: "Balance mostly through the hands. Press fingertips into the floor when the body tips too far; shift pressure toward the heel of the hand when it falls short. Keep corrections small so the shoulders and legs stay quiet.",
                    assetName: "hs_freestanding-hs-30_phase3",
                    fallbackSymbol: "hand.tap.fill"
                ),
                FormPhase(
                    id: "phase4",
                    title: "Hold",
                    cues: [
                        "Ribs down, glutes tight",
                        "Legs together",
                        "Breathe, then exit clean"
                    ],
                    instruction: "Hold the hollow line with calm breathing: ribs down, glutes on, legs together, toes reaching. The rep ends with an intentional step-down or cartwheel bail, not a collapse out of tired shoulders.",
                    assetName: "hs_freestanding-hs-30_phase4",
                    fallbackSymbol: "checkmark.seal.fill"
                ),
            ]

        case "hs.wall-plank":
            return [
                phase("phase1", "Set Hands", "Hands shoulder-width, fingers spread, elbows locked before the feet climb.", "hand.raised.fill", assetName: "hs_wall-plank_phase1"),
                phase("phase2", "Walk Up", "Step the feet up the wall slowly. Stop before the ribs flare or elbows soften.", "arrow.up.right", assetName: "hs_wall-plank_phase2"),
                phase("phase3", "Push Tall", "Press the floor away, head between arms, ribs tucked, glutes on.", "arrow.up.circle.fill", assetName: "hs_wall-plank_phase3"),
                phase("phase4", "Walk Down", "Exit with the same control. Do not collapse or jump away from the wall.", "checkmark.seal.fill", assetName: "hs_wall-plank_phase4")
            ]

        case "hs.headstand":
            return [
                phase("phase1", "Tripod", "Hands and head form a stable triangle; palms press into the floor.", "triangle.fill", assetName: "hs_headstand_phase1"),
                phase("phase2", "Load", "Shift weight into the hands so the neck stays long and light.", "hand.raised.fill", assetName: "hs_headstand_phase2"),
                phase("phase3", "Tuck", "Lift knees to the arms, then pull into a compact tuck without kicking.", "arrow.up.circle.fill", assetName: "hs_headstand_phase3"),
                phase("phase4", "Extend", "Raise the legs slowly to vertical, hold quietly, then exit with control.", "checkmark.seal.fill", assetName: "hs_headstand_phase4")
            ]

        case "hs.tuck-handstand":
            return [
                phase("phase1", "Stack", "Start from a tall handstand with elbows locked and shoulders by the ears.", "line.diagonal", assetName: "hs_tuck-handstand_phase1"),
                phase("phase2", "Draw In", "Pull knees toward the chest while the hips stay over the hands.", "rectangle.compress.vertical", assetName: "hs_tuck-handstand_phase2"),
                phase("phase3", "Balance", "Keep pushing tall; balance through fingertips instead of bending elbows.", "hand.tap.fill", assetName: "hs_tuck-handstand_phase3"),
                phase("phase4", "Re-Extend", "Open back to handstand or step down before the shoulder line breaks.", "arrow.up.circle.fill", assetName: "hs_tuck-handstand_phase4")
            ]

        case "hs.tuck-press":
            return [
                phase("phase1", "Compress", "Hands planted, knees tight, hips high, elbows locked.", "rectangle.compress.vertical", assetName: "hs_tuck-press_phase1"),
                phase("phase2", "Lean", "Shoulders move past wrists so the feet can become light.", "arrow.forward.circle.fill", assetName: "hs_tuck-press_phase2"),
                phase("phase3", "Float", "Feet lift quietly with no jump; knees stay tucked until hips stack.", "arrow.up.circle.fill", assetName: "hs_tuck-press_phase3"),
                phase("phase4", "Stack", "Press tall into tuck handstand or open to a full handstand finish.", "checkmark.seal.fill", assetName: "hs_tuck-press_phase4")
            ]

        case "hs.straddle-press":
            return [
                phase("phase1", "Fold", "Hands down, legs wide, active pancake compression.", "figure.flexibility", assetName: "hs_straddle-press_phase1"),
                phase("phase2", "Lean", "Shoulders pass over wrists while hips rise above the hands.", "arrow.forward.circle.fill", assetName: "hs_straddle-press_phase2"),
                phase("phase3", "Circle", "Legs stay wide and light; do not close them before vertical.", "arrow.triangle.2.circlepath", assetName: "hs_straddle-press_phase3"),
                phase("phase4", "Close", "Once stacked, bring legs together and hold the handstand.", "checkmark.seal.fill", assetName: "hs_straddle-press_phase4")
            ]

        case "hs.press-to-handstand":
            return [
                phase("phase1", "Load", "Hands rooted, arms straight, shoulders elevated before the feet move.", "hand.raised.fill", assetName: "hs_press-to-handstand_phase1"),
                phase("phase2", "Compress", "Pull legs close to the torso to shorten the lever.", "rectangle.compress.vertical", assetName: "hs_press-to-handstand_phase2"),
                phase("phase3", "Lift", "Hips travel over shoulders while the feet float, not hop.", "arrow.up.forward", assetName: "hs_press-to-handstand_phase3"),
                phase("phase4", "Align", "Open into a stacked handstand and pause before counting the rep.", "checkmark.seal.fill", assetName: "hs_press-to-handstand_phase4")
            ]

        case "hs.wall-supported-oah":
            return [
                phase("phase1", "Stack", "Use a chest-to-wall handstand with toes lightly on the wall, arms locked, shoulders elevated, and ribs pulled down before shifting weight.", "rectangle.portrait", assetName: "hs_wall-supported-oah_phase1"),
                phase("phase2", "Straddle", "Open into a wide straddle while the toes keep light wall contact. The wall gives feedback; it should not become a heavy heel slam.", "figure.flexibility", assetName: "hs_wall-supported-oah_phase2"),
                phase("phase3", "Shift", "Move hips over the support hand while the free hand turns into fingertips. Keep the support elbow locked and shoulder tall.", "arrow.left.and.right", assetName: "hs_wall-supported-oah_phase3"),
                phase("phase4", "Unload", "Float the free hand or keep one fingertip down only. End the rep before the support shoulder sinks or the wall starts carrying the balance.", "hand.point.up.left.fill", assetName: "hs_wall-supported-oah_phase4")
            ]

        case "oah.one-arm-handstand-5s":
            return [
                phase("phase1", "Enter", "Start from a freestanding two-hand straddle handstand. Lock the elbows, push tall through both shoulders, and settle the ribs before transferring.", "figure.gymnastics", assetName: "oah_one-arm-handstand-5s_phase1"),
                phase("phase2", "Align", "Shift the hips over the support hand while the wide straddle stays open. The free hand becomes lighter, but it is not gone yet.", "line.diagonal", assetName: "oah_one-arm-handstand-5s_phase2"),
                phase("phase3", "Transfer", "Reduce the free hand to fingertips and let the support fingers steer the floor. Keep the body from twisting toward the lifted side.", "hand.tap.fill", assetName: "oah_one-arm-handstand-5s_phase3"),
                phase("phase4", "5 Sec", "Lift the free hand into a wide-straddle one-arm hold for a short clean count. Exit before the support shoulder drops or the hold turns into a save.", "checkmark.seal.fill", assetName: "oah_one-arm-handstand-5s_phase4")
            ]

        case "oah.full-one-arm-handstand":
            return [
                phase("phase1", "Enter", "Enter from a controlled two-hand straddle handstand. Use the wide shape only to organize the transfer, not as the final standard.", "figure.gymnastics", assetName: "oah_full-one-arm-handstand_phase1"),
                phase("phase2", "Stack", "Stack the hips over the support hand and begin narrowing the legs. The support shoulder stays elevated while the free hand gets light.", "line.diagonal", assetName: "oah_full-one-arm-handstand_phase2"),
                phase("phase3", "Lift", "Peel the free hand fully off the floor and hold the line with the support fingers. Keep narrowing toward the full shape without bending the elbow.", "hand.tap.fill", assetName: "oah_full-one-arm-handstand_phase3"),
                phase("phase4", "Full", "Finish in the cleanest one-arm line you own: free hand off, support elbow locked, shoulder tall, and legs close or only slightly apart.", "checkmark.seal.fill", assetName: "oah_full-one-arm-handstand_phase4")
            ]

        case "pp.dead-hang":
            return hangPhases(assetPrefix: "pp_dead-hang")
        case "pp.pullup", "pp.strict-pullup", "pp.wide-pullup":
            return verticalPullPhases(
                title: skillId == "pp.wide-pullup" ? "Wide Pull-Up" : (skillId == "pp.strict-pullup" ? "Strict Pull-Up" : "Pull-Up"),
                grip: skillId == "pp.wide-pullup" ? "Take an overhand grip wider than shoulder width. Use a width you can control without shoulder pinching; wider is not better if range disappears." : "Take an overhand grip around shoulder width to slightly wider. Wrap the thumb if possible and set the body still before the first pull.",
                top: skillId == "pp.wide-pullup" ? "Pull until the chin clearly clears the bar while the elbows drive down and slightly out. Do not trade the wider grip for a short half rep." : "Pull until the chin clearly clears the bar. Think elbows down toward the ribs and chest rising, not neck reaching.",
                assetPrefix: "pp_pullup"
            )
        case "pp.chin-up", "pp.strict-chin-up":
            return chinUpPhases(assetPrefix: "pp_chin-up", strict: skillId == "pp.strict-chin-up")
        case "pp.weighted-pullup", "pp.weighted-chin-up":
            return weightedPullPhases(
                isChin: skillId == "pp.weighted-chin-up",
                assetPrefix: skillId == "pp.weighted-chin-up" ? "pp_weighted-chin-up" : "pp_weighted-pullup"
            )
        case "pp.explosive-pullup", "pp.clapping-pullup":
            return explosivePullPhases(
                isClapping: skillId == "pp.clapping-pullup",
                assetPrefix: skillId == "pp.clapping-pullup" ? "pp_clapping-pullup" : "pp_explosive-pullup"
            )
        case "pp.archer-pullup":
            return archerPullPhases(assetPrefix: "pp_archer-pullup")
        case "pp.oap-negative":
            return soloArmPhases(skillId: skillId, assetPrefix: "pp_oap-negative")
        case "pp.one-arm-pullup":
            return soloArmPhases(skillId: skillId, assetPrefix: "pp_one-arm-pullup")
        case "pp.heighted-chin-up":
            return heightedChinPhases(assetPrefix: "pp_heighted-chin-up")
        case "pp.one-arm-chin-up":
            return soloArmPhases(skillId: skillId, assetPrefix: "pp_one-arm-chin-up")
        case "pp.l-sit-chin-up":
            return lSitChinPhases(assetPrefix: "pp_l-sit-chin-up")
        case "pp.incline-row", "pp.row", "pp.decline-row", "pp.one-arm-row", "pp.tuck-row", "pp.straddle-row", "pp.tuck-front-lever-pullup":
            return rowPhases(skillId: skillId)
        case "pp.ring-muscle-up":
            return ringMuscleUpPhases(assetPrefix: "pp_ring-muscle-up")
        case "pp.strict-muscle-up":
            return strictMuscleUpPhases(assetPrefix: "pp_strict-muscle-up")
        case "cal.plank-30":
            return forearmPlankPhases()
        case "cl.hollow-body-30":
            return hollowBodyPhases(assetPrefix: "cl_hollow-body-30")
        case "cl.crunch", "cl.reverse-crunch", "cl.levitation-crunch", "cl.inverted-situp", "cl.decline-situp":
            return coreFlexionPhases(skillId: skillId)
        case "cl.bird-dog-plank", "cl.superman-plank":
            return antiRotationPhases(skillId: skillId)
        case "cl.extended-plank", "cl.knee-ab-rollout", "cl.standing-ab-rollout":
            return rolloutPlankPhases(skillId: skillId)
        case "cl.knee-raise", "cl.leg-raise", "cl.hanging-knee-raise", "cl.hanging-leg-raise", "cl.toes-to-bar":
            return raisePhases(skillId: skillId)
        case "cal.l-sit-10", "cl.semi-straddle-l-sit", "cl.straddle-l-sit", "cl.v-sit", "cl.vertical-l-sit":
            return lSitFamilyPhases(skillId: skillId)
        case "cl.tuck-front-lever", "cl.straddle-front-lever", "cl.full-front-lever":
            return frontLeverPhases(skillId: skillId)
        case "cl.german-hang", "cl.skin-the-cat", "cl.tuck-back-lever", "cl.straddle-back-lever", "cl.full-back-lever":
            return backLeverPhases(skillId: skillId)
        case "cl.three-sixty-pulls":
            return threeSixtyPullPhases()
        case "cl.dragon-flag-hip-raise", "cl.dragon-flag":
            return dragonFlagPhases(skillId: skillId)
        case "cal.incline-pushup", "cal.pushup", "cal.decline-pushup":
            return pushupPhases(skillId: skillId)
        case "cal.diamond-pushup", "cal.sphinx-pushup":
            return closePushPhases(skillId: skillId)
        case "cal.5-dips", "cal.bench-dip":
            return dipPhases(skillId: skillId)
        case "cal.ring-dip":
            return ringDipPhases()
        case "cal.pike-pushup", "cal.elevated-pike-pushup", "cal.floating-pike-pushup":
            return pikePushPhases(skillId: skillId)
        case "cal.handstand-pushup":
            return handstandPushPhases()
        case "cal.ninety-degree-pushup":
            return ninetyDegreePushPhases()
        case "cal.clapping-handstand-pushup":
            return clappingHandstandPushPhases()
        case "cal.pseudo-planche-pushup", "cal.tuck-planche-pushup":
            return planchePushPhases(skillId: skillId)
        case "hs.crow-pose", "hs.crane-pose", "hs.flying-crow":
            return crowFamilyPhases(skillId: skillId)
        case "hs.elbow-lever", "hs.one-arm-elbow-lever":
            return elbowLeverPhases(skillId: skillId)
        case "pl.tuck-planche", "pl.straddle-planche", "pl.half-lay-planche", "pl.full-planche", "pl.bent-arm-planche":
            return plancheHoldPhases(skillId: skillId)
        case "cal.archer-pushup", "cal.one-arm-pushup":
            return unilateralPushPhases(skillId: skillId)
        case "cal.explosive-pushup", "cal.clapping-pushup", "cal.triple-clap-pushup":
            return explosivePushPhases(skillId: skillId)
        case "cal.bent-arm-press":
            return bentArmPressPhases()
        case let id where id.hasPrefix("ld."):
            return legPhases(skillId: id)

        default:
            return []  // fallback to numbered cue list
        }
    }


    static func phase(_ id: String, _ title: String, _ instruction: String, _ symbol: String, assetName: String? = nil) -> FormPhase {
        FormPhase(
            id: id,
            title: title,
            cues: [],
            instruction: instruction,
            assetName: assetName,
            fallbackSymbol: symbol
        )
    }

    static func assetName(_ prefix: String?, _ phase: String) -> String? {
        guard let prefix else { return nil }
        return "\(prefix)_\(phase)"
    }
}
