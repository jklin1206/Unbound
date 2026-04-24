import SwiftUI
import UIKit

// MARK: - PhotoCaptureFlow
//
// Presented as a fullScreenCover from Home / Profile. Enum-driven:
//
//   .photo — daily ritual. Tap → camera → review → confirm → save
//            ProgressPhoto(source: .manual) → +5 SP (deduped per day) →
//            dismiss with toast.
//
//   .scan  — bi-weekly Gemini body read. Consent gate (first time only)
//            → camera → review → confirm → analyzing cinematic (~1.2s,
//            during which ScanContextBuilder + BodyAnalysisService
//            .analyzeScan run concurrently) → ScanPayoffView → RETURN
//            HOME → +25 SP + ProgressPhoto(source: .scan).
//
// On scan failure: degrades silently to photo path (+5 SP) and does NOT
// advance the 14-day scan timer — user can retry immediately.

struct PhotoCaptureFlow: View {
    enum Mode: String, Identifiable, Equatable {
        case photo, scan
        var id: String { rawValue }
    }

    let mode: Mode
    let onComplete: (Outcome) -> Void

    enum Outcome: Equatable {
        case photoSaved
        case scanCompleted
        case scanDegradedToPhoto   // scan failed → saved as photo instead
        case cancelled
    }

    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismissSheet

    @State private var stage: Stage = .intro
    @State private var capturedImage: UIImage?
    @State private var analysis: BodyScanAnalysis?
    @State private var cameraPermissionGranted = false
    @State private var cameraSessionStarted = false
    @State private var analysisError: Error?
    @AppStorage("unbound.scanConsentGranted") private var scanConsentGranted: Bool = false

