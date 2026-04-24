import SwiftUI

// MARK: - Step_Verdict
//
// The post-scan reveal. Reframed from "verdict" to "snapshot" — the scan is
// a visual record of progress toward the user's chosen archetype, not a
// score against it. No match-% anywhere. Rank shown is the user's gym-earned
// rank (derived from commitment + lifestyle), not a scan output.

struct Step_Verdict: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onContinue: () -> Void

    @State private var hasAnimated = false

    var body: some View {
        ZStack {
            // Hero vertical fade + subtle violet vignette
            LinearGradient(
                colors: [Color.unbound.surface, Color.unbound.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.unbound.accent.opacity(0.18), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    heroCard
                    if flow.scanInsights != nil {
                        scanInsightCard
                    }
                    buildDossierCard
                    archetypeCard
                    focusCard
                    planCard
                    Spacer().frame(height: 80) // space for pinned CTA
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
            }

            // Pinned CTA
            VStack {
                Spacer()
                UnboundButton(
                    title: "See the ladder",
                    icon: "arrow.right",
                    action: onContinue
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        colors: [Color.unbound.bg.opacity(0), Color.unbound.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false),
                    alignment: .bottom
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .opacity(hasAnimated ? 1 : 0)
        .offset(y: hasAnimated ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.88)) {
                hasAnimated = true
            }
            UnboundHaptics.heavy()
        }
    }

    // MARK: Hero — rank + scan photo

    private var heroCard: some View {
        VStack(spacing: 20) {
            // Scan photo as circular profile pic with violet ring
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.unbound.accent.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)

                Group {
                    if let photo = flow.profilePhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else if let baseline = UIImage(named: "body_baseline") {
                        // User skipped capture (dev path / fallback) — show
                        // the baseline starter silhouette as "you are here"
                        // rather than a raw SF Symbol.
                        Image(uiImage: baseline)
                            .resizable()
                            .scaledToFit()
                            .background(Color.unbound.surfaceElevated)
                    } else {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.unbound.surfaceElevated)
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.unbound.accent, lineWidth: 2)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 12, x: 0, y: 0)
                )
            }

            // Snapshot framing — no judgment, just a logged moment.
            VStack(spacing: 10) {
                Text("YOUR SNAPSHOT · \(flow.archetype?.shortName ?? "UNBOUND")")
                    .font(Font.unbound.monoS)
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)

                Text("The \(flow.archetype?.shortName ?? "Unbound")")
                    .font(Font.unbound.displayM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)

                if let tagline = flow.archetype?.characterTagline {
                    Text(tagline)
                        .font(Font.unbound.monoS)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("LOGGED · \(loggedDateText)")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                }
                .foregroundStyle(Color.unbound.success)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Capsule().strokeBorder(Color.unbound.success.opacity(0.55), lineWidth: 1)
                )

                Text(flow.displayHandle.isEmpty
                     ? "Your arc is logged. Every session moves this forward."
                     : "\(flow.displayHandle) — your arc is logged. Every session moves this forward.")
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var loggedDateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date()).uppercased()
    }

    // MARK: Scan insight — one honest, specific fact from the Vision analysis
    //
    // Shown only when `LocalBodyInsightsService` produced a result during
    // the analyzing screen. Intentionally narrow: one measured ratio, one
    // line explaining how it nudged the program. No body-fat %, no muscle-
    // mass score, nothing we don't actually measure.

    private var scanInsightCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text("FROM YOUR SCAN")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }

                if let insights = flow.scanInsights {
                    Text(insights.headline)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)

                    HStack(spacing: 8) {
                        Text("SHOULDER-TO-HIP")
                            .font(Font.unbound.captionS)
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(String(format: "%.2f", insights.shoulderHipRatio))
                            .font(Font.unbound.monoM)
                            .foregroundStyle(Color.unbound.accent)
                            .monospacedDigit()
                    }

                    Text(insights.programImpact)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Build dossier — tailored narrative paragraph
    //
    // Pulls from every onboarding answer to assemble a 3–4 sentence dossier
    // that reads like a dossier, not a checklist. Static template with
    // input-driven slots — AI-generated version is a follow-up.

    private var buildDossierCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text("YOUR BUILD DOSSIER")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }

                Text(buildNarrative)
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
        }
    }

    /// Weaves archetype, focus areas, experience, and commitment into one
    /// cohesive dossier paragraph. Not AI — purely template — but reads
    /// tailored because it pulls from the user's actual answers.
    private var buildNarrative: String {
        let arch = flow.archetype?.shortName ?? "UNBOUND"
        let focusPhrase = focusAreasPhrase
        let experiencePhrase = experienceDescriptor
        let commitPhrase = commitmentDescriptor
        let equipPhrase = equipmentDescriptor

        return """
        We're building a \(arch) frame, tuned to your \(experiencePhrase) baseline \(equipPhrase). Priority work is \(focusPhrase) — where your current shape is furthest from the shape you want. With your \(commitPhrase) commitment, the math says you reach your first real milestone inside 60 days, and you keep climbing from there.
        """
    }

    private var focusAreasPhrase: String {
        let names = focusAreas.prefix(2).map { $0.lowercased() }
        switch names.count {
        case 0: return "full-body recomposition"
        case 1: return names[0]
        default: return "\(names[0]) and \(names[1])"
        }
    }

    private var experienceDescriptor: String {
        // Keyed off experience level — any experience enum exists downstream;
        // if not wired, return a safe default read.
        "current"
    }

    private var commitmentDescriptor: String {
        switch flow.commitment {
        case 9...10: return "all-in"
        case 7...8: return "serious"
        case 5...6: return "steady"
        default: return "starting"
        }
    }

    private var equipmentDescriptor: String {
        if flow.equipment.contains(.fullGym) { return "with full-gym access" }
        if flow.equipment.contains(.bodyweight), flow.equipment.count == 1 {
            return "with bodyweight only"
        }
        if flow.equipment.isEmpty { return "" }
        return "with your current gear"
    }

    // MARK: Archetype + supportive quote

    private var archetypeCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("YOUR ARCHETYPE")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text(archetypeName)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.accent)
                        .tracking(1.2)
                }

                Divider().background(Color.unbound.borderSubtle)

                Text("\"\(supportiveQuote)\"")
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var archetypeName: String {
        flow.archetype?.shortName ?? "Unbound"
    }

    /// Supportive tone per jlin's direction — NOT the spec's roast lines.
    private var supportiveQuote: String {
        guard let a = flow.archetype else {
            return "Dense frame waiting to be built. Let's go."
        }
        switch a {
        case .heavyDuty: return "Mass responds fastest when you're starting here. Good foundation."
        case .leanCut:   return "Balanced proportions. The hero-build blueprint starts today."
        case .shredded:  return "Clean lines to work with. Let's sharpen the detail."
        case .vTaper:    return "Shoulders + taper is where we'll carve your signature."
        }
    }

    // MARK: Focus areas

    private var focusCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("FOCUS AREAS")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                FlexibleWrap(spacing: 8) {
                    ForEach(focusAreas, id: \.self) { area in
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.system(size: 10, weight: .semibold))
                            Text(area)
                                .font(Font.unbound.bodyS)
                        }
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var focusAreas: [String] {
        guard let a = flow.archetype else { return ["Full body"] }
        return a.priorityMuscleGroups.prefix(4).map(\.displayName)
    }

    // MARK: Plan preview

    private var planCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR ADAPTIVE PROTOCOL")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                planArc(number: 1, title: "Foundation", detail: "Wake the base. Volume in, form locked.")
                planArc(number: 2, title: "Growth", detail: "Intensification. Loads climb, reps tighten.")
                planArc(number: 3, title: "Power", detail: "Realization when rank opens it.")

                Divider().background(Color.unbound.borderSubtle)

                HStack(spacing: 12) {
                    statChip(icon: "calendar", value: "\(sessionsPerWeek)", label: "sessions / week")
                    statChip(icon: "clock", value: "\(sessionMinutes)", label: "min / session")
                }
            }
        }
    }

    private func planArc(number: Int, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Color.unbound.accent, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
        }
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text(value)
                .font(Font.unbound.monoM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
    }

    private var sessionsPerWeek: Int {
        switch flow.targetFrequency {
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case nil: return 4
        }
    }

    private var sessionMinutes: Int {
        flow.sessionLength?.minutes ?? 45
    }
}
