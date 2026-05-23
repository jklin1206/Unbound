import Foundation

@MainActor
final class BodyAnalysisService: BodyAnalysisServiceProtocol {
    static let shared = BodyAnalysisService()
    private init() {}

    func flavorCopy(for identity: BuildIdentity) async -> String {
        await ScanPayoffFlavorService.shared.flavor(for: identity)
    }
}