    private enum Stage {
        case intro
        case consent        // scan only, first time
        case camera
        case review
        case analyzing      // scan only
        case payoff         // scan only
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            switch stage {
            case .intro:     introView
            case .consent:   ScanConsentModal(onAccept: acceptConsent, onDecline: declineConsent)
            case .camera:    cameraView
            case .review:    reviewView
            case .analyzing: analyzingView
            case .payoff:    payoffView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stage)
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button {
                    UnboundHaptics.soft()
                    onComplete(.cancelled)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.unbound.surface))
                        .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }

            Spacer().frame(height: 12)

            Text(introLabel)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.accent)

            Text(introTitle)
                .font(Font.unbound.displayM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(introBody)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                UnboundHaptics.medium()
                advanceFromIntro()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(introCTA)
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private var introLabel: String {
        mode == .scan ? "BI-WEEKLY SCAN · +25 SP" : "DAILY PHOTO · +5 SP"
    }
    private var introTitle: String {
        mode == .scan ? "Lock in your body read." : "Lock in today's photo."
    }
    private var introBody: String {
        mode == .scan
            ? "A quick front photo. The coach reads it against your last two weeks of training and tells you what it sees. 3 sentences, no numbers."
            : "One photo. Keeps the arc honest. Come back in a month and see the change."
    }
    private var introCTA: String { "OPEN CAMERA" }

    private func advanceFromIntro() {
        if mode == .scan && !scanConsentGranted {
            stage = .consent
        } else {
            stage = .camera
        }
    }

    // MARK: - Consent

    private func acceptConsent() {
        scanConsentGranted = true
        stage = .camera
    }
    private func declineConsent() {
        onComplete(.cancelled)
    }

    // MARK: - Camera

    private var cameraView: some View {
        ZStack {
            ScanCameraPreview(service: services.imageCapture)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        UnboundHaptics.soft()
                        tearDownCamera()
                        onComplete(.cancelled)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(mode == .scan ? "SCAN" : "PHOTO")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                    Spacer().frame(width: 38)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                Button {
                    capture()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(Color.unbound.accent)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.unbound.accent.opacity(0.55), radius: 10)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 38)
            }
        }
        .task {
            guard !cameraSessionStarted else { return }
            cameraPermissionGranted = await services.imageCapture.requestPermission()
            guard cameraPermissionGranted else {
                onComplete(.cancelled)
                return
            }
            do {
                try await services.imageCapture.startSession()
                cameraSessionStarted = true
            } catch {
                onComplete(.cancelled)
            }
        }
    }

    private func capture() {
        UnboundHaptics.medium()
        Task {
            do {
                let image = try await services.imageCapture.capturePhoto()
                capturedImage = image
                tearDownCamera()
                stage = .review
            } catch {
                // Camera failure — bail out.
                tearDownCamera()
                onComplete(.cancelled)
            }
        }
    }

    private func tearDownCamera() {
        services.imageCapture.stopSession()
        cameraSessionStarted = false
    }

    // MARK: - Review

    @ViewBuilder
    private var reviewView: some View {
        if let img = capturedImage {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        UnboundHaptics.soft()
                        capturedImage = nil
                        stage = .camera
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .bold))
                            Text("RETAKE")
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(Color.unbound.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.unbound.surface))
                        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 460)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.unbound.accent.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: Color.unbound.accent.opacity(0.3), radius: 18)
                    .padding(.horizontal, 20)

                Spacer()

                Button {
                    UnboundHaptics.medium()
                    confirm()
                } label: {
                    HStack(spacing: 10) {
                        Text(mode == .scan ? "ANALYZE" : "LOCK IT IN")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.accent)
                    )
                    .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        } else {
            ProgressView().tint(Color.unbound.accent)
        }
    }

    private func confirm() {
        switch mode {
        case .photo:
            Task { await savePhoto(); onComplete(.photoSaved) }
        case .scan:
            stage = .analyzing
            Task { await runScan() }
        }
    }

    // MARK: - Analyzing

    @State private var analyzingPhase: CGFloat = 0
    private var analyzingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .strokeBorder(Color.unbound.accent.opacity(0.25), lineWidth: 2)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.unbound.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(analyzingPhase))
                    .shadow(color: Color.unbound.accent.opacity(0.55), radius: 8)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    analyzingPhase = 360
                }
            }
            Text("READING BODY")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.accent)
            Text("The coach is checking your photo against the last two weeks of training.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Payoff

    @ViewBuilder
    private var payoffView: some View {
        if let img = capturedImage, let a = analysis {
            ScanPayoffView(image: img, analysis: a) {
                onComplete(.scanCompleted)
            }
        } else {
            ProgressView().tint(Color.unbound.accent)
        }
    }

    // MARK: - Flow logic

    @MainActor
    private func savePhoto() async {
        guard let image = capturedImage else { return }
        let userId = services.auth.currentUserId ?? "anonymous"
        let photoId = savePhotoToDatabase(image: image, userId: userId, source: .manual)
        _ = services.photoXP.awardDailyPhoto(userId: userId)
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: "unbound.lastPhotoTimestamp"
        )
        services.badges.bind(userId: userId)
        _ = await services.badges.evaluate(trigger: .photoCaptured)
        NotificationCenter.default.post(name: .photoCaptured, object: nil, userInfo: ["photoId": photoId])
    }

    @MainActor
    private func runScan() async {
        guard let image = capturedImage else { return }
        let userId = services.auth.currentUserId ?? "anonymous"

        guard let ctx = await ScanContextBuilder.shared.build(userId: userId, currentImage: image) else {
            await degradeToPhoto()
            return
        }

        // Save the photo FIRST — even if Gemini fails, the user's photo is
        // in the library. Scan ID is the photo ID.
        let photoId = savePhotoToDatabase(image: image, userId: userId, source: .scan)

        do {
            let result = try await services.bodyAnalysis.analyzeScan(
                context: ctx,
                userId: userId,
                photoId: photoId
            )
            analysis = result
            services.photoXP.awardScan(userId: userId)
            UserDefaults.standard.set(
                Date().timeIntervalSince1970,
                forKey: "unbound.lastScanTimestamp"
            )
            services.badges.bind(userId: userId)
            _ = await services.badges.evaluate(trigger: .scanCompleted)
            NotificationCenter.default.post(
                name: .scanCompleted,
                object: nil,
                userInfo: ["photoId": photoId, "analysisId": result.id]
            )
            stage = .payoff
        } catch {
            analysisError = error
            await degradeToPhoto()
        }
    }

    /// Scan failed or context couldn't be built. Treat as a photo instead:
    /// award the daily +5 SP, do NOT advance the 14-day scan timer.
    @MainActor
    private func degradeToPhoto() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        _ = services.photoXP.awardDailyPhoto(userId: userId)
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: "unbound.lastPhotoTimestamp"
        )
        onComplete(.scanDegradedToPhoto)
    }

    /// Persist a `ProgressPhoto` row. Returns the new id. For now the
    /// storage URL is a local Documents path — Supabase Storage upload
    /// lands in task #44.
    @MainActor
    private func savePhotoToDatabase(image: UIImage, userId: String, source: ProgressPhoto.Source) -> String {
        let id = UUID().uuidString
        let jpeg = image.jpegData(compressionQuality: 0.85)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        var storedPath = "local://\(id)"
        if let jpeg, let docs {
            let fileURL = docs.appendingPathComponent("progress_\(id).jpg")
            try? jpeg.write(to: fileURL, options: [.atomic])
            storedPath = fileURL.path
        }
        let photo = ProgressPhoto(
            id: id,
            userId: userId,
            storageUrl: storedPath,
            capturedAt: Date(),
            note: nil,
            angle: .front,
            blockNumber: nil,
            source: source
        )
        Task {
            try? await services.database.create(photo, collection: "progressPhotos", documentId: id)
        }
        return id
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let photoCaptured = Notification.Name("unbound.photoCaptured")
    static let scanCompleted = Notification.Name("unbound.scanCompleted")
}
