import SwiftUI

struct ReportContainerView: View {
    @StateObject private var viewModel: ReportViewModel
    @EnvironmentObject var services: ServiceContainer

    init(analysis: BodyAnalysis, services: ServiceContainer) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(analysis: analysis, services: services))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BodyScoreCard(analysis: viewModel.analysis)
                MuscleGroupBreakdown(
                    assessments: viewModel.analysis.muscleAssessments,
                    radarData: viewModel.radarData
                )
                ProportionAnalysis(proportions: viewModel.analysis.proportions)
                GapAnalysisView(focusAreas: viewModel.analysis.focusAreas, onUnlock: {
                    Task {
                        let result = await viewModel.unlockProgram()
                        // Handle result
                        _ = result
                    }
                })
            }
            .padding(16)
        }
        .background(Color.theme.background)
        .navigationTitle("Your Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.shareReport() } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.theme.primary)
                }
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            ReportShareView(analysis: viewModel.analysis)
        }
    }
}
