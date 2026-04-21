import SwiftUI

@MainActor
final class BodyScanViewModel: ObservableObject {
    @Published var currentAngle: ScanAngle = .front
    @Published var capturedPhotos: [ScanAngle: UIImage] = [:]
    @Published var selectedArchetype: Archetype = .vTaper
    @Published var scanState: LoadingState<ScanSession> = .idle
    @Published var analysisState: LoadingState<BodyAnalysis> = .idle
    @Published var programState: LoadingState<TrainingProgram> = .idle
    @Published var heightCm: String = ""
    @Published var weightKg: String = ""
    @Published var trainingExperience: TrainingExperience = .beginner
    @Published var analysisProgress: AnalysisProgress = .idle

    enum AnalysisProgress: String {
        case idle = ""
        case uploading = "Uploading photos..."
        case analyzing = "Analyzing your physique..."
        case calculatingMuscles = "Scoring muscle groups..."
        case buildingReport = "Building your report..."
        case complete = "Done!"
        case failed = "Analysis failed"
    }

    let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    var allPhotosCaptured: Bool {
        ScanAngle.allCases.allSatisfy { capturedPhotos[$0] != nil }
    }

    func capturePhoto(_ image: UIImage, for angle: ScanAngle) {
        capturedPhotos[angle] = image
        services.analytics.track(.scanPhotoTaken(angle: angle))
        HapticManager.impact(.light)

        if let nextAngle = ScanAngle.allCases.first(where: { $0.order == angle.order + 1 }) {
            currentAngle = nextAngle
        }

        if allPhotosCaptured {
            services.analytics.track(.scanPhotosCompleted)
        }
    }

    func retakePhoto(for angle: ScanAngle) {
        capturedPhotos[angle] = nil
        currentAngle = angle
    }

    func startAnalysis() async {
        guard allPhotosCaptured else { return }
        guard let userId = services.auth.currentUserId else { return }

        services.analytics.track(.scanAnalysisStarted)
        analysisState = .loading
        analysisProgress = .uploading

        let scanId = UUID().uuidString
        let session = ScanSession(
            id: scanId,
            userId: userId,
            createdAt: Date(),
            targetArchetype: selectedArchetype,
            photos: [],
            analysisId: nil,
            programId: nil,
            status: .photosCapturing,
            heightCm: Double(heightCm),
            weightKg: Double(weightKg),
            trainingExperience: trainingExperience
        )

        do {
            try await services.database.create(session, collection: "scans", documentId: scanId)
            scanState = .loaded(session)

            analysisProgress = .analyzing

            let profile = try await services.user.fetchProfile(userId: userId)

            analysisProgress = .calculatingMuscles

            let analysis = try await services.bodyAnalysis.analyze(
                scanSession: session,
                photos: capturedPhotos,
                userProfile: profile
            )

            analysisProgress = .buildingReport

            try? await services.user.updateProfile(userId: userId, fields: [
                "totalScans": (profile.totalScans + 1),
                "preferredArchetype": selectedArchetype.rawValue
            ])

            analysisProgress = .complete
            HapticManager.notification(.success)
            analysisState = .loaded(analysis)
            services.analytics.track(.scanAnalysisCompleted(score: analysis.overallScore, archetype: selectedArchetype))

        } catch let error as AppError {
            analysisProgress = .failed
            analysisState = .error(error)
            HapticManager.notification(.error)
            services.analytics.track(.scanAnalysisFailed(error: error.localizedDescription))
        } catch {
            analysisProgress = .failed
            analysisState = .error(.unknown(underlying: error))
            HapticManager.notification(.error)
        }
    }

    func generateProgram() async {
        guard case .loaded(let analysis) = analysisState else { return }
        guard let userId = services.auth.currentUserId else { return }

        programState = .loading

        do {
            let profile = try await services.user.fetchProfile(userId: userId)
            let program = try await services.programGeneration.generateProgram(analysis: analysis, userProfile: profile)
            programState = .loaded(program)
            services.analytics.track(.programUnlocked(scanId: analysis.scanId))
            HapticManager.notification(.success)
        } catch let error as AppError {
            programState = .error(error)
            HapticManager.notification(.error)
        } catch {
            programState = .error(.unknown(underlying: error))
        }
    }
}
