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
                    title: "Breathe",
                    cues: [
                        "Hold the line while breathing",
                        "Stop before shape breaks",
                        "Step down with control"
                    ],
                    instruction: "The hold only counts while the position survives normal breathing. If the low back arches, elbows bend, or shoulders sink, step down under control and use shorter sets.",
                    assetName: "hs_wall-handstand-30_phase4",
                    fallbackSymbol: "lungs.fill"
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
                phase("phase1", "Stack", "Build a tight wall handstand with shoulders elevated and ribs controlled.", "rectangle.portrait", assetName: "hs_wall-supported-oah_phase1"),
                phase("phase2", "Straddle", "Open the legs so balance can shift without dumping sideways.", "figure.flexibility", assetName: "hs_wall-supported-oah_phase2"),
                phase("phase3", "Shift", "Move weight into one hand while the working shoulder stays tall.", "arrow.left.and.right", assetName: "hs_wall-supported-oah_phase3"),
                phase("phase4", "Unload", "Reduce the free hand to fingertips or a brief hover.", "hand.point.up.left.fill", assetName: "hs_wall-supported-oah_phase4")
            ]

        case "oah.one-arm-handstand-5s":
            return [
                phase("phase1", "Enter", "Kick or press to a stable straddle handstand before shifting.", "figure.gymnastics", assetName: "oah_one-arm-handstand-5s_phase1"),
                phase("phase2", "Align", "Push tall, control ribs, and center hips over the support side.", "line.diagonal", assetName: "oah_one-arm-handstand-5s_phase2"),
                phase("phase3", "Transfer", "Make the free hand light while the working hand steers the floor.", "hand.tap.fill", assetName: "oah_one-arm-handstand-5s_phase3"),
                phase("phase4", "Balance", "Lift the free hand, breathe, and exit before the shoulder sinks.", "checkmark.seal.fill", assetName: "oah_one-arm-handstand-5s_phase4")
            ]

        case "oah.full-one-arm-handstand":
            return [
                phase("phase1", "Enter", "Kick or press to a stable straddle handstand before shifting.", "figure.gymnastics", assetName: "oah_full-one-arm-handstand_phase1"),
                phase("phase2", "Align", "Push tall, control ribs, and center hips over the support side.", "line.diagonal", assetName: "oah_full-one-arm-handstand_phase2"),
                phase("phase3", "Transfer", "Make the free hand light while the working hand steers the floor.", "hand.tap.fill", assetName: "oah_full-one-arm-handstand_phase3"),
                phase("phase4", "Balance", "Lift the free hand, breathe, and exit before the shoulder sinks.", "checkmark.seal.fill", assetName: "oah_full-one-arm-handstand_phase4")
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
            return chinUpPhases(assetPrefix: "pp_chin-up")
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
        case "pp.oap-negative", "pp.one-arm-pullup":
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
        case "cl.german-hang", "cl.skin-the-cat", "cl.straddle-back-lever", "cl.full-back-lever":
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
        case let id where id.hasPrefix("co."):
            return conditioningPhases(skillId: id)

        default:
            return []  // fallback to numbered cue list
        }
    }

    private static func hangPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Grip", "Set both hands just outside shoulder width, wrap the bar securely, and let the body settle before loading the hang. If grip is the limiter, use shorter clean holds instead of twisting on the bar.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shoulders", "Reach long through straight arms, then keep the shoulders active enough that the neck stays long and the ears do not swallow the shoulders. This active bottom becomes the start of every pull.", "arrow.down.circle.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Body Line", "Keep ribs down, glutes lightly squeezed, and legs together. The hold should look still from the side, not like a swing building momentum.", "figure.core.training", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Finish", "End by stepping down or releasing under control. Do not turn the last second into a sudden drop from loose shoulders.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func verticalPullPhases(title: String, grip: String, top: String, assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Set", "\(grip) Start from straight arms with ribs down, glutes lightly on, and legs quiet. Pause long enough that the body is not swinging before the pull begins.", "figure.climbing", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Initiate", "Begin by pulling the shoulder blades down and slightly back. The elbows have not done the whole job yet; this sets the lats and keeps the neck from shrugging.", "arrow.down.backward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Pull", "\(top) Keep the path smooth and vertical. If the chin reaches forward or the knees kick, use assistance or fewer reps.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Lower under control until the arms are straight again. The rep is not finished at the top; the controlled return proves you own the full range.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func chinUpPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Chin Grip", "Set both hands shoulder-width or slightly narrower. From your perspective, the knuckles wrap over the far side of the bar; from a front camera, the knuckle side of both hands is visible. Keep thumbs underneath and wrists stacked.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Pull", "Begin the pull without letting the hands roll. The camera should still see knuckles, not open palms, while elbows drive down and slightly forward under the bar.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Top", "Clear the chin with the same hand shape: knuckle side visible from the front, thumbs underneath, wrists not folded over, elbows close to the ribs, and shoulders down.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Lower to straight arms while the grip stays unchanged. If a front view no longer shows the knuckle side clearly, reset before the next rep.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func weightedPullPhases(isChin: Bool, assetPrefix: String? = nil) -> [FormPhase] {
        let name = isChin ? "weighted chin-up" : "weighted pull-up"
        let grip = isChin ? "supinated chin-up grip" : "overhand pull-up grip"
        if isChin {
            return [
                phase("phase1", "Load", "Set the load, then take a true chin grip: from your perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Keep thumbs underneath and start from straight arms.", "scalemass.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Brace before pulling while the grip stays visibly underhand. A front view should show knuckles on both hands, wrists stacked, elbows ready to travel down and slightly forward, and the load quiet.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Pull", "Pull with the same hand orientation the whole way. The camera should still see knuckles, thumbs stay wrapped underneath, elbows drive down and forward, and the wrists do not roll into overhand.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control", "Lower until the arms are straight while the grip stays unchanged. If the load makes the visible knuckles disappear or the grip flip, reduce weight before adding reps.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
        return [
            phase("phase1", "Load", "Attach the load so it hangs still. Step or jump carefully to the bar and wait for the plate, vest, or dumbbell to stop swinging before starting the \(name).", "scalemass.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Brace", "Set a \(grip), straighten the arms, brace the trunk, and keep the legs quiet. The added weight should not pull the body into an arch or swing.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Pull", "Pull with the same standard as the bodyweight version: shoulder blades set, elbows drive down, and chin clears the bar without shortening the range.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Control", "Lower until the arms are straight while the load stays quiet. If the plate swings or range disappears, reduce weight before adding reps.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func explosivePullPhases(isClapping: Bool, assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Dead Stop", "Start from a still active hang. Explosive work begins from control; do not preload the rep with a hidden swing or knee kick.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Snap", "Pull as hard and fast as possible while staying hollow. Think bar toward lower chest, not chin barely over bar.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", isClapping ? "Release" : "Height", isClapping ? "Only release when the pull is high enough that both hands can leave the bar, clap once, and return to the bar without panic." : "Measure the rep by height. Stop the set when the body no longer reaches the same target.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Absorb", "Re-grip or finish the high pull with active shoulders, then lower under control. Power reps still need a clean landing.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func archerPullPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Wide Set", "Take a wide overhand grip and start from a full, still hang. Pick a width that allows one arm to straighten without shoulder pain.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shift", "Pull toward one hand while the opposite arm stays long. The straight arm guides the path; the working arm does most of the pull.", "arrow.up.left", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Finish", "Bring the chest toward the working hand without spinning the torso open. If both elbows bend equally, regress to banded archers or archer rows.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Return", "Lower back to a full hang under control before switching sides or repeating. Match the weaker side instead of letting the stronger side define the set.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func soloArmPhases(skillId: String, assetPrefix: String? = nil) -> [FormPhase] {
        let isNegative = skillId == "pp.oap-negative"
        let isChin = skillId == "pp.one-arm-chin-up"
        let hangTitle = isChin ? "Chin Hang" : (isNegative ? "Top Set" : "One-Arm Hang")
        let hangInstruction = isNegative ? "Start at the top with one hand on the bar, shoulder packed, and torso quiet. Use a box or assist hand to arrive cleanly instead of jumping into chaos." : (isChin ? "Start from an active one-arm hang with the working hand supinated: from your perspective, knuckles wrap over the far side of the bar; from a front camera, knuckles are visible. Thumb stays underneath and free arm stays off the bar." : "Start from an active one-arm hang. Pull the shoulder down away from the ear before bending the elbow.")
        let pullInstruction = isNegative ? "Lower slowly through the full range without dropping, shrugging, or spinning out. Use assistance if any part becomes a fall." : (isChin ? "Pull the elbow down and slightly forward while the hand stays underhand. The camera should still see the knuckle side of the working hand, and the body resists twisting into the bar." : "Pull the elbow toward the ribs or hip while resisting rotation. Some body turn is normal; wild twisting means the assist level is too low.")
        return [
            phase("phase1", hangTitle, hangInstruction, "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Scap First", isChin ? "Keep the working hand underhand while the shoulder blade depresses. From the front, the knuckle side stays visible; the palm does not open toward the camera." : "Depress and slightly retract the shoulder blade. This tiny first movement protects the shoulder and gives the elbow a stronger path.", "arrow.down.circle.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", isNegative ? "Lower" : "Pull", pullInstruction, "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Control", isChin ? "Lower without letting the working wrist roll over the bar. A front view should still show knuckles, and any grip flip means the rep should be reset." : "Finish with a controlled lower or controlled top. Keep volume low and stop if elbow tendon pain rises during the session.", "exclamationmark.triangle.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func heightedChinPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Chin Grip", "Set a true chin grip: from your perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Thumbs wrap underneath and hands stay shoulder-width or slightly narrower.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "High Pull", "Keep the grip readable as the elbows drive down and slightly forward. The camera should still see knuckles, and the chest rises close without the wrists rolling over.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Chest To Bar", "Pull until the upper chest or collarbone reaches the bar with the underhand grip still intact: visible knuckles from the front, thumbs underneath, forearms under the hands. A grip-flipped pull-up does not count.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Control", "Lower under control back to straight arms while preserving the same visible-knuckle chin grip. Stop the set once height, range, or grip orientation starts fading.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func lSitChinPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "L Set", "Take a chin-up grip first: from your perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Then raise the legs toward horizontal and lock in the hollow trunk.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Pull", "Keep the L shape while driving elbows down and slightly forward. The hands stay underhand with visible knuckles from the front; do not let the wrist roll into a pull-up grip.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Top", "Pause briefly with the chin over the bar, legs still lifted, and knuckles still visible from the front. Do not let the knees bend or the grip flip to steal the finish.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Return to straight arms while maintaining the L and the same hand orientation. If the front view no longer shows the knuckle side, reset before the next rep.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func rowPhases(skillId: String) -> [FormPhase] {
        if skillId == "pp.tuck-row" || skillId == "pp.straddle-row" || skillId == "pp.tuck-front-lever-pullup" {
            let shape = skillId == "pp.straddle-row" ? "straddle front-lever shape" : "tucked front-lever shape"
            let assetPrefix = "pp_tuck-row"
            return [
                phase("phase1", "Lever Set", "Set a \(shape) before bending the arms. Shoulders stay depressed, ribs stay down, and hips stay high enough to match the chosen lever.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Pull", "Row from the lever without opening the tuck, dropping the hips, or turning it into a normal pull-up. Use band assistance or a shorter range if the shape changes.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Top", "Pause at the top while keeping the same lever. The row only counts if the body line survives the hardest point.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Return", "Lower back into the same lever shape under control. If the eccentric collapses, regress the lever or reduce reps.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        }

        let oneArm = skillId == "pp.one-arm-row"
        let decline = skillId == "pp.decline-row"
        let standardRow = skillId == "pp.row"
        let assetPrefix = oneArm ? "pp_one-arm-row" : (standardRow ? "pp_row" : "pp_incline-row")
        return [
            phase("phase1", "Set Angle", decline ? "Set the bar or rings so the body is near horizontal, often with feet elevated. Keep a straight line from head to heels." : (standardRow ? "Set a low bar or rings so the body is close to horizontal, heels grounded, and the chest can reach the hands without neck reaching." : "Set the bar or rings high enough that every rep can reach the same top. Walk the feet forward to make it harder, back to make it easier."), "slider.horizontal.3", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Brace", oneArm ? "Brace hard and keep the torso square. The free hand may assist lightly at easier levels, but it cannot twist the body into the finish." : "Squeeze glutes, keep ribs down, and start with straight arms. The body should feel like a plank before the elbows bend.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Row", oneArm ? "Pull with one arm while resisting rotation. The working elbow travels back; the torso stays quiet." : "Pull the lower chest or ribs toward the bar. Lead with shoulder blades and elbows, not the chin.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Pause briefly at the top, then lower to straight arms without hips sagging. Progress only when every rep keeps the same body line.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func hollowBodyPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Brace", "Lie on your back and lock the pelvis first: ribs down, tailbone slightly tucked, low back sealed to the floor. If the low back lifts, the set has already drifted.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Short Hollow", "Lift shoulders and bent legs while keeping the spine glued down. Use this tucked shape until you can breathe normally without losing the brace.", "arrow.up.left.and.arrow.down.right", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Long Hollow", "Reach arms and legs longer only as far as the low back stays pressed down. Legs low with an arched back is not harder; it is just a broken hollow.", "rectangle.expand.vertical", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Transfer", "Use the same ribs-down body line in rocks, hangs, levers, and handstands. The point is not just ab burn; it is owning one clean trunk shape under motion.", "arrow.triangle.2.circlepath", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func forearmPlankPhases() -> [FormPhase] {
        let assetPrefix = "cal_plank-30"
        return [
            phase("phase1", "Stack", "Set forearms on the floor with elbows under shoulders. Root the forearms before lifting into the hold.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Brace", "Zip ribs toward hips, lightly squeeze glutes and quads, and keep the neck long.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Hold", "Keep one long line from head to heels while breathing quietly. No sag, pike, or shoulder collapse.", "timer", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Exit", "Lower with the same line you held. Do not finish by collapsing into the low back or shoulders.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func coreFlexionPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "cl.reverse-crunch":
            return [
                phase("phase1", "Tabletop", "Start on your back with knees bent, shins lifted, and shoulders grounded. The setup should be still before the curl.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Flatten ribs and steady the pelvis. Hands can press lightly into the floor for control.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Curl", "Peel the tailbone toward the ribs without throwing the knees. Keep the motion small and heavy.", "arrow.up.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control", "Return slowly without leg swing or low-back arch. Reset before the next rep.", "metronome", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "cl.levitation-crunch":
            return [
                phase("phase1", "Hollow", "Hover shoulders and legs with the low back pressed down. Shorten the lever if the spine lifts.", "circle.hexagongrid.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Gather", "Bring knees and ribs toward center together. The neck does not yank the rep.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Compress", "Pause briefly in the tight shape while the low back stays heavy.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Reopen", "Extend back to a quiet hollow hover without dropping shoulders or heels.", "arrow.up.left.and.arrow.down.right", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "cl.inverted-situp":
            return [
                phase("phase1", "Anchor", "Secure the hook or grip before moving. The inverted setup must feel stable first.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Lock ribs and pelvis while upside down. Stop if the anchor shifts.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Curl", "Fold the trunk toward the legs or bar like a strict crunch, not a swing.", "arrow.up.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Lower", "Return slowly without whipping the spine or losing the hook.", "arrow.down.circle.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "cl.decline-situp":
            return [
                phase("phase1", "Lock In", "Secure feet and choose a modest bench angle. More decline only counts if control stays clean.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Set ribs down and pelvis controlled before the torso leaves the bench.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Rise", "Curl first, then sit tall. Do not yank the head or rely only on hip flexors.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Descend", "Lower slowly with ribs down. No flopping into a back arch.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Set", "Plant feet, support the head lightly if needed, and keep elbows wide. The hands do not pull.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Exhale", "Exhale and soften ribs down before lifting. The low back stays controlled.", "wind", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Curl", "Lift shoulder blades by drawing ribs toward pelvis. Small and precise beats high and sloppy.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Uncurl", "Lower vertebra by vertebra until the shoulder blades touch down.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    private static func antiRotationPhases(skillId: String) -> [FormPhase] {
        let isBirdDog = skillId == "cl.bird-dog-plank"
        let prefix = isBirdDog ? "cl_bird-dog-plank" : "cl_superman-plank"
        return [
            phase("phase1", "Stack", "Start with ribs stacked over pelvis, glutes lightly on, and hands pressing the floor away. Do not begin the reach from a sagging plank.", "rectangle.compress.vertical", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Brace", "Brace like someone is about to nudge your ribs sideways. The trunk should stay quiet before any limb leaves the floor.", "shield.lefthalf.filled", assetName: assetName(prefix, "phase2")),
            phase("phase3", isBirdDog ? "Reach" : "Long Lever", isBirdDog ? "Extend the opposite arm and leg without letting the hips roll open. Arm stays near shoulder height; leg stays near hip height." : "Reach the limbs long while the hips stay level. A higher leg or twisted torso makes the hold easier and less useful.", "arrow.up.left.and.arrow.down.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Return", "Bring the limbs back slowly, then switch sides. The return should be as controlled as the hold, with no hip drop when the support changes.", "arrow.uturn.backward", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func rolloutPlankPhases(skillId: String) -> [FormPhase] {
        let isRollout = skillId.contains("rollout")
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", isRollout ? "Start" : "Reach", isRollout ? "Set ribs down, glutes on, and shoulders active before the wheel moves. The spine position is the skill." : "Walk hands forward only as far as the ribs stay tucked and the hips stay level.", "figure.core.training", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Extend", isRollout ? "Roll out slowly while keeping a hollow body. Stop before the low back sags; range is earned, not forced." : "Hold the longer lever with shoulders packed and neck neutral. Hands farther forward only counts if the body line survives.", "arrow.forward", assetName: assetName(prefix, "phase2")),
            phase("phase3", "End Range", "Pause at the hardest point without breath-holding or collapsing the shoulders. If the brace breaks, shorten the lever on the next set.", "pause.circle.fill", assetName: assetName(prefix, "phase3")),
            phase("phase4", isRollout ? "Return" : "Exit", isRollout ? "Pull back with lats and abs together. Do not pike the hips first to escape the hard range." : "Walk the hands back under control. The exit should not be a sudden hip pike or shoulder shrug.", "arrow.backward", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func raisePhases(skillId: String) -> [FormPhase] {
        let hanging = skillId.contains("hanging") || skillId == "cl.toes-to-bar"
        let straight = skillId.contains("leg") || skillId == "cl.toes-to-bar"
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", hanging ? "Active Hang" : "Set", hanging ? "Hang with shoulders pulled down enough that the body is quiet. Start each rep from control, not from a pendulum." : "Press the low back down and set the pelvis before the legs move. The floor version trains the same anti-arch position as harder hanging raises.", hanging ? "figure.hanging" : "figure.core.training", assetName: assetName(prefix, "phase1")),
            phase("phase2", straight ? "Lift" : "Tuck", straight ? "Raise straight legs from the pelvis, not by throwing the feet. Keep knees locked only if the trunk can stay controlled." : "Drive knees toward the chest and curl the pelvis at the top. A waist-high knee lift is not the same as a tight knee raise.", "arrow.up", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId == "cl.toes-to-bar" ? "Touch" : "Curl", skillId == "cl.toes-to-bar" ? "Compress until the toes actually reach the bar between the hands. If the knees bend or the body swings, regress to strict leg raises." : "Finish with a small posterior pelvic curl so the abs do more than the hip flexors. Keep the bar or floor quiet.", "scope", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Lower", "Lower slower than you lifted. Do not let gravity drop the legs and create the next rep's swing.", "arrow.down", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func lSitFamilyPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        let target = skillId == "cl.v-sit" || skillId == "cl.vertical-l-sit" ? "above horizontal" : "near horizontal"
        return [
            phase("phase1", "Support", "Press the floor, bars, or parallettes down until the shoulders move away from the ears. Elbows stay locked before the legs lift.", "arrow.down.to.line", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Tuck", "Lift the hips and bring knees toward the chest. This teaches support strength and compression without forcing hamstrings to decide the skill.", "figure.core.training", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId.contains("straddle") ? "Open" : "Extend", skillId.contains("straddle") ? "Open the legs only as wide as you can keep them lifted. Both knees stay locked and both legs stay above the hands." : "Extend one or both legs while keeping the hips off the floor. Quads stay on; toes point; shoulders do not shrug.", "arrow.left.and.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Hold", "Hold the final shape with legs \(target), arms locked, and breathing steady. End the set when the hips sink or knees soften.", "checkmark.seal.fill", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func frontLeverPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Tuck", "Start from straight arms and a tight tuck. Depress the shoulders, pull the hands toward the hips, and bring hips to shoulder height before lengthening the lever.", "figure.hanging", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Open Tuck", "Open the hips slightly while keeping ribs down and elbows locked. If the back arches or hips drop, return to the tighter tuck.", "rectangle.expand.vertical", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId == "cl.tuck-front-lever" ? "Line Check" : "Straddle", skillId == "cl.tuck-front-lever" ? "Hold the shortest lever perfectly: shoulders down, arms straight, and hips level. This is the shape that buys every later progression." : "Extend into a wide straddle with toes pointed and hips level. A wide clean straddle beats a narrow, sagging one.", "arrow.left.and.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", skillId == "cl.full-front-lever" ? "Full Lever" : "Exit", skillId == "cl.full-front-lever" ? "Bring legs together only when the horizontal body line stays quiet. The final hold is face-up, straight-arm, and ribs-down from shoulders to toes." : "Exit by returning to tuck or inverted hang under control. Dropping out teaches panic instead of lever strength.", "checkmark.seal.fill", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func backLeverPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        if skillId == "cl.german-hang" {
            return [
                phase("phase1", "Enter", "Move through a skin-the-cat path slowly. Use low rings or foot assistance if the shoulders cannot control the descent.", "figure.gymnastics", assetName: assetName(prefix, "phase1")),
                phase("phase2", "Open", "Let the arms travel behind the body with elbows straight and rings quiet. Stop before sharp anterior shoulder pain.", "arrow.down.backward", assetName: assetName(prefix, "phase2")),
                phase("phase3", "Breathe", "Hold the deepest pain-free range with calm breathing. The chest opens, but the shoulders do not get dumped into the joint.", "lungs.fill", assetName: assetName(prefix, "phase3")),
                phase("phase4", "Exit", "Reverse the exact path back through inverted hang. The exit is part of the standard, not an optional escape.", "arrow.uturn.backward", assetName: assetName(prefix, "phase4"))
            ]
        }
        if skillId == "cl.skin-the-cat" {
            return [
                phase("phase1", "Hang", "Start from a quiet straight-arm ring hang. Set the shoulders and stop any swing before the pass-through begins.", "figure.hanging", assetName: assetName(prefix, "phase1")),
                phase("phase2", "Invert", "Tuck or pike the legs overhead with straight arms. Keep the rings still and the ribs controlled.", "arrow.up.forward", assetName: assetName(prefix, "phase2")),
                phase("phase3", "Pass", "Lower through the back side slowly into a pain-free German hang. Do not drop into the bottom.", "arrow.down.circle.fill", assetName: assetName(prefix, "phase3")),
                phase("phase4", "Return", "Reverse the motion back to inverted hang and then to a quiet hang. Count only reps you can bring home under control.", "arrow.triangle.2.circlepath", assetName: assetName(prefix, "phase4"))
            ]
        }
        return [
            phase("phase1", "German Hang", "Enter shoulder extension slowly through a skin-the-cat path. Stop before pain; this position is mobility and connective-tissue prep, not a dare.", "figure.gymnastics", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Tuck", "Keep elbows locked and tuck knees tight while lowering toward horizontal. Shoulders stay active; the body does not dump into the front of the joint.", "figure.core.training", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId == "cl.full-back-lever" || skillId == "cl.straddle-back-lever" ? "Straddle" : "Control", skillId == "cl.full-back-lever" || skillId == "cl.straddle-back-lever" ? "Open into a wide straddle with glutes squeezed and ribs down. Widen the legs as needed to keep the body line honest." : "Move in and out of the bottom slowly. If the shoulders shock-load or elbows bend, regress the range.", "arrow.left.and.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", skillId == "cl.full-back-lever" ? "Full Lever" : "Exit", skillId == "cl.full-back-lever" ? "Bring legs together into a face-down horizontal line only when the shoulders, elbows, and trunk stay calm." : "Return through the same path you entered. Never drop out of a German hang or back lever attempt.", "checkmark.seal.fill", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func threeSixtyPullPhases() -> [FormPhase] {
        let prefix = "cl_three-sixty-pulls"
        return [
            phase("phase1", "Load", "Start from an active hang and build a clean hollow-to-power pull. The shoulders are set before speed enters.", "figure.hanging", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Explode", "Pull above bar height before release. Height is what gives the rotation time to finish safely.", "arrow.up.circle.fill", assetName: assetName(prefix, "phase2")),
            phase("phase3", "Rotate", "Snap into a tight tuck after release and spot the bar early. Do not reach blind.", "arrow.triangle.2.circlepath", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Re-Catch", "Catch with prepared shoulders and absorb into control. A slammed dead hang is a failed catch.", "hand.raised.fill", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func dragonFlagPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Anchor", "Grip the bench, post, or pads hard enough that the shoulders stay pinned. The hands anchor the body; the neck should not strain.", "hand.raised.fill", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Lift", "Raise hips until the body forms one rigid line from shoulders to toes. Do not pike just to get the feet higher.", "arrow.up", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId == "cl.dragon-flag" ? "Lower" : "Hip Line", skillId == "cl.dragon-flag" ? "Lower as one piece for several seconds. The rep ends when the hips fold, the back arches, or the shoulders lose the anchor." : "Own the straight-body top before chasing full negatives. The hip raise is the bridge between reverse crunches and the flag.", "line.diagonal", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Reset", "Reset cleanly between reps instead of bouncing off the bottom. Dragon flag work should feel precise, not like a swinging sit-up.", "arrow.clockwise", assetName: assetName(prefix, "phase4"))
        ]
    }

    private static func pushupPhases(skillId: String) -> [FormPhase] {
        let isIncline = skillId == "cal.incline-pushup"
        let isDecline = skillId == "cal.decline-pushup"
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Plank Set", isIncline ? "Set hands on a stable elevated surface and walk feet back until the body forms one straight line. Brace ribs, glutes, and quads before bending the elbows." : (isDecline ? "Set feet on a stable box and hands on the floor under the chest. Keep ribs down so the elevated feet do not turn the rep into a banana-back press." : "Start in a strong plank with hands under the chest, ribs tucked, glutes squeezed, and legs quiet. The push-up is a moving plank before it is a chest exercise."), "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Descend", "Lower the chest and hips together. Elbows travel diagonally back around 30-45 degrees instead of flaring straight out to the sides.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Depth", isIncline ? "Touch the chest to the bench or box without losing the plank line. If you cannot reach the surface, raise the hands higher." : "Reach full depth with chest near the floor while the neck stays neutral. The head should not dive ahead of the torso.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lockout", "Press the floor away until elbows lock and shoulders stay active. Finish in the same body line you started with before the next rep.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func closePushPhases(skillId: String) -> [FormPhase] {
        let isSphinx = skillId == "cal.sphinx-pushup"
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Narrow Set", isSphinx ? "Start in a forearm plank with elbows under shoulders, ribs down, and glutes tight. The trunk stays one piece before the triceps press begins." : "Set hands close under the sternum. A true diamond is optional; use a pain-free close grip if wrists or elbows complain.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Elbows Back", isSphinx ? "Press through the forearms and begin extending the elbows while the hips stay level. Do not pike up to escape the triceps load." : "Lower with elbows tracking back near the ribs. The close grip should load triceps, not force the shoulders into a flare.", "arrow.down.backward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Full Range", isSphinx ? "Reach the hardest middle range with forearms still controlling the floor. Keep the neck long and shoulders away from the ears." : "Bring the chest toward the hands without cutting depth. If range vanishes, use an incline close-grip variation.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Triceps Lock", "Finish with a clear elbow lockout and active shoulders. The last inch of extension is the point of the close-grip path.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func dipPhases(skillId: String) -> [FormPhase] {
        let isBench = skillId == "cal.bench-dip"
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Support", isBench ? "Set hands on a stable bench behind the hips and keep the hips close to the edge. Shoulders stay controlled before the first descent." : "Start in a locked parallel-bar support with shoulders depressed, elbows straight, and body still. If support shakes, train holds first.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Lower", "Bend the elbows under control and keep them tracking back. Do not dive-bomb into the bottom or let the shoulders shrug toward the ears.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Bottom", isBench ? "Stop at the deepest pain-free range with shoulders still organized. Bench dips are a regression, not a reason to crank the shoulder forward." : "Reach shoulders level with or slightly below elbows only if mobility allows. The bottom should feel loaded, not collapsed.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Out", "Press the bars or bench down until elbows lock and shoulders stay active. Pause briefly at support before the next rep.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func ringDipPhases() -> [FormPhase] {
        let assetPrefix = "cal_ring-dip"
        return [
            phase("phase1", "RTO Support", "Begin in a still ring support with elbows locked and rings turned out if possible. The top support is part of the rep, not a place to rush through.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Rings Close", "Lower slowly while the rings stay close to the ribs. If they drift wide, use foot assistance or support holds.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Controlled Bottom", "Reach the deepest stable bottom without shoulder collapse. Rings should not wobble wildly or flare away from the body.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Turn Out", "Press back to a locked support and turn the rings out at the top. Pause until the rings are still before the next rep.", "rotate.right.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func pikePushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isElevated = skillId == "cal.elevated-pike-pushup"
        let isFloating = skillId == "cal.floating-pike-pushup"
        return [
            phase("phase1", "Pike Stack", isFloating ? "Start from a tuck or straddle support on parallettes with feet off the floor. Hips stack high and shoulders stay active before the press." : (isElevated ? "Place feet on a box and walk hands in until hips stack high. Increase box height only when the line stays controlled." : "Walk feet in and lift hips high so the body resembles an inverted V. This is vertical pressing practice, not a regular push-up."), "triangle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Tripod Path", "Lower the head between the hands into a tripod-like path. Elbows bend diagonally back instead of flaring straight sideways.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Head Target", "Touch the top of the head lightly or reach a controlled target. Do not crash into the floor or let the hips drift backward.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Tall", "Press the floor away and return hips over shoulders. Think up toward handstand, not back into an easier push-up angle.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func handstandPushPhases() -> [FormPhase] {
        let assetPrefix = "cal_handstand-pushup"
        return [
            phase("phase1", "Handstand Line", "Start in a stable wall or freestanding handstand. Hands are around shoulder width, ribs tucked, glutes on, and shoulders pushed tall.", "figure.handball", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Toes To Wall", "Lower under control so the head moves slightly in front of the hands. In a chest-to-wall rep, keep the toes pointed toward the wall instead of turning the feet away or planting the heels.", "triangle.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Soft Touch", "Lightly touch the head or pad without collapsing onto the neck. Use partial range if the descent becomes a crash.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Tall Lockout", "Press to full elbow lockout and push tall through the shoulders. Keep ribs tucked so the finish is a handstand, not a backbend.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func ninetyDegreePushPhases() -> [FormPhase] {
        let assetPrefix = "cal_ninety-degree-pushup"
        return [
            phase("phase1", "Handstand Set", "Start from a stacked handstand with elbows locked, shoulders tall, ribs tucked, and eyes between the hands. The line has to be quiet before the descent begins.", "figure.handball", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shoulders Forward", "Lean the shoulders far past the wrists before the elbows bend. The hands stay near the balance point under the body mass instead of sitting back like a regular push-up.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Floating 90", "Reach a true bent-arm planche shape: elbows near 90 degrees, shoulders forward of the wrists, hands under the center of mass, and feet completely off the floor.", "angle", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Back", "Press through the same path back toward handstand. Keep shoulders protracted and elbows tracking back; do not kick the legs to escape the press.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func clappingHandstandPushPhases() -> [FormPhase] {
        let assetPrefix = "cal_clapping-handstand-pushup"
        return [
            phase("phase1", "Strict Base", "Begin from a stable handstand push-up setup with a predictable bottom target. Do not train release work until strict reps are controlled.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Controlled Lower", "Lower like a normal chest-to-wall handstand push-up with the same wall-side direction every rep. Toes stay light on the wall, but the press comes from shoulders and triceps.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Pop Clap", "Clap only if the launch is high enough for a small near-floor release. The hands meet close under the head and shoulders; do not reach forward or let the body line flip away from the wall.", "hands.clap.fill", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Catch Tall", "Return the hands under the shoulders with elbows soft enough to absorb, then press tall. Stop the set when the catch gets noisy or the line arches.", "arrow.down.forward.circle.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func bentArmPressPhases() -> [FormPhase] {
        let assetPrefix = "cal_bent-arm-press"
        return [
            phase("phase1", "Tripod Base", "Set hands shoulder-width and place the head lightly ahead of the hands. Hips lift high before the press so the shoulders are already loaded.", "triangle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Float Hips", "Shift shoulders forward and float the feet or tuck the knees. Keep elbows strong and ribs tucked instead of jumping the legs upward.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Press Through", "Press the floor away while the hips rise over the shoulders. The movement should feel like unfolding into handstand, not kicking past the balance point.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Handstand Finish", "Arrive in a tall handstand with elbows locked, shoulders elevated, and a controlled exit. If the finish arches hard, regress the entry or use wall assistance.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func planchePushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isTuck = skillId == "cal.tuck-planche-pushup"
        return [
            phase("phase1", "Lean Set", isTuck ? "Enter a stable tuck planche with feet off the floor, shoulders protracted, and elbows locked. Do not begin the push-up from a collapsing tuck." : "Set hands low near the hips or lower ribs, then lean shoulders clearly forward past the wrists. Mark the lean so it is repeatable.", "ruler.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Protract", "Push the floor away and spread the shoulder blades. Protraction and hollow shape keep the planche line alive.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Bend Without Losing Lean", isTuck ? "Bend the elbows while feet stay off the floor and knees remain tucked tight. If the feet touch, regress." : "Lower through the push-up while shoulders remain forward. If the body drifts back over the hands, the rep lost its planche load.", "arrow.down", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press To Same Shape", "Press back to the exact setup position: same lean, same protraction, same hollow line. Do not finish by shifting backward into a normal push-up.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func crowFamilyPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "hs.crane-pose":
            return [
                phase("phase1", "Crow Base", "Begin from a stable crow with knees high on the upper arms. The feet should float because the hands control pressure, not because you hopped into balance.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Press Tall", "Press the floor away and let the hips climb. Keep the knees glued high on the triceps while the elbows begin to straighten.", "arrow.up.circle.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Lock Arms", "Reach toward straight elbows without dumping weight into the wrists. Fingers stay active and the upper back stays rounded.", "lock.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold Crane", "Hold with straight arms, knees still high, and a calm gaze slightly forward. If elbows rebend or knees slide, return to crow work.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "hs.flying-crow":
            return [
                phase("phase1", "Base", "Start from a quiet crow or crane. One knee stays high on the arm before the back leg starts to leave the compact shape.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Shift", "Shift weight forward and into the support-side hand. Move slowly enough that the fingers can correct balance before the long leg pulls you over.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Extend", "Reach the free leg straight back with the toe pointed. Keep the support knee connected to the triceps instead of letting the pose turn into a kick.", "arrow.right", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold with one knee anchored, one leg long, hips as level as the shape allows, and shoulders still pushing the floor away.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Setup", "Plant hands shoulder-width with fingers spread, then set knees high on the upper arms. The elbows bend to make a shelf.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Shelf", "Lean shoulders forward and squeeze knees into the arms. Keep the hips high so the feet can get light.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Float", "Lift one foot, then the other, without jumping. Use fingertip pressure to stop tipping forward.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold with bent elbows, knees high, rounded upper back, and steady breathing. Step down before the wrists collapse.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    private static func elbowLeverPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        if skillId == "hs.one-arm-elbow-lever" {
            return [
                phase("phase1", "Two Arm", "Enter a clean two-arm elbow lever first. Both elbows should be anchored before you try to remove support.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Shift", "Move weight toward the working elbow while keeping the torso square. The free hand becomes light before it leaves.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Release", "Reach the free arm off the floor as a counterbalance. Do not let that side twist open or drop.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold one-arm support with the working elbow locked into the hip crease, legs straight, and body horizontal.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
        return [
            phase("phase1", "Plant", "Set hands shoulder-width with fingers spread. Bend elbows inward toward the lower abdomen or hip crease before leaning.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Anchor", "Wedge both elbows into the body and lean forward gradually. The shelf should support the torso before the feet lift.", "scope", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Float", "Let the feet float as the balance point moves forward. Extend the legs only as far as the elbow shelf stays fixed.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Hold", "Hold a horizontal body line with glutes tight, legs together, and wrists active. Step out before the elbows slide.", "timer", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func plancheHoldPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "pl.tuck-planche":
            return [
                phase("phase1", "Support", "Grip floor or parallettes, lock elbows, depress shoulders, and push hard into protraction. The shoulders must be active before the feet float.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Lean", "Lean shoulders forward of the hands. If shoulders stay stacked over wrists, the hold cannot balance without another cheat.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Tuck", "Pull knees tight to the chest, heels close to glutes, and lift hips toward shoulder height. Knees do not rest on the arms.", "figure.core.training", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold with straight elbows, rounded upper back, and quiet head position. Stop when hips drop or elbows soften.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "pl.straddle-planche":
            return [
                phase("phase1", "Tuck Base", "Begin from a tuck or advanced tuck planche you can control with the same protracted shoulder position.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Open", "Extend the legs wide into straddle, not straight back. A wider split is the bridge; narrow it only after control appears.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Line", "Lock knees, point toes, posteriorly tilt the pelvis, and keep hips level with shoulders instead of letting the legs droop.", "line.diagonal", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Exit", "Step down or tuck back in before the scapula collapses. Clean short holds beat long banana-back holds.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "pl.half-lay-planche":
            return [
                phase("phase1", "Straddle Set", "Start from a clean straddle planche with shoulders forward, elbows locked, and hips already level.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Narrow", "Close the legs partway toward parallel in small increments. The torso and shoulder shape should not change.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Brace", "Squeeze glutes, quads, and toes while keeping ribs down. Narrower legs make every small leak louder.", "figure.core.training", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Proof Hold", "Use short two-to-five-second holds. If hips drop, widen the straddle or use band assistance.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "pl.full-planche":
            return [
                phase("phase1", "Shoulder Lean", "Hands press down, shoulders travel forward of the hands, elbows stay locked, and scapulae stay protracted and depressed.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Hollow Line", "Ribs down, pelvis tucked, glutes squeezed, quads locked, legs together, toes pointed. Hollow beats banana.", "circle.hexagongrid.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Float", "Lift into the hold without bending the elbows. Use band or box assistance if the full line appears only for a split second.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Standard", "Hold the body roughly parallel to the floor with hands as the only contact. End the set as soon as elbows soften or hips drop.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Lean", "Shift shoulders forward and protract before the legs float. This is still a planche-family shape, not a normal push-up pause.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Bend", "Use a strong bent-arm angle while keeping the body horizontal. Do not wedge elbows into the hips like an elbow lever.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Hold", "Chest stays forward, legs extended, and hips level. Step down before the line turns into a sag.", "timer", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Separate", "Treat this as pressing accessory work. Straight-arm planche progress still needs locked-elbow leans and holds.", "arrow.triangle.branch", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    private static func unilateralPushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isOneArm = skillId == "cal.one-arm-pushup"
        return [
            phase("phase1", "Base", isOneArm ? "Set one hand under the shoulder or slightly inside and widen the feet enough to balance. The free hand stays off the floor." : "Set hands wide and brace before shifting. Use a moderate width first; very wide hands can irritate shoulders.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shift Load", isOneArm ? "Shift weight over the working hand and resist twisting. The torso should stay mostly square instead of spinning open." : "Move the chest toward the working hand while the opposite arm stays long and light. The straight arm guides more than it presses.", "arrow.up.left", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Full Depth", "Lower to honest depth with control. If range shrinks or hips rotate hard, raise the working hand and rebuild the full path.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lockout", "Press back to lockout without dumping the shoulder forward. Train the weaker side first and match clean reps.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func explosivePushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isClap = skillId == "cal.clapping-pushup"
        let isTriple = skillId == "cal.triple-clap-pushup"
        return [
            phase("phase1", "Strict Load", "Start as a strict push-up and lower with control. Power comes from a strong plank line, not a hip buck.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Explode", "Punch the floor away hard enough that both hands leave the ground. Stop the set when height drops.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", isTriple ? "Triple Clap" : (isClap ? "Clap" : "Airtime"), isTriple ? "Fit three quick claps only if the launch is massive and controlled. This is an elite power skill, not conditioning." : (isClap ? "Clap once at chest level and return the hands before the landing. A low hip-level clap means airtime is not ready yet." : "Show clear airtime without changing the body line. The hands leave because the press is fast, not because the hips snap."), "hands.clap.fill", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Soft Catch", "Land with elbows slightly bent and shoulders active, then regain the plank before the next rep. Never catch stiff-armed.", "arrow.down.forward.circle.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func ringMuscleUpPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "False Grip", "Set the wrist high over each ring before the pull. The false grip keeps the hand ready for transition instead of forcing a desperate regrip.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Pull Close", "Pull the rings down the body toward lower chest. Keep rings close; if they drift away, the transition becomes a shoulder fight.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Transition", "Roll the chest over the rings with elbows close and moving back. Use feet or bands until the turnover is smooth rather than a grind.", "arrow.triangle.branch", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Support", "Land in the bottom of a ring dip, then press to stable support with rings controlled near the body.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func strictMuscleUpPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Strict Hang", "Start from a dead or active hang with no swing, hip pop, or leg kick. False grip can help, but the body must stay quiet.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "High Pull", "Pull higher than a normal pull-up, aiming toward lower chest or upper stomach. Chin height is usually too low for a strict turnover.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Turnover", "Keep elbows close and lean the chest over the hands before momentum dies. The transition should be continuous, not pull-up, pause, panic.", "arrow.triangle.branch", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Out", "Press to full support under control. If swing created the transition, log it as regular muscle-up work instead.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    private static func conditioningPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "co.bw-farmer-carry":
            return [
                phase("phase1", "Grip Base", "Set the implements evenly, hinge to grip, and brace before standing. Handles should start quiet.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "BW Load", "Carry total load equal to bodyweight while standing tall with shoulders level.", "scalemass.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Unbroken Walk", "Use short controlled steps and finish the course without drops or thigh rests.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Calm Carry", "Keep breathing and set the load down under control. The finish is not a crash.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.1.5x-farmer-carry":
            return [
                phase("phase1", "Heavy Setup", "Brace before the pick and keep wrists neutral. Do not rush the first stand.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Load Bridge", "Build from bodyweight toward 1.5x total load with the same tall posture.", "scalemass.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "1.5x Standard", "Walk the prescribed course with shoulders level and handles quiet.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Fatigue Proof", "Finish before posture leaks. Set down safely instead of dropping from grip panic.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.2x-farmer-carry":
            return [
                phase("phase1", "Max Brace", "Treat the pickup like a heavy deadlift: wedge, brace, stand, then walk.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Heavy Holds", "Own the load standing still before asking it to move.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "2x Walk", "Use small steps and keep the trunk rigid as the load tries to pull posture apart.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Controlled Finish", "Hinge down and place the implements safely with posture intact.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.dead-hang-45":
            return [
                phase("phase1", "Find Bar", "Set a shoulder-width grip, wrap the thumbs if possible, and settle the body before timing.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Stack Time", "Build toward 45 seconds with clean clusters before testing unbroken.", "timer", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Unbroken 45", "Hang for the full time without foot taps, elbow bend, or shoulder pain.", "figure.hanging", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Quiet Hang", "Keep the body still and step down under control when finished.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.dead-hang-60":
            return [
                phase("phase1", "45 Base", "Own the shorter hang first. The final 15 seconds should not change the shape.", "timer", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Grip Reserve", "Use repeated holds to build enough grip that the minute does not become a panic fight.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Unbroken 60", "Hold the full minute with long arms, quiet ribs, and no kicking.", "figure.hanging", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Durable Hang", "Repeat the standard without elbow or shoulder irritation.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.sled-push":
            return [
                phase("phase1", "Lean Line", "Set hands, brace the trunk, and create a strong forward body angle before driving.", "line.diagonal", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Move Sled", "Use short powerful steps to get the sled rolling without bouncing upright.", "arrow.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Sustain Force", "Hold cadence and push the floor behind you as fatigue builds.", "bolt.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Finish Strong", "Stay low through the final steps. Do not let the back round or the arms take over.", "flag.checkered", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.400m-row":
            return [
                phase("phase1", "Set Erg", "Strap feet, choose a familiar damper or drag, and set the monitor to 400m.", "slider.horizontal.3", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Find Length", "Use full strokes: legs drive, body swings, arms finish; recovery reverses that order.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Sprint Control", "Row fast without shortening into half-strokes or yanking early with the arms.", "speedometer", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Last 100", "Lift the rate near the finish while keeping the handle path clean.", "flag.checkered", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.mile-sub-7":
            return [
                phase("phase1", "Pace Lock", "Learn the target: faster than 1:45 per 400m or 6:59 for the mile.", "timer", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Lap Two", "Open controlled and keep the second lap steady instead of paying for a reckless start.", "speedometer", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Middle Hold", "Press the third lap with tall posture, relaxed shoulders, and quick feet under hips.", "figure.run", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Sub-7 Close", "Commit before the final straight and finish 6:59 or faster.", "flag.checkered", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "co.5k-sub-22":
            return [
                phase("phase1", "Goal Pace", "Feel the target pace: slightly faster than 4:24 per km or 7:05 per mile.", "timer", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Controlled Start", "The first 2 km should feel strong, not desperate. Avoid the adrenaline spike.", "speedometer", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Midrace Hold", "Stay locked through kilometers 3 and 4 with relaxed shoulders and quick cadence.", "figure.run", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Sub-22 Close", "Commit before the final kilometer and finish under 22:00.", "flag.checkered", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Bike Fit", "Set seat height so the knee has a soft bend at the bottom. Start tall, not cramped.", "slider.horizontal.3", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Smooth RPM", "Sync arms and legs so the handles push and pull with the pedals.", "arrow.left.arrow.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "30-Cal Hold", "Settle into a hard sustainable rhythm after the opening acceleration.", "speedometer", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Final Push", "Drive through the final calories and do not coast before the monitor stops.", "flag.checkered", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    private static func legPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "ld.goblet-20":
            return [
                phase("phase1", "Stance", "Set feet around shoulder width, hold the weight tight to the chest, and root heel, big toe, and little toe before descending.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Half Depth", "Sit between the hips to the deepest clean target for this node. Knees track with toes and ribs stay stacked over the pelvis.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Drive Up", "Stand by pushing the floor away through the whole foot. Hips and chest rise together without the knees caving in.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Reset", "Finish tall, breathe, and reset foot pressure before the next rep. Do not bounce through sloppy volume.", "arrow.counterclockwise", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.step-up":
            return [
                phase("phase1", "Plant", "Face a stable box and place the whole lead foot on top. Do not start from the toes or a half-foot plant.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Drive", "Push mostly through the lead midfoot and heel while the trailing leg stays quiet. Knee tracks over the second toe.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Stand Tall", "Finish with hip and knee fully extended on top before stepping down. The rep is not complete while folded forward.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control Down", "Step down slowly and quietly. If you drop off the box or wobble hard, lower the height or reps.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.deep-squat":
            return [
                phase("phase1", "Stance", "Set feet around shoulder width with a small toe turn-out. Keep heel, big toe, and little toe rooted.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Sink", "Sit between the hips until hips pass below knees without heels lifting. Use a counterweight if balance blocks the range.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Open", "Keep chest open, knees tracking with toes, and breathe slowly in the bottom. This is active mobility, not a collapsed rest.", "wind", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Own Time", "Hold only while the position stays pain-free and foot-flat. Stand and reset before shape degrades.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.glute-bridge", "ld.single-leg-glute-bridge":
            let single = skillId == "ld.single-leg-glute-bridge"
            return [
                phase("phase1", "Set Ribs", "Lie back with ribs down and heel under knee. \(single ? "Extend the free leg and keep both hips level." : "Plant both feet evenly.")", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Drive Heels", "Push through the heel, not the toes, and lift by squeezing glutes instead of arching the low back.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Lock Hips", "Pause at full hip extension with glutes on and ribs still tucked. The top should not become a backbend.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Lower Quietly", "Lower with control and keep the pelvis level. If hamstrings cramp or hips twist, shorten the range.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.split-squat", "ld.weighted-split-squat", "ld.bulgarian-split-squat", "ld.weighted-bss":
            let rearElevated = skillId.contains("bulgarian") || skillId.contains("bss")
            return [
                phase("phase1", "Rails", "Set feet hip-width like train tracks. \(rearElevated ? "Rear foot rests on the bench as a balance point, not the engine." : "Back foot stays planted behind you.")", "lines.measurement.horizontal", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Descend", "Lower under control with front knee tracking over toes and torso organized. Match depth on both sides.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Front-Leg Drive", "Drive through the front foot to stand. The rear leg should not spring the rep into place.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Symmetry", "Let the weaker side set load and reps. If weight shortens range, reduce it before progressing.", "equal.circle.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.shrimp-squat", "ld.pistol-squat", "ld.weighted-pistol":
            let shrimp = skillId == "ld.shrimp-squat"
            return [
                phase("phase1", "Balance Set", shrimp ? "Grab the rear ankle, free arm forward, and root the working foot." : "Reach arms forward, lift the free leg, and root the working heel before descending.", "scope", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Slow Lower", "Use a controlled eccentric. Knee follows toes; heel stays planted; hips stay square instead of twisting out.", "metronome", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", shrimp ? "Soft Knee Touch" : "Bottom Control", shrimp ? "Let the rear knee lightly touch the pad or floor. Do not crash into it or push from it." : "Reach the lowest controlled position with the free foot still off the floor. Pause instead of bouncing.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Stand Clean", "Drive up without hand assist, free-foot touch, or heel lift. Use a box or counterweight if the full rep breaks.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.calf-raise", "ld.weighted-sl-calf":
            return [
                phase("phase1", "Stretch", "Start from a controlled bottom with ankle straight and pressure through the big toe mound. Use wall balance if needed.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Rise High", "Lift as high as the ankle allows without rolling outward or bending the knee to cheat.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Pause", "Hold the top briefly. This pause makes the rep full-range instead of a bounce.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Slow Lower", "Lower for control back into the stretch. Add load only after range stays identical.", "metronome", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.jumping-squat", "ld.box-jump":
            let box = skillId == "ld.box-jump"
            return [
                phase("phase1", "Load", box ? "Set a stable box and dip into an athletic quarter squat." : "Descend to a controlled squat depth with feet rooted.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Triple Extend", "Extend hips, knees, and ankles together. Arms can swing, but knees still track toes.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", box ? "Soft Box Landing" : "Soft Landing", box ? "Land with the whole foot on the box, knees soft, and chest organized. Stand tall after landing." : "Land quietly with knees soft and aligned, then absorb into the next rep.", "arrow.down.forward.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", box ? "Step Down" : "Stop On Fade", box ? "Step down instead of jumping down. Protect the ankle and keep the next rep crisp." : "End the set when height or landing quality drops. Power reps are not burnout reps.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.leg-extensions":
            return [
                phase("phase1", "Knee Set", "Kneel with ankles anchored or toes planted, hips open, ribs down, and glutes lightly on before the first lean.", "scope", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Lean Back", "Let the knees bend as the body leans backward in one line from knees to shoulders. Do not sit the hips back.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Quad Tension", "Pause only as deep as the quads can control without sharp knee pain or lumbar arching.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Extend", "Drive through the quads to return tall. Keep hips open instead of turning the rep into a hip hinge.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.sissy-squat":
            return [
                phase("phase1", "Tall Line", "Stand tall with hips open, ribs down, and light support available if needed. This is a quad isolation pattern, not a normal squat.", "line.diagonal", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Knees Forward", "Let knees travel forward while the torso leans back and heels rise as needed. Keep hips extended.", "arrow.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Deep Lean", "Reach the deepest controlled quad-loaded arc without dropping into pain or folding at the hips.", "scope", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Drive Tall", "Use the quads to return to a tall line. Reduce range if the hips hinge to escape the load.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.fire-hydrant":
            return [
                phase("phase1", "Quadruped Set", "Set hands under shoulders, knees under hips, ribs down, and pelvis square before lifting the leg.", "square.grid.2x2", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Lift Side", "Lift the bent knee out to the side from the hip. The spine and pelvis should stay quiet.", "arrow.up.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Square Hips", "Pause where the glute owns the position. Do not roll the whole body open for extra height.", "scope", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control Down", "Lower slowly to the same quadruped set. Match both sides and stop when the trunk starts twisting.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.flying-kickback":
            return [
                phase("phase1", "Quadruped Set", "Set ribs down and hips square on hands and knees. The working leg starts from control, not a swing.", "square.grid.2x2", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Drive Back", "Drive the leg straight back from the glute while the low back stays quiet.", "arrow.backward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Glute Squeeze", "Pause with the leg long and hips level. Do not arch the lumbar spine to fake height.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control Return", "Return under control to the start. The next rep begins only after the pelvis is square again.", "arrow.counterclockwise", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.nordic-hip-hinge", "ld.advancing-nordic-curl", "ld.nordic-curl":
            if skillId == "ld.nordic-hip-hinge" {
                return [
                    phase("phase1", "Anchor", "Secure ankles under a stable anchor. If the feet shift, the rep is over before it starts.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                    phase("phase2", "Brace Line", "Set ribs, glutes, and trunk before hinging. The hinge is deliberate, not a collapse.", "line.diagonal", assetName: assetName(assetPrefix, "phase2")),
                    phase("phase3", "Hip Hinge", "Move the hips back while the hamstrings load. Keep the spine organized and avoid rounding to escape tension.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase3")),
                    phase("phase4", "Return", "Pull back to tall kneeling with control. Shorten the range if the anchor shifts or the back rounds.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
                ]
            }
            return [
                phase("phase1", "Anchor", "Secure ankles under a stable anchor. If the feet shift, the rep is over before it starts.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace Line", "Set ribs, glutes, and trunk. Keep a straight knee-to-head line unless you are deliberately using the hip-hinge regression.", "line.diagonal", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Slow Eccentric", "Lower under hamstring control. Use a band, shorter range, or hand catch before the last inches become a fall.", "metronome", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Return Or Catch", "Pull back up only if the line stays honest. Otherwise catch with hands, reset, and keep volume low.", "exclamationmark.triangle.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.floor-to-ceiling-squat":
            return [
                phase("phase1", "Floor Set", "Start low with feet rooted and hands near the floor or target. Set knees over toes before standing.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Stand Up", "Rise from the squat without knee cave or heel lift. Finish tall before loading the jump.", "figure.stand", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Explode", "Jump vertically with full hip, knee, and ankle extension. Reach for the ceiling or measured target.", "bolt.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Touch", "Touch the target and land softly with knees aligned. The rep is not clean if the landing falls apart.", "hand.point.up.left.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Set", "Start with the working joints stacked and the foot or knee position stable. Do not rush the first rep.", "scope", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Control", "Move through the intended range slowly enough that knee, hip, and trunk alignment stay visible.", "metronome", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Target", "Reach the skill's target position without bouncing, twisting, or using hidden assistance.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Reset", "Return under control and match the weaker side. Stop when form changes.", "arrow.counterclockwise", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    private static func phase(_ id: String, _ title: String, _ instruction: String, _ symbol: String, assetName: String? = nil) -> FormPhase {
        FormPhase(
            id: id,
            title: title,
            cues: [],
            instruction: instruction,
            assetName: assetName,
            fallbackSymbol: symbol
        )
    }

    private static func assetName(_ prefix: String?, _ phase: String) -> String? {
        guard let prefix else { return nil }
        return "\(prefix)_\(phase)"
    }
}
