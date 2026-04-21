import Foundation

// Anthropic Messages API client. Supports text and vision, with forced tool use
// for reliable structured-JSON output. Used directly from iOS during validation;
// keys will move server-side before App Store submission.

final class ClaudeClient: @unchecked Sendable {
    static let shared = ClaudeClient()

    enum Model: String {
        case sonnet46 = "claude-sonnet-4-6"
        case opus47 = "claude-opus-4-7"
        case haiku45 = "claude-haiku-4-5-20251001"
    }

    enum ClaudeError: LocalizedError {
        case apiError(status: Int, message: String)
        case noToolUseInResponse
        case noTextInResponse
        case invalidResponse
        case decodingFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .apiError(let status, let message): return "Claude API \(status): \(message)"
            case .noToolUseInResponse: return "Claude did not return structured output"
            case .noTextInResponse: return "Claude returned no text"
            case .invalidResponse: return "Invalid response from Claude"
            case .decodingFailed(let error): return "Failed to decode Claude output: \(error.localizedDescription)"
            }
        }
    }

    private let session: URLSession
    private let logger = LoggingService.shared
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"
    private let maxRetries = 3

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func sendText(
        model: Model = .sonnet46,
        system: String,
        userText: String,
        maxTokens: Int = 1024
    ) async throws -> String {
        let body = RequestBody(
            model: model.rawValue,
            maxTokens: maxTokens,
            system: system,
            messages: [Message(role: "user", content: [.text(userText)])],
            tools: nil,
            toolChoice: nil
        )
        let response = try await sendWithRetry(body: body)
        for block in response.content {
            if case .text(let s) = block { return s }
        }
        throw ClaudeError.noTextInResponse
    }

    func sendStructured<T: Decodable>(
        _ type: T.Type = T.self,
        model: Model = .sonnet46,
        system: String,
        userText: String,
        tool: Tool,
        maxTokens: Int = 4096
    ) async throws -> T {
        try await sendStructuredInternal(
            model: model,
            system: system,
            userBlocks: [.text(userText)],
            tool: tool,
            maxTokens: maxTokens
        )
    }

    func sendStructuredWithImages<T: Decodable>(
        _ type: T.Type = T.self,
        model: Model = .sonnet46,
        system: String,
        userText: String,
        jpegImages: [Data],
        tool: Tool,
        maxTokens: Int = 4096
    ) async throws -> T {
        var blocks: [ContentBlock] = jpegImages.map {
            .image(base64: $0.base64EncodedString(), mediaType: "image/jpeg")
        }
        blocks.append(.text(userText))
        return try await sendStructuredInternal(
            model: model,
            system: system,
            userBlocks: blocks,
            tool: tool,
            maxTokens: maxTokens
        )
    }

    // MARK: - Internals

    private func sendStructuredInternal<T: Decodable>(
        model: Model,
        system: String,
        userBlocks: [ContentBlock],
        tool: Tool,
        maxTokens: Int
    ) async throws -> T {
        let body = RequestBody(
            model: model.rawValue,
            maxTokens: maxTokens,
            system: system,
            messages: [Message(role: "user", content: userBlocks)],
            tools: [tool],
            toolChoice: ToolChoice(type: "tool", name: tool.name)
        )
        let response = try await sendWithRetry(body: body)
        for block in response.content {
            if case .toolUse(_, _, let inputData) = block {
                do {
                    return try JSONDecoder().decode(T.self, from: inputData)
                } catch {
                    throw ClaudeError.decodingFailed(underlying: error)
                }
            }
        }
        throw ClaudeError.noToolUseInResponse
    }

    private func sendWithRetry(body: RequestBody) async throws -> ResponseBody {
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                return try await send(body: body)
            } catch let error as ClaudeError {
                if case .apiError(let status, _) = error,
                   (400...499).contains(status) && status != 429 {
                    throw error
                }
                lastError = error
            } catch {
                lastError = error
            }
            if attempt < maxRetries {
                let delay = pow(2.0, Double(attempt - 1))
                logger.log("Claude retry attempt \(attempt)", level: .warning)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        throw lastError ?? ClaudeError.invalidResponse
    }

    private func send(body: RequestBody) async throws -> ResponseBody {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(Secrets.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeError.apiError(status: http.statusCode, message: message)
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
}

// MARK: - Types

extension ClaudeClient {
    struct Tool: Encodable {
        let name: String
        let description: String
        let inputSchema: JSONValue

        enum CodingKeys: String, CodingKey {
            case name, description
            case inputSchema = "input_schema"
        }
    }

    struct ToolChoice: Encodable {
        let type: String
        let name: String?
    }

    struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]
        let tools: [Tool]?
        let toolChoice: ToolChoice?

        enum CodingKeys: String, CodingKey {
            case model, system, messages, tools
            case maxTokens = "max_tokens"
            case toolChoice = "tool_choice"
        }
    }

    struct Message: Encodable {
        let role: String
        let content: [ContentBlock]
    }

    enum ContentBlock: Encodable {
        case text(String)
        case image(base64: String, mediaType: String)

        private enum Keys: String, CodingKey {
            case type, text, source, media_type, data
        }
        private enum SourceKeys: String, CodingKey {
            case type, media_type, data
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: Keys.self)
            switch self {
            case .text(let s):
                try c.encode("text", forKey: .type)
                try c.encode(s, forKey: .text)
            case .image(let base64, let mediaType):
                try c.encode("image", forKey: .type)
                var src = c.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
                try src.encode("base64", forKey: .type)
                try src.encode(mediaType, forKey: .media_type)
                try src.encode(base64, forKey: .data)
            }
        }
    }

    struct ResponseBody: Decodable {
        let id: String
        let model: String
        let content: [ResponseBlock]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case id, model, content
            case stopReason = "stop_reason"
        }
    }

    enum ResponseBlock: Decodable {
        case text(String)
        case toolUse(id: String, name: String, input: Data)
        case unknown

        private enum Keys: String, CodingKey {
            case type, text, id, name, input
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "text":
                self = .text(try c.decode(String.self, forKey: .text))
            case "tool_use":
                let id = try c.decode(String.self, forKey: .id)
                let name = try c.decode(String.self, forKey: .name)
                let inputJSON = try c.decode(JSONValue.self, forKey: .input)
                let data = try JSONEncoder().encode(inputJSON)
                self = .toolUse(id: id, name: name, input: data)
            default:
                self = .unknown
            }
        }
    }
}
