import Foundation
import SwiftUI

// MARK: - SVGPathParser
//
// Minimal SVG path-data parser covering the command set produced by
// react-native-body-highlighter's exported paths: M/m (move), L/l (line),
// H/h (hline), V/v (vline), C/c (cubic), S/s (smooth cubic), Q/q
// (quadratic), T/t (smooth quad), A/a (arc — falls back to line for now,
// not used in this asset), Z/z (close).
//
// Numbers may be space- or comma-separated, with optional leading signs
// and implicit repeated commands (e.g. `L 1,2 3,4` means two line-tos).

enum SVGPathParser {
    /// Parse a single SVG path data string into a SwiftUI `Path`.
    static func path(from d: String) -> Path {
        var path = Path()
        var scanner = Scanner(d: d)
        var lastCommand: Character = " "
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        var lastCtrl2 = CGPoint.zero     // for S/s reflection
        var lastCtrlQ = CGPoint.zero     // for T/t reflection

        while let cmd = scanner.readCommand() ?? implicitCommand(for: lastCommand) {
            lastCommand = cmd
            switch cmd {
            case "M", "m":
                guard let p = scanner.readPoint() else { return path }
                let target = cmd == "M" ? p : currentPoint + p
                path.move(to: target)
                currentPoint = target
                startPoint = target
                // Subsequent implicit points after M are treated as L
                while let next = scanner.peekNumber() {
                    _ = next
                    guard let q = scanner.readPoint() else { break }
                    let t = cmd == "M" ? q : currentPoint + q
                    path.addLine(to: t)
                    currentPoint = t
                }

            case "L", "l":
                guard let p = scanner.readPoint() else { return path }
                let target = cmd == "L" ? p : currentPoint + p
                path.addLine(to: target)
                currentPoint = target
                while scanner.peekNumber() != nil, let q = scanner.readPoint() {
                    let t = cmd == "L" ? q : currentPoint + q
                    path.addLine(to: t)
                    currentPoint = t
                }

            case "H", "h":
                while let x = scanner.readNumber() {
                    let target = CGPoint(
                        x: cmd == "H" ? x : currentPoint.x + x,
                        y: currentPoint.y
                    )
                    path.addLine(to: target)
                    currentPoint = target
                    if scanner.peekNumber() == nil { break }
                }

            case "V", "v":
                while let y = scanner.readNumber() {
                    let target = CGPoint(
                        x: currentPoint.x,
                        y: cmd == "V" ? y : currentPoint.y + y
                    )
                    path.addLine(to: target)
                    currentPoint = target
                    if scanner.peekNumber() == nil { break }
                }

            case "C", "c":
                while let c1 = scanner.readPoint(),
                      let c2 = scanner.readPoint(),
                      let p = scanner.readPoint() {
                    let rel = cmd == "c"
                    let cc1 = rel ? currentPoint + c1 : c1
                    let cc2 = rel ? currentPoint + c2 : c2
                    let tgt = rel ? currentPoint + p : p
                    path.addCurve(to: tgt, control1: cc1, control2: cc2)
                    lastCtrl2 = cc2
                    currentPoint = tgt
                    if scanner.peekNumber() == nil { break }
                }

            case "S", "s":
                while let c2 = scanner.readPoint(), let p = scanner.readPoint() {
                    let rel = cmd == "s"
                    // Reflect lastCtrl2 across currentPoint
                    let c1 = CGPoint(
                        x: 2 * currentPoint.x - lastCtrl2.x,
                        y: 2 * currentPoint.y - lastCtrl2.y
                    )
                    let cc2 = rel ? currentPoint + c2 : c2
                    let tgt = rel ? currentPoint + p : p
                    path.addCurve(to: tgt, control1: c1, control2: cc2)
                    lastCtrl2 = cc2
                    currentPoint = tgt
                    if scanner.peekNumber() == nil { break }
                }

            case "Q", "q":
                while let c1 = scanner.readPoint(), let p = scanner.readPoint() {
                    let rel = cmd == "q"
                    let cc1 = rel ? currentPoint + c1 : c1
                    let tgt = rel ? currentPoint + p : p
                    path.addQuadCurve(to: tgt, control: cc1)
                    lastCtrlQ = cc1
                    currentPoint = tgt
                    if scanner.peekNumber() == nil { break }
                }

            case "T", "t":
                while let p = scanner.readPoint() {
                    let rel = cmd == "t"
                    let c1 = CGPoint(
                        x: 2 * currentPoint.x - lastCtrlQ.x,
                        y: 2 * currentPoint.y - lastCtrlQ.y
                    )
                    let tgt = rel ? currentPoint + p : p
                    path.addQuadCurve(to: tgt, control: c1)
                    lastCtrlQ = c1
                    currentPoint = tgt
                    if scanner.peekNumber() == nil { break }
                }

            case "A", "a":
                // Arc: rx ry xRotate largeArc sweep x y. We approximate with
                // a straight line — the highlighter asset doesn't use arcs
                // for muscle geometry, so this is a safe fallback.
                while let _ = scanner.readNumber(),          // rx
                      let _ = scanner.readNumber(),          // ry
                      let _ = scanner.readNumber(),          // xRotate
                      let _ = scanner.readNumber(),          // largeArc
                      let _ = scanner.readNumber(),          // sweep
                      let p = scanner.readPoint() {
                    let rel = cmd == "a"
                    let tgt = rel ? currentPoint + p : p
                    path.addLine(to: tgt)
                    currentPoint = tgt
                    if scanner.peekNumber() == nil { break }
                }

            case "Z", "z":
                path.closeSubpath()
                currentPoint = startPoint

            default:
                return path
            }
        }
        return path
    }

