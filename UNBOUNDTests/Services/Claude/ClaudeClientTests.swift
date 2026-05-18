import XCTest
@testable import UNBOUND

final class ClaudeClientTests: XCTestCase {

    private func encodedKeys(_ body: ClaudeClient.RequestBody) throws -> [String: Any] {
        let data = try JSONEncoder().encode(body)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func testTemperatureOmittedWhenNil() throws {
        let body = ClaudeClient.RequestBody(
            model: "claude-haiku-4-5-20251001",
            maxTokens: 128,
            system: "sys",
            messages: [ClaudeClient.Message(role: "user", content: [.text("hi")])],
            tools: nil,
            toolChoice: nil,
            temperature: nil
        )
        let json = try encodedKeys(body)
        XCTAssertNil(json["temperature"], "nil temperature must be omitted")
        XCTAssertEqual(json["max_tokens"] as? Int, 128)
    }

    func testTemperatureEncodedWhenSet() throws {
        let body = ClaudeClient.RequestBody(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            system: "sys",
            messages: [ClaudeClient.Message(role: "user", content: [.text("hi")])],
            tools: nil,
            toolChoice: nil,
            temperature: 0.45
        )
        let json = try encodedKeys(body)
        XCTAssertEqual(json["temperature"] as? Double, 0.45)
    }
}
