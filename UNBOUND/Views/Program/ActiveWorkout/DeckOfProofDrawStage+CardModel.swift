import SwiftUI

// MARK: - DeckOfProofDrawStage card model
//
// Derives the playing-card descriptor (rank/suit/title/tint/dimensions) and
// formatting helpers from the exercise block metadata.

extension DeckOfProofDrawStage {
    var drawNumber: String {
        numberString(drawIndex + 1)
    }

    var cardWidth: CGFloat { isRevealed ? 230 : 250 }

    var cardHeight: CGFloat { isRevealed ? 312 : 338 }

    var cardFlipDegrees: Double {
        if isRevealed { return 180 }
        if isDrawing { return 90 }
        return 0
    }

    var cardNumber: String {
        deckCardDescriptor?.number ?? drawNumber
    }

    var cardFaceText: String {
        "\(cardRankCode)\(suitGlyph)"
    }

    var cardRankCode: String {
        guard cardSuitCode != nil, !cardNumber.isEmpty else { return cardNumber }
        return String(cardNumber.dropLast())
    }

    var cardTitle: String {
        deckCardDescriptor?.title ?? exercise.blockTitle ?? "Proof"
    }

    var remainingDrawsText: String {
        "\(max(1, totalDraws - drawIndex)) LEFT"
    }

    var restText: String {
        "REST \(restTimeString(exercise.restSeconds))"
    }

    var deckCardDescriptor: (number: String, title: String)? {
        guard let blockTitle = exercise.blockTitle else { return nil }
        let prefix = "Card "
        guard blockTitle.hasPrefix(prefix) else { return nil }

        let remainder = blockTitle.dropFirst(prefix.count)
        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let number = parts.first else { return nil }
        let title = parts.dropFirst().first.map(String.init) ?? blockTitle
        return (String(number), title)
    }

    var movementDefinition: MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    var suitSymbol: String {
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

    var suitGlyph: String {
        switch cardSuitCode {
        case "S": return "♠"
        case "H": return "♥"
        case "D": return "♦"
        case "C": return "♣"
        default: return "♠"
        }
    }

    var suitTint: Color {
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

    var cardInk: Color {
        switch cardSuitCode {
        case "H", "D":
            return Color(red: 0.72, green: 0.04, blue: 0.08)
        default:
            return Color(red: 0.06, green: 0.07, blue: 0.08)
        }
    }

    var cardSuitCode: String? {
        guard let last = cardNumber.last else { return nil }
        let code = String(last).uppercased()
        return ["S", "H", "D", "C"].contains(code) ? code : nil
    }

    var cardIndex: Int {
        max(0, (Int(cardNumber) ?? (drawIndex + 1)) - 1)
    }

    func numberString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    func restTimeString(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