    /// After a command finishes, additional coordinate pairs with no new
    /// command letter reuse the last command — but M implicitly becomes L,
    /// and close-path has no implicit form.
    private static func implicitCommand(for last: Character) -> Character? {
        switch last {
        case "M": return "L"
        case "m": return "l"
        case "Z", "z": return nil
        case " ": return nil
        default:  return last
        }
    }
}

// MARK: - Scanner

private struct Scanner {
    private let chars: [Character]
    private var i: Int = 0

    init(d: String) {
        self.chars = Array(d)
    }

    var atEnd: Bool { i >= chars.count }

    mutating func readCommand() -> Character? {
        skipSeparators()
        guard !atEnd else { return nil }
        let c = chars[i]
        if c.isLetter {
            i += 1
            return c
        }
        return nil
    }

    mutating func readPoint() -> CGPoint? {
        guard let x = readNumber(), let y = readNumber() else { return nil }
        return CGPoint(x: x, y: y)
    }

    mutating func readNumber() -> Double? {
        skipSeparators()
        guard !atEnd else { return nil }
        let start = i
        // Optional sign
        if chars[i] == "+" || chars[i] == "-" { i += 1 }
        var hasDigit = false
        while i < chars.count, chars[i].isNumber {
            hasDigit = true
            i += 1
        }
        if i < chars.count, chars[i] == "." {
            i += 1
            while i < chars.count, chars[i].isNumber {
                hasDigit = true
                i += 1
            }
        }
        // Optional exponent
        if i < chars.count, chars[i] == "e" || chars[i] == "E" {
            i += 1
            if i < chars.count, chars[i] == "+" || chars[i] == "-" { i += 1 }
            while i < chars.count, chars[i].isNumber { i += 1 }
        }
        guard hasDigit else {
            i = start
            return nil
        }
        return Double(String(chars[start..<i]))
    }

    func peekNumber() -> Double? {
        var copy = self
        copy.skipSeparators()
        guard !copy.atEnd else { return nil }
        let c = copy.chars[copy.i]
        if c == "+" || c == "-" || c == "." || c.isNumber { return 0 }
        return nil
    }

    mutating func skipSeparators() {
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "," || c == "\t" || c == "\n" || c == "\r" { i += 1 }
            else { break }
        }
    }
}

// MARK: - CGPoint helpers

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
