import SwiftUI

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var analysis: BodyAnalysis
    @Published var showShareSheet = false

    private let services: ServiceContainer

    init(analysis: BodyAnalysis, services: ServiceContainer) {
        self.analysis = analysis
        self.services = services
        services.analytics.track(.reportViewed(scanId: analysis.scanId, score: analysis.overallScore))
    }

    var radarData: [MuscleRadarChart.RadarDataPoint] {
        analysis.muscleAssessments.map { assessment in
            MuscleRadarChart.RadarDataPoint(
                label: assessment.muscleGroup.displayName,
                current: CGFloat(assessment.currentScore),
                target: CGFloat(assessment.targetScore)
            )
        }
    }

    func shareReport() {
        showShareSheet = true
        services.analytics.track(.reportShared(scanId: analysis.scanId))
    }

    func unlockProgram() async -> PaywallResult {
        await services.paywall.triggerPaywall(placement: AppConstants.Paywall.reportUnlockProgram)
    }
}
