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

    /// The draw table — a warm bloom with a summoning circle the deck rests inside.
    private var drawTableGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    suitTint.opacity(isRevealed ? 0.30 : 0.20),
                    Color.unbound.accent.opacity(isRevealed ? 0.11 : 0.08),
                    .clear
                ],
                center: .center,
                startRadius: 22,
                endRadius: 200
            )
            .frame(width: 340, height: 320)
            .blur(radius: 9)

            // ritual rings laid flat on the table beneath the deck
            ForEach(0..<2, id: \.self) { ring in
                Circle()
                    .strokeBorder(suitTint.opacity(0.24 - Double(ring) * 0.09), lineWidth: 1)
                    .frame(width: 250 + CGFloat(ring) * 64, height: 250 + CGFloat(ring) * 64)
                    .scaleEffect(y: 0.32, anchor: .center)
                    .offset(y: 120)
            }

            Ellipse()
                .fill(Color.black.opacity(0.34))
                .frame(width: 300, height: 44)
                .blur(radius: 13)
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

            // large suit watermark for forged depth
            Text(suitGlyph)
                .font(.system(size: 150, weight: .bold, design: .serif))
                .foregroundStyle(suitTint.opacity(0.08))

            // ornate suit-tinted inner frame
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(suitTint.opacity(0.34), lineWidth: 1)
                .padding(10)

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

    /// The card back — a forged crest: concentric sigil rings around the suit mark,
    /// in the gate's arcane language rather than a generic playing-card back.
    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.unbound.surfaceElevated, Color.unbound.bg],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(suitTint.opacity(0.55), lineWidth: 1.4)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(suitTint.opacity(0.26), lineWidth: 1)
                .padding(11)

            // the forged crest
            ZStack {
                ForEach(0..<3, id: \.self) { r in
                    Circle()
                        .strokeBorder(suitTint.opacity(0.5 - Double(r) * 0.13), lineWidth: 1.1)
                        .frame(width: 60 + CGFloat(r) * 28, height: 60 + CGFloat(r) * 28)
                }
                ForEach(0..<4, id: \.self) { s in
                    Capsule()
                        .fill(suitTint.opacity(0.30))
                        .frame(width: 1.4, height: 18)
                        .offset(y: -57)
                        .rotationEffect(.degrees(Double(s) * 90))
                }
                Text(suitGlyph)
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(colors: [.white.opacity(0.95), suitTint],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: suitTint.opacity(0.7), radius: 10)
            }
            .offset(y: -10)

            VStack(spacing: 3) {
                Spacer()
                Text("DRAW CARD")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("DECK \(remainingDrawsText)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(suitTint)
            }
            .padding(.bottom, 30)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}
