import Foundation

@MainActor
final class MockBodyAnalysisService: BodyAnalysisServiceProtocol {
    func flavorCopy(for identity: BuildIdentity) async -> String {
        "Mock flavor copy."
    }
}
