import SwiftUI

// MARK: - Step_Verdict
//
// Post-scan reveal — scored breakdown in the style of a body analysis.
// 4 graded attributes (Frame / Proportion / Drive / Potential) shown as
// letter-grade cards with filled bars, followed by archetype identity,
// focus areas, and protocol preview.

struct Step_Verdict: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onContinue: () -> Void

    @State private var hasAnimated = false
    @State private var barsRevealed = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            RadialGradient(
                colors: [Color.unbound.accent.opacity(0.14), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 480
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    headerLabel
                    heroCard
                    scoreGrid
                    dossierCard
                    archetypeCard
                    focusCard
                    planCard
                    Spacer().frame(height: 100)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 24)
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
        .offset(y: hasAnimated ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                hasAnimated = true
            }
            UnboundHaptics.heavy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.7)) { barsRevealed = true }
            }
        }
    }

    // MARK: - Header

    private var headerLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.success)
            Text("ANALYSIS COMPLETE · \(loggedDateText)")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var loggedDateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date()).uppercased()
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(spacing: 16) {
            // Photo
            Group {
                if let photo = flow.profilePhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.unbound.surfaceElevated)
                }
            }
            .frame(width: 88, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: Color.unbound.accent.opacity(0.3), radius: 12)

            VStack(alignment: .leading, spacing: 6) {
                Text(flow.archetype?.shortName.uppercased() ?? "UNBOUND")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(Color.unbound.accent)

                Text("The \(flow.archetype?.shortName ?? "Unbound")")
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)

                if let tagline = flow.archetype?.characterTagline {
                    Text(tagline)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Overall grade pill
                HStack(spacing: 5) {
                    Text("OVERALL")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(overallGrade.letter)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(overallGrade.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(overallGrade.color.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(overallGrade.color.opacity(0.35), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            ChamferedRectangle(inset: 10)
                .fill(Color.unbound.surface)
        )
        .overlay(
            ChamferedRectangle(inset: 10)
                .stroke(Color.unbound.border, lineWidth: 1)
        )
    }

    // MARK: - Score grid

    private var scoreGrid: some View {
        VStack(spacing: 10) {
            HStack {
                Text("BODY BREAKDOWN")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                if flow.bodyRatings != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                        Text("AI SCORED")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                    }
                    .foregroundStyle(Color.unbound.accent)
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(gridItems, id: \.0) { label, metric in
                    gradeCell(label: label, metric: metric)
                }
            }

            if let coachLine = flow.bodyRatings?.coachLine, !coachLine.isEmpty {
                Text("\u{201C}\(coachLine)\u{201D}")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.ember)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // Always returns body-part labels regardless of data source.
    // Priority: Gemini bodyRatings → Vision geometry estimates → neutral placeholders.
    private var gridItems: [(String, ScoreMetric)] {
        if let r = flow.bodyRatings {
            return [
                ("SHOULDERS", metricFrom(score: r.shoulders)),
                ("CHEST",     metricFrom(score: r.chest)),
                ("ARMS",      metricFrom(score: r.arms)),
                ("CORE",      metricFrom(score: r.core)),
                ("LEGS",      metricFrom(score: r.legs)),
                ("OVERALL",   metricFrom(score: r.overall))
            ]
        }
        // Vision fallback — map geometry to body-part names as best as possible.
        // Shoulders/legs have real Vision backing; chest/arms/core are neutral (Vision
        // can't assess muscle development).
        return [
            ("SHOULDERS", frameScore),
            ("CHEST",     proportionScore),
            ("ARMS",      neutralMetric),
            ("CORE",      neutralMetric),
            ("LEGS",      torsoLegScore),
            ("OVERALL",   potentialScore)
        ]
    }

    // Neutral placeholder — used when Vision has no signal for a body part.
    private var neutralMetric: ScoreMetric {
        ScoreMetric(grade: Grade(letter: "C", color: Color(hex: "#FF9F0A"), fillFraction: 0.40), fillFraction: 0.40, valueLabel: "—")
    }

    private func gradeCell(label: String, metric: ScoreMetric) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            Text("\(metric.displayScore)")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 14)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.unbound.borderSubtle)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(metric.grade.color)
                        .frame(
                            width: barsRevealed ? proxy.size.width * metric.fillFraction : 0,
                            height: 3
                        )
                        .shadow(color: metric.grade.color.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(metric.grade.color.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Dossier

    private var dossierCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text("YOUR BUILD DOSSIER")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
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

    // MARK: - Archetype

    private var archetypeCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("YOUR ARCHETYPE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text(flow.archetype?.shortName.uppercased() ?? "UNBOUND")
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

    // MARK: - Focus areas

    private var focusCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("FOCUS AREAS")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
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
                        .overlay(Capsule().strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Plan preview

    private var planCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR ADAPTIVE PROTOCOL")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)

                planArc(number: 1, title: "Foundation", detail: "Wake the base. Volume in, form locked.")
                planArc(number: 2, title: "Growth",     detail: "Intensification. Loads climb, reps tighten.")
                planArc(number: 3, title: "Power",      detail: "Realization when rank opens it.")

                Divider().background(Color.unbound.borderSubtle)

                HStack(spacing: 12) {
                    statChip(icon: "calendar", value: "\(sessionsPerWeek)", label: "sessions / week")
                    statChip(icon: "clock",    value: "\(sessionMinutes)", label: "min / session")
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
                    .font(.system(size: 11, weight: .black, design: .monospaced))
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

    // MARK: - Score computation

    struct Grade {
        let letter: String
        let color: Color
        let fillFraction: Double
    }

    struct ScoreMetric {
        let grade: Grade
        let fillFraction: Double
        let valueLabel: String
        // Derived from fillFraction so no callsite changes needed.
        // metricFrom(score:) → fill = score/10 → displayScore = score*10 (1-100 scale).
        // Vision fallbacks derive naturally from their fill fractions.
        var displayScore: Int { max(10, Int(fillFraction * 100)) }
    }

    // Convert a 1-10 Gemini score to a display metric
    private func metricFrom(score: Int) -> ScoreMetric {
        let fill = Double(score) / 10.0
        switch score {
        case 9...10: return ScoreMetric(grade: Grade(letter: "S", color: Color.unbound.accent, fillFraction: fill), fillFraction: fill, valueLabel: "\(score)/10")
        case 7...8:  return ScoreMetric(grade: Grade(letter: "A", color: Color(hex: "#34C759"),  fillFraction: fill), fillFraction: fill, valueLabel: "\(score)/10")
        case 5...6:  return ScoreMetric(grade: Grade(letter: "B", color: Color(hex: "#5AC8FA"),  fillFraction: fill), fillFraction: fill, valueLabel: "\(score)/10")
        case 3...4:  return ScoreMetric(grade: Grade(letter: "C", color: Color(hex: "#FF9F0A"),  fillFraction: fill), fillFraction: fill, valueLabel: "\(score)/10")
        default:     return ScoreMetric(grade: Grade(letter: "D", color: Color(hex: "#FF453A"),  fillFraction: max(fill, 0.15)), fillFraction: max(fill, 0.15), valueLabel: "\(score)/10")
        }
    }

    // Vision fallback — shoulder-to-hip ratio → frame breadth
    private var frameScore: ScoreMetric {
        let ratio = flow.scanInsights?.shoulderHipRatio ?? defaultShoulderRatio
        switch ratio {
        case 1.55...: return ScoreMetric(grade: Grade(letter: "S", color: Color.unbound.accent, fillFraction: 0.97), fillFraction: 0.97, valueLabel: String(format: "%.2f", ratio))
        case 1.45...: return ScoreMetric(grade: Grade(letter: "A", color: Color(hex: "#34C759"), fillFraction: 0.82), fillFraction: 0.82, valueLabel: String(format: "%.2f", ratio))
        case 1.35...: return ScoreMetric(grade: Grade(letter: "B", color: Color(hex: "#5AC8FA"), fillFraction: 0.65), fillFraction: 0.65, valueLabel: String(format: "%.2f", ratio))
        case 1.20...: return ScoreMetric(grade: Grade(letter: "C", color: Color(hex: "#FF9F0A"), fillFraction: 0.48), fillFraction: 0.48, valueLabel: String(format: "%.2f", ratio))
        default:      return ScoreMetric(grade: Grade(letter: "D", color: Color(hex: "#FF453A"), fillFraction: 0.30), fillFraction: 0.30, valueLabel: String(format: "%.2f", ratio))
        }
    }

    // Vision fallback — proximity to archetype ideal ratio
    private var proportionScore: ScoreMetric {
        let ratio = flow.scanInsights?.shoulderHipRatio ?? defaultShoulderRatio
        let target: Double
        switch flow.archetype {
        case .vTaper:    target = 1.55
        case .leanCut:   target = 1.45
        case .shredded:  target = 1.50
        case .heavyDuty: target = 1.35
        case nil:        target = 1.45
        }
        let delta = abs(ratio - target)
        switch delta {
        case 0.0..<0.05: return ScoreMetric(grade: Grade(letter: "S", color: Color.unbound.accent, fillFraction: 0.96), fillFraction: 0.96, valueLabel: "IDEAL")
        case 0.05..<0.12: return ScoreMetric(grade: Grade(letter: "A", color: Color(hex: "#34C759"), fillFraction: 0.80), fillFraction: 0.80, valueLabel: "CLOSE")
        case 0.12..<0.22: return ScoreMetric(grade: Grade(letter: "B", color: Color(hex: "#5AC8FA"), fillFraction: 0.63), fillFraction: 0.63, valueLabel: "BUILDING")
        case 0.22..<0.35: return ScoreMetric(grade: Grade(letter: "C", color: Color(hex: "#FF9F0A"), fillFraction: 0.45), fillFraction: 0.45, valueLabel: "GAP")
        default:          return ScoreMetric(grade: Grade(letter: "D", color: Color(hex: "#FF453A"), fillFraction: 0.28), fillFraction: 0.28, valueLabel: "BIG GAP")
        }
    }

    // Vision fallback — torso-to-leg ratio (aesthetic balance)
    private var torsoLegScore: ScoreMetric {
        let ratio = flow.scanInsights?.torsoLegRatio ?? 0.7
        // Ideal torso:leg is ~0.55–0.65 (longer legs = athletic look)
        switch ratio {
        case 0.0..<0.55: return ScoreMetric(grade: Grade(letter: "S", color: Color.unbound.accent, fillFraction: 0.94), fillFraction: 0.94, valueLabel: "LONG LEGS")
        case 0.55..<0.65: return ScoreMetric(grade: Grade(letter: "A", color: Color(hex: "#34C759"), fillFraction: 0.80), fillFraction: 0.80, valueLabel: "BALANCED")
        case 0.65..<0.78: return ScoreMetric(grade: Grade(letter: "B", color: Color(hex: "#5AC8FA"), fillFraction: 0.64), fillFraction: 0.64, valueLabel: "EVEN")
        case 0.78..<0.90: return ScoreMetric(grade: Grade(letter: "C", color: Color(hex: "#FF9F0A"), fillFraction: 0.47), fillFraction: 0.47, valueLabel: "TORSO-HEAVY")
        default:          return ScoreMetric(grade: Grade(letter: "D", color: Color(hex: "#FF453A"), fillFraction: 0.30), fillFraction: 0.30, valueLabel: "SHORT LEGS")
        }
    }

    // Vision fallback — shoulder symmetry / posture
    private var symmetryScore: ScoreMetric {
        let isSymmetric = flow.scanInsights?.postureFlags.contains(.uprightStance) ?? true
        return isSymmetric
            ? ScoreMetric(grade: Grade(letter: "A", color: Color(hex: "#34C759"), fillFraction: 0.84), fillFraction: 0.84, valueLabel: "ALIGNED")
            : ScoreMetric(grade: Grade(letter: "C", color: Color(hex: "#FF9F0A"), fillFraction: 0.46), fillFraction: 0.46, valueLabel: "ASYMMETRY")
    }

    // Vision fallback — composite of the 4 vision metrics
    private var potentialScore: ScoreMetric {
        let avg = (frameScore.fillFraction + proportionScore.fillFraction + torsoLegScore.fillFraction + symmetryScore.fillFraction) / 4.0
        switch avg {
        case 0.85...: return ScoreMetric(grade: Grade(letter: "S", color: Color.unbound.accent, fillFraction: avg), fillFraction: avg, valueLabel: "ELITE")
        case 0.72...: return ScoreMetric(grade: Grade(letter: "A", color: Color(hex: "#34C759"), fillFraction: avg), fillFraction: avg, valueLabel: "HIGH")
        case 0.56...: return ScoreMetric(grade: Grade(letter: "B", color: Color(hex: "#5AC8FA"), fillFraction: avg), fillFraction: avg, valueLabel: "SOLID")
        case 0.40...: return ScoreMetric(grade: Grade(letter: "C", color: Color(hex: "#FF9F0A"), fillFraction: avg), fillFraction: avg, valueLabel: "BUILDING")
        default:      return ScoreMetric(grade: Grade(letter: "D", color: Color(hex: "#FF453A"), fillFraction: max(avg, 0.22)), fillFraction: max(avg, 0.22), valueLabel: "STARTER")
        }
    }

    private var overallGrade: Grade {
        if let r = flow.bodyRatings { return metricFrom(score: r.overall).grade }
        return potentialScore.grade
    }

    private var defaultShoulderRatio: Double {
        switch flow.archetype {
        case .vTaper:    return 1.42
        case .leanCut:   return 1.38
        case .shredded:  return 1.36
        case .heavyDuty: return 1.32
        case nil:        return 1.38
        }
    }

    // MARK: - Supporting copy

    private var buildNarrative: String {
        let arch = flow.archetype?.shortName ?? "Unbound"
        let commitPhrase = commitmentDescriptor
        let equipPhrase = equipmentDescriptor
        let focusPhrase = focusAreasPhrase

        return "Building a \(arch) frame, tuned to your current baseline \(equipPhrase). Priority work is \(focusPhrase) — where the gap is widest right now. With your \(commitPhrase) commitment, the first real milestone lands inside 60 days. The arc climbs from there."
    }

    private var focusAreasPhrase: String {
        let names = focusAreas.prefix(2).map { $0.lowercased() }
        switch names.count {
        case 0: return "full-body recomposition"
        case 1: return names[0]
        default: return "\(names[0]) and \(names[1])"
        }
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
        if flow.equipment.contains(.bodyweight), flow.equipment.count == 1 { return "with bodyweight only" }
        if flow.equipment.isEmpty { return "" }
        return "with your current gear"
    }

    private var supportiveQuote: String {
        guard let a = flow.archetype else { return "Dense frame waiting to be built. Let's go." }
        switch a {
        case .heavyDuty: return "Mass responds fastest when you're starting here. Good foundation."
        case .leanCut:   return "Balanced proportions. The hero-build blueprint starts today."
        case .shredded:  return "Clean lines to work with. Let's sharpen the detail."
        case .vTaper:    return "Shoulders + taper is where we'll carve your signature."
        }
    }

    private var focusAreas: [String] {
        guard let a = flow.archetype else { return ["Full body"] }
        return a.priorityMuscleGroups.prefix(4).map(\.displayName)
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

    private var sessionMinutes: Int { flow.sessionLength?.minutes ?? 45 }
}
