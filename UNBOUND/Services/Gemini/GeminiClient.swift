import Foundation

// Google Gemini REST client. Used for vision-heavy structured output —
// cheaper than Claude for image analysis at comparable quality on this task.

final class GeminiClient: @unchecked Sendable {
    static let shared = GeminiClient()

    enum Model: String {
        case flash25 = "gemini-2.5-flash"
        case pro25 = "gemini-2.5-pro"
    }

    enum GeminiError: LocalizedError {
        case apiError(status: Int, message: String)
        case emptyResponse
        case invalidResponse
        case decodingFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .apiError(let s, let m): return "Gemini API \(s): \(m)"
            case .emptyResponse: return "Gemini returned no content"
            case .invalidResponse: return "Invalid Gemini response"
            case .decodingFailed(let e): return "Gemini output decode failed: \(e.localizedDescription)"
            }
        }
    }

    private let session: URLSession
    private let logger = LoggingService.shared
    private let maxRetries = 3

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func generateStructured<T: Decodable>(
        _ type: T.Type = T.self,
        model: Model = .flash25,
        systemInstruction: String,
        userText: String,
        jpegImages: [Data] = [],
        responseSchema: JSONValue,
        maxOutputTokens: Int = 4096,
        temperature: Double = 0.3
    ) async throws -> T {
        var parts: [Part] = jpegImages.map {
            .inlineData(mimeType: "image/jpeg", base64: $0.base64EncodedString())
        }
        parts.append(.text(userText))

        let body = RequestBody(
            contents: [Content(role: "user", parts: parts)],
            systemInstruction: Content(role: "system", parts: [.text(systemInstruction)]),
            generationConfig: GenerationConfig(
                temperature: temperature,
                maxOutputTokens: maxOutputTokens,
                responseMimeType: "application/json",
                responseSchema: responseSchema
            )
        )

        let response = try await sendWithRetry(body: body, model: model)

        guard let candidate = response.candidates.first,
              let textPart = candidate.content.parts.first(where: { if case .text = $0 { return true }; return false }),
              case .text(let jsonString) = textPart,
              let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.emptyResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            throw GeminiError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Internals

    private func sendWithRetry(body: RequestBody, model: Model) async throws -> ResponseBody {
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                return try await send(body: body, model: model)
            } catch let error as GeminiError {
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
                logger.log("Gemini retry attempt \(attempt)", level: .warning)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        throw lastError ?? GeminiError.invalidResponse
    }

    private func send(body: RequestBody, model: Model) async throws -> ResponseBody {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.apiError(status: http.statusCode, message: message)
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
}

// MARK: - Types

extension GeminiClient {
    struct RequestBody: Encodable {
        let contents: [Content]
        let systemInstruction: Content?
        let generationConfig: GenerationConfig
    }

    struct Content: Encodable {
        let role: String
        let parts: [Part]
    }

    enum Part: Encodable {
        case text(String)
        case inlineData(mimeType: String, base64: String)

        private enum Keys: String, CodingKey {
            case text, inline_data
        }
        private enum InlineKeys: String, CodingKey {
            case mime_type, data
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: Keys.self)
            switch self {
            case .text(let s):
                try c.encode(s, forKey: .text)
            case .inlineData(let mime, let base64):
                var inner = c.nestedContainer(keyedBy: InlineKeys.self, forKey: .inline_data)
                try inner.encode(mime, forKey: .mime_type)
                try inner.encode(base64, forKey: .data)
            }
        }
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
        let responseMimeType: String
        let responseSchema: JSONValue

        enum CodingKeys: String, CodingKey {
            case temperature
            case maxOutputTokens = "maxOutputTokens"
            case responseMimeType = "responseMimeType"
            case responseSchema = "responseSchema"
        }
    }

    struct ResponseBody: Decodable {
        let candidates: [Candidate]
    }

    struct Candidate: Decodable {
        let content: ResponseContent
        let finishReason: String?
    }

    struct ResponseContent: Decodable {
        let parts: [ResponsePart]
        let role: String?
    }

    enum ResponsePart: Decodable {
        case text(String)
        case unknown

        private enum Keys: String, CodingKey {
            case text
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            if let t = try c.decodeIfPresent(String.self, forKey: .text) {
                self = .text(t)
            } else {
                self = .unknown
            }
        }
    }
}
