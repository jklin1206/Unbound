import Foundation

struct CoachResponse {
    let text: String
    let actions: [CoachAction]
}

protocol CoachClientProtocol: Sendable {
    func send(messages: [CoachMessage], context: String) async throws -> CoachResponse
}
