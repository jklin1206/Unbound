import UIKit

protocol BodyAnalysisServiceProtocol: Sendable {
    func analyze(scanSession: ScanSession, photos: [ScanAngle: UIImage], userProfile: UserProfile) async throws -> BodyAnalysis
}
