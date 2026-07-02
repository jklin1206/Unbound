import XCTest
@testable import UNBOUND

// Locks the squads row-coding contract:
//
//   UnboundSupabase.dbDecoder uses .convertFromSnakeCase, which rewrites the
//   JSON keys ("squad_id" → "squadId") BEFORE matching them against a struct's
//   CodingKeys. A Decodable property named `squad_id` therefore never matches
//   and the whole fetch throws keyNotFound. This broke every squads read path
//   for real accounts (create/fetch squad, roster, activity, challenges,
//   missions, honors, presence, linked sessions) while the DEBUG local-squad
//   path masked it.
//
// Two guards:
//   1. A live decode proof that the camelCase convention parses a realistic
//      PostgREST payload (snake keys + fractional-second timestamps), and the
//      snake_case anti-pattern fails.
//   2. A source scan of UNBOUND/Services/Squads that fails if any Decodable
//      row struct re-introduces a snake_case property.
final class SquadRowCodingConventionTests: XCTestCase {

    // MARK: - 1. Decoder behavior proof

    private struct CamelRow: Decodable {
        let squadId: UUID
        let createdAt: Date
    }

    private struct SnakeRow: Decodable {
        let squad_id: UUID
        let created_at: Date
    }

    private let sampleJSON = Data("""
    {"squad_id":"11111111-2222-3333-4444-555555555555","created_at":"2026-05-14T13:00:04.123456+00:00"}
    """.utf8)

    func testCamelCaseRowDecodesPostgrestPayload() throws {
        let row = try UnboundSupabase.dbDecoder.decode(CamelRow.self, from: sampleJSON)
        XCTAssertEqual(row.squadId.uuidString, "11111111-2222-3333-4444-555555555555")
    }

    func testSnakeCaseRowFailsUnderSharedDecoder() {
        XCTAssertThrowsError(
            try UnboundSupabase.dbDecoder.decode(SnakeRow.self, from: sampleJSON),
            "convertFromSnakeCase rewrites JSON keys to camelCase, so snake_case properties must never appear in Decodable rows"
        )
    }

    // MARK: - 2. Source scan: no snake_case Decodable properties in Squads

    /// Encodable-only request/insert bodies may stay snake_case (the Functions
    /// client encodes with a plain JSONEncoder), so only structs that adopt
    /// Decodable/Codable are scanned.
    func testNoSnakeCaseDecodablePropertiesInSquadServices() throws {
        let squadsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Services
            .deletingLastPathComponent()  // UNBOUNDTests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("UNBOUND/Services/Squads")

        let files = try XCTUnwrap(
            FileManager.default.enumerator(at: squadsDir, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" }
        )
        XCTAssertFalse(files.isEmpty, "Expected Swift sources under Services/Squads")

        let structHeader = try NSRegularExpression(
            pattern: #"struct\s+\w+[^\{]*\b(Decodable|Codable)\b[^\{]*\{"#
        )
        let snakeProperty = try NSRegularExpression(
            pattern: #"^\s*(let|var)\s+[a-z0-9]+_[a-z0-9_]+\s*:"#,
            options: [.anchorsMatchLines]
        )

        var offenders: [String] = []
        for file in files {
            let raw = try String(contentsOf: file, encoding: .utf8)
            // Strip line comments so prose mentioning "struct … Codable" can't
            // register as a struct header.
            let source = raw
                .components(separatedBy: "\n")
                .map { line -> String in
                    guard let range = line.range(of: "//") else { return line }
                    return String(line[..<range.lowerBound])
                }
                .joined(separator: "\n")
            let ns = source as NSString
            let headers = structHeader.matches(in: source, range: NSRange(location: 0, length: ns.length))
            for header in headers {
                // Walk to the struct's closing brace by brace counting.
                var depth = 0
                var index = header.range.location + header.range.length - 1
                var end = ns.length
                while index < ns.length {
                    let ch = ns.character(at: index)
                    if ch == UInt16(("{" as Character).asciiValue!) { depth += 1 }
                    if ch == UInt16(("}" as Character).asciiValue!) {
                        depth -= 1
                        if depth == 0 { end = index; break }
                    }
                    index += 1
                }
                let bodyRange = NSRange(location: header.range.location, length: end - header.range.location)
                if snakeProperty.firstMatch(in: source, range: bodyRange) != nil {
                    let snippet = ns.substring(with: NSRange(location: header.range.location, length: min(60, ns.length - header.range.location)))
                    offenders.append("\(file.lastPathComponent): \(snippet)…")
                }
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "Decodable row structs in Services/Squads must use camelCase properties (dbDecoder converts the JSON keys). Offenders: \(offenders)"
        )
    }
}
