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

    // A canned transport so no network is touched.
    final class MockClaudeTransport: ClaudeTransport, @unchecked Sendable {
        var responses: [(data: Data, status: Int)]
        private(set) var sentBodies: [ClaudeClient.RequestBody] = []
        init(_ responses: [(data: Data, status: Int)]) { self.responses = responses }
        func send(_ body: ClaudeClient.RequestBody) async throws -> (data: Data, status: Int) {
            sentBodies.append(body)
            return responses.isEmpty
                ? (Data("{}".utf8), 500)
                : responses.removeFirst()
        }
    }

    private func toolUseJSON(_ obj: String) -> Data {
        Data("""
        {"id":"m","model":"claude-haiku-4-5-20251001","stop_reason":"tool_use",
         "content":[{"type":"tool_use","id":"t","name":"echo","input":\(obj)}]}
        """.utf8)
    }

    struct Echo: Decodable, Equatable { let v: Int }

    func testStructuredDecodesToolUseAndSendsModelAndToolChoice() async throws {
        let mock = MockClaudeTransport([(toolUseJSON(#"{"v":7}"#), 200)])
        let client = ClaudeClient(transport: mock)
        let tool = ClaudeClient.Tool(name: "echo", description: "d",
                                     inputSchema: .object(["v": .string("integer")]))
        let out: Echo = try await client.sendStructured(
            Echo.self, model: .haiku45, system: "s", userText: "u",
            tool: tool, maxTokens: 64, temperature: 0.5)
        XCTAssertEqual(out, Echo(v: 7))
        let body = try XCTUnwrap(mock.sentBodies.first)
        XCTAssertEqual(body.model, "claude-haiku-4-5-20251001")
        XCTAssertEqual(body.toolChoice?.name, "echo")
        XCTAssertEqual(body.temperature, 0.5)
    }

    func testDoesNotRetryOn400ButRetriesOn429() async throws {
        let bad = Data(#"{"error":"bad"}"#.utf8)
        let mock400 = MockClaudeTransport([(bad, 400), (toolUseJSON(#"{"v":1}"#), 200)])
        let c1 = ClaudeClient(transport: mock400)
        let tool = ClaudeClient.Tool(name: "echo", description: "d",
                                     inputSchema: .object([:]))
        do {
            let _: Echo = try await c1.sendStructured(Echo.self, system: "s",
                                                      userText: "u", tool: tool)
            XCTFail("400 must not be retried/succeed")
        } catch {}
        XCTAssertEqual(mock400.sentBodies.count, 1, "400 must NOT retry")

        let mock429 = MockClaudeTransport([(bad, 429), (toolUseJSON(#"{"v":2}"#), 200)])
        let c2 = ClaudeClient(transport: mock429)
        let ok: Echo = try await c2.sendStructured(Echo.self, system: "s",
                                                   userText: "u", tool: tool)
        XCTAssertEqual(ok, Echo(v: 2))
        XCTAssertEqual(mock429.sentBodies.count, 2, "429 must retry once then succeed")
    }

    // Proof B (no local backdoor): when the server's entitlement check denies
    // the premium call (HTTP 403 from anthropic_proxy), the client surfaces a
    // distinct .premiumRequired error and does NOT retry or unlock — the server
    // flag, not any local entitlement, decides access.
    func testServer403SurfacesPremiumRequiredAndDoesNotRetry() async throws {
        let denied = Data(#"{"error":"premium_required"}"#.utf8)
        // Even if a follow-up call would succeed, a 403 must short-circuit.
        let mock = MockClaudeTransport([(denied, 403), (toolUseJSON(#"{"v":9}"#), 200)])
        let client = ClaudeClient(transport: mock)
        let tool = ClaudeClient.Tool(name: "echo", description: "d",
                                     inputSchema: .object([:]))
        do {
            let _: Echo = try await client.sendStructured(Echo.self, system: "s",
                                                          userText: "u", tool: tool)
            XCTFail("403 must not unlock premium content")
        } catch let error as ClaudeClient.ClaudeError {
            guard case .premiumRequired = error else {
                return XCTFail("expected .premiumRequired, got \(error)")
            }
        }
        XCTAssertEqual(mock.sentBodies.count, 1, "403 must NOT retry")
    }
}
