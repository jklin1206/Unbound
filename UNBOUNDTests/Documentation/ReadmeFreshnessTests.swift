import XCTest

/// Enforces the README maintenance contract from ARCHITECTURE.md:
/// every directory that carries a README.md must keep it in sync with the
/// Swift files that actually live there, in the same change that adds,
/// renames, or removes a file. A stale README is worse than none — it routes
/// agents (and humans) to files that don't exist or hides ones that do.
///
/// Two invariants per README directory:
/// 1. Roster: every `*.swift` file directly in the directory is mentioned
///    somewhere in its README (catches adds/renames that skipped the doc).
/// 2. No ghosts: every path-less `X.swift` token inside a markdown table row
///    of the README exists in that directory (catches deletes/renames that
///    left a stale table row behind). Cross-directory references are fine as
///    long as they include a `/` (e.g. `../Scan/NutritionTargetCalculator.swift`).
final class ReadmeFreshnessTests: XCTestCase {

    func testReadmeTablesMatchDirectoryContents() throws {
        let appRoot = try Self.appSourceRoot()
        let fm = FileManager.default

        var rosterFailures: [String] = []
        var ghostFailures: [String] = []
        var checkedReadmeCount = 0

        let enumerator = try XCTUnwrap(fm.enumerator(at: appRoot, includingPropertiesForKeys: [.isDirectoryKey]))
        for case let url as URL in enumerator {
            guard url.lastPathComponent == "README.md" else { continue }
            let dir = url.deletingLastPathComponent()
            let relDir = dir.path.replacingOccurrences(of: appRoot.path, with: "UNBOUND")
            if relDir.contains(".xcassets") { continue }

            let readme = try String(contentsOf: url, encoding: .utf8)
            checkedReadmeCount += 1

            let swiftFilesOnDisk = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "swift" }
                .map(\.lastPathComponent)

            // Invariant 1 — roster: every real file is mentioned.
            for file in swiftFilesOnDisk where !readme.contains(file) {
                rosterFailures.append("\(relDir)/\(file) exists but is not mentioned in \(relDir)/README.md")
            }

            // Invariant 2 — no ghosts: path-less .swift tokens in table rows must exist here.
            let diskSet = Set(swiftFilesOnDisk)
            for line in readme.split(separator: "\n") where line.hasPrefix("|") {
                for token in Self.backtickedSwiftTokens(in: String(line)) where !token.contains("/") {
                    if !diskSet.contains(token) {
                        ghostFailures.append("\(relDir)/README.md table row references `\(token)` which does not exist in \(relDir)")
                    }
                }
            }
        }

        XCTAssertGreaterThan(checkedReadmeCount, 30, "README sweep found suspiciously few READMEs — did the navigation layer move?")

        if !rosterFailures.isEmpty || !ghostFailures.isEmpty {
            let message = (
                ["README freshness contract violated (update the README in the same change that adds/renames/removes files — see ARCHITECTURE.md):"]
                + rosterFailures.map { "  MISSING ROW: \($0)" }
                + ghostFailures.map { "  STALE ROW: \($0)" }
            ).joined(separator: "\n")
            XCTFail(message)
        }
    }

    // MARK: - Helpers

    /// Walks up from this test file to the repo checkout and returns UNBOUND/.
    private static func appSourceRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("UNBOUND")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("App").path, isDirectory: &isDir), isDir.boolValue {
                return candidate
            }
        }
        throw XCTSkip("Could not locate the UNBOUND source root from #filePath — running outside a source checkout.")
    }

    private static func backtickedSwiftTokens(in line: String) -> [String] {
        var tokens: [String] = []
        var remainder = Substring(line)
        while let open = remainder.firstIndex(of: "`") {
            remainder = remainder[remainder.index(after: open)...]
            guard let close = remainder.firstIndex(of: "`") else { break }
            let token = String(remainder[..<close])
            if token.hasSuffix(".swift") { tokens.append(token) }
            remainder = remainder[remainder.index(after: close)...]
        }
        return tokens
    }
}
