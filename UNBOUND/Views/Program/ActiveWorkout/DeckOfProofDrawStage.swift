import SwiftUI

struct DeckOfProofDrawStage: View {
    let exercise: ActiveWorkoutSession.ActiveExercise
    let drawIndex: Int
    let totalDraws: Int
    let isRevealed: Bool
    let isDrawing: Bool
    let onDraw: () -> Void
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: isRevealed ? 12 : 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DECK OF PROOF")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(isRevealed ? "\(cardFaceText) revealed" : "Draw \(drawNumber)")
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                }

                Spacer()

                Text("\(min(drawIndex + 1, totalDraws))/\(max(1, totalDraws))")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                    .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }

            Button(action: onDraw) {
                ZStack {
                    drawTableGlow
                    deckStack
                    flipCard
                }
                .frame(maxWidth: .infinity)
                .frame(height: isRevealed ? 318 : 356)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Draw \(drawNumber) revealed" : "Draw card")
            .accessibilityIdentifier("deck.drawCard")

            if isRevealed {
                revealedActionPanel
            } else {
                drawPrompt
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Color.unbound.bg)
    }

    private var flipCard: some View {
        ZStack {
            if isRevealed {
                realCardFace
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                cardBack
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .rotation3DEffect(
            .degrees(cardFlipDegrees),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
        .rotationEffect(.degrees(isDrawing ? 0 : isRevealed ? 2 : -3))
        .scaleEffect(isDrawing ? 1.06 : isRevealed ? 1.01 : 1)
        .shadow(color: suitTint.opacity(isRevealed ? 0.28 : 0.18), radius: 24, y: 14)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.36), value: isRevealed)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.34), value: isDrawing)
    }

    private var drawPrompt: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.coachCyan)
            Text("Tap to flip the next card.")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer(minLength: 0)
            Text(restText)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 4)
    }

    private var revealedActionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if let definition = movementDefinition {
                    ExerciseVisualView(definition: definition, size: .thumbnail)
                        .frame(width: 70, height: 56)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DO \(exercise.plannedReps.uppercased())")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(suitTint)
                    Text(exercise.name)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text("Rest \(restTimeString(exercise.restSeconds)).")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }

                Spacer(minLength: 0)
            }

            Button(action: onComplete) {
                HStack(spacing: 10) {
                    Image(systemName: drawIndex >= totalDraws - 1 ? "checkmark.seal.fill" : "rectangle.stack.badge.plus")
                        .font(.system(size: 14, weight: .black))
                    Text(drawIndex >= totalDraws - 1 ? "DONE - FINISH DECK" : "DONE - NEXT CARD")
                        .font(Font.unbound.bodyM.weight(.heavy))
                        .tracking(1.4)
                }
                .foregroundStyle(Color.unbound.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(suitTint))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("deck.completeCard")
        }
    }

    private var drawTableGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    suitTint.opacity(isRevealed ? 0.26 : 0.18),
                    Color.unbound.accent.opacity(isRevealed ? 0.11 : 0.08),
                    .clear
                ],
                center: .center,
                startRadius: 24,
                endRadius: 190
            )
            .frame(width: 330, height: 300)
            .blur(radius: 8)

            Ellipse()
                .fill(Color.black.opacity(0.34))
                .frame(width: 294, height: 42)
                .blur(radius: 12)
                .offset(y: 146)
        }
        .allowsHitTesting(false)
    }

    private var deckStack: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { offset in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                    .frame(width: 232, height: 314)
                    .rotationEffect(.degrees(Double(offset - 1) * 5))
                    .offset(x: CGFloat(offset - 1) * 16, y: CGFloat(offset) * -5)
                    .opacity(isRevealed ? 0.20 : 0.82)
            }
        }
        .offset(x: isDrawing ? -28 : 0, y: isDrawing ? 8 : 0)
    }

    private var realCardFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.965, green: 0.955, blue: 0.925))
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(cardInk.opacity(0.28), lineWidth: 1.4)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    cardCorner
                    Spacer()
                    Text("DRAW \(drawNumber)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Color.black.opacity(0.46))
                }

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text(suitGlyph)
                        .font(.system(size: 66, weight: .bold, design: .serif))
                        .foregroundStyle(cardInk)
                        .lineLimit(1)
                    Text(cardFaceText)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(cardInk)
                    Text(cardTitle.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.black.opacity(0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Divider()
                        .overlay(cardInk.opacity(0.18))
                        .padding(.horizontal, 24)
                    Text(exercise.name.uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.black.opacity(0.82))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(exercise.plannedReps.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(cardInk)
                }

                Spacer(minLength: 12)

                HStack {
                    Spacer()
                    cardCorner
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(18)
        }
    }

    private var cardCorner: some View {
        VStack(spacing: 1) {
            Text(cardRankCode)
                .font(.system(size: 20, weight: .black, design: .rounded))
            Text(suitGlyph)
                .font(.system(size: 18, weight: .bold, design: .serif))
        }
        .foregroundStyle(cardInk)
        .frame(width: 34, alignment: .center)
    }

    private var cardBack: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.coachCyan.opacity(0.32),
                                Color.unbound.accent.opacity(0.18),
                                Color.unbound.bg.opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.coachCyan.opacity(0.42), lineWidth: 1)
                    .padding(14)
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Color.unbound.coachCyan)
                    Text("DRAW CARD")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("DECK \(remainingDrawsText)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
        }
    }

    private var revealedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DRAW \(drawNumber)")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                    Text("CARD \(cardNumber)")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer()
                Image(systemName: suitSymbol)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(suitTint)
            }
            .foregroundStyle(suitTint)

            if let definition = movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                    )
                    .frame(height: 150)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(cardTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                Text(exercise.name)
                    .font(Font.unbound.bodyM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text("\(exercise.plannedSets) x \(exercise.plannedReps)")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 246, height: 330, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(suitTint.opacity(0.44), lineWidth: 1)
        )
        .shadow(color: suitTint.opacity(0.20), radius: 20, y: 10)
    }

    private var drawNumber: String {
        numberString(drawIndex + 1)
    }

    private var cardWidth: CGFloat { isRevealed ? 230 : 250 }

    private var cardHeight: CGFloat { isRevealed ? 312 : 338 }

    private var cardFlipDegrees: Double {
        if isRevealed { return 180 }
        if isDrawing { return 90 }
        return 0
    }

    private var cardNumber: String {
        deckCardDescriptor?.number ?? drawNumber
    }

    private var cardFaceText: String {
        "\(cardRankCode)\(suitGlyph)"
    }

    private var cardRankCode: String {
        guard cardSuitCode != nil, !cardNumber.isEmpty else { return cardNumber }
        return String(cardNumber.dropLast())
    }

    private var cardTitle: String {
        deckCardDescriptor?.title ?? exercise.blockTitle ?? "Proof"
    }

    private var remainingDrawsText: String {
        "\(max(1, totalDraws - drawIndex)) LEFT"
    }

    private var restText: String {
        "REST \(restTimeString(exercise.restSeconds))"
    }

    private var deckCardDescriptor: (number: String, title: String)? {
        guard let blockTitle = exercise.blockTitle else { return nil }
        let prefix = "Card "
        guard blockTitle.hasPrefix(prefix) else { return nil }

        let remainder = blockTitle.dropFirst(prefix.count)
        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let number = parts.first else { return nil }
        let title = parts.dropFirst().first.map(String.init) ?? blockTitle
        return (String(number), title)
    }

    private var movementDefinition: MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    private var suitSymbol: String {
        switch cardSuitCode {
        case "S": return "suit.spade.fill"
        case "H": return "suit.heart.fill"
        case "D": return "suit.diamond.fill"
        case "C": return "suit.club.fill"
        default:
            break
        }

        switch cardIndex % 4 {
        case 0: return "suit.spade.fill"
        case 1: return "suit.heart.fill"
        case 2: return "suit.diamond.fill"
        default: return "suit.club.fill"
        }
    }

    private var suitGlyph: String {
        switch cardSuitCode {
        case "S": return "♠"
        case "H": return "♥"
        case "D": return "♦"
        case "C": return "♣"
        default: return "♠"
        }
    }

    private var suitTint: Color {
        switch cardSuitCode {
        case "S", "C":
            return Color.unbound.coachCyan
        case "H", "D":
            return Color.unbound.emberGlow
        default:
            break
        }

        switch cardIndex % 4 {
        case 0, 3:
            return Color.unbound.coachCyan
        default:
            return Color.unbound.emberGlow
        }
    }

    private var cardInk: Color {
        switch cardSuitCode {
        case "H", "D":
            return Color(red: 0.72, green: 0.04, blue: 0.08)
        default:
            return Color(red: 0.06, green: 0.07, blue: 0.08)
        }
    }

    private var cardSuitCode: String? {
        guard let last = cardNumber.last else { return nil }
        let code = String(last).uppercased()
        return ["S", "H", "D", "C"].contains(code) ? code : nil
    }

    private var cardIndex: Int {
        max(0, (Int(cardNumber) ?? (drawIndex + 1)) - 1)
    }

    private func numberString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private func restTimeString(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
