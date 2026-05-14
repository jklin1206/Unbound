import SwiftUI
import AVFoundation

// MARK: - CameraView
//
// Post-onboarding scan surface — used by rescan / progress photo flows.
// Mirrors the onboarding Step_ScanLive experience:
//   - Live camera preview
//   - BodyAlignmentDetector + auto-snap with 3-second countdown
//   - Shared BodyAlignmentGuide so the frame is visually obvious
//   - Manual capture button still available as override
//
// Captures the current `viewModel.currentAngle` and advances through
// front/side/back in sequence via viewModel.capturePhoto(...).

struct CameraView: View {
    @ObservedObject var viewModel: BodyScanViewModel
    @EnvironmentObject var services: ServiceContainer
    @State private var showReview = false

    @State private var detector = BodyAlignmentDetector()
    @State private var isCapturing = false
    @State private var showsFlashOverlay = false
    @State private var useAutoSnap = true
    @State private var countdownSeconds: Int? = nil
    @State private var countdownTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            CameraPreviewView(service: services.imageCapture)
                .ignoresSafeArea()

            // Dimming scrim for overlay legibility
            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.55),
                    Color.clear,
                    Color.clear,
                    Color.unbound.bg.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Countdown display
            if let s = countdownSeconds {
                AutoSnapCountdown(seconds: s)
            }

            // Flash on capture
            if showsFlashOverlay {
                Color.white.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Chrome
            VStack {
                // Angle indicator
                angleIndicator
                    .padding(.top, 60)

                Spacer()

                AlignmentStatusChip(alignment: detector.alignment)

                autoSnapPill
                    .padding(.top, 10)

                captureButton
                    .padding(.top, 14)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .task {
            await startCamera()
        }
        .onDisappear {
            countdownTask?.cancel()
            countdownTask = nil
            countdownSeconds = nil
            services.imageCapture.attachVideoSampleHandler(nil)
            services.imageCapture.stopSession()
        }
        .onChange(of: detector.alignment) { _, new in
            handleAlignmentChange(new)
        }
        .fullScreenCover(isPresented: $showReview) {
            NavigationStack {
                PhotoReviewView(viewModel: viewModel)
                    .environmentObject(services)
            }
        }
    }

    // MARK: - Chrome

    private var angleIndicator: some View {
        Text("\(viewModel.currentAngle.order) of 3 · \(viewModel.currentAngle.rawValue.capitalized)")
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(2.0)
            .foregroundStyle(Color.unbound.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule().strokeBorder(Color.unbound.border.opacity(0.6), lineWidth: 1)
            )
    }

    private var autoSnapPill: some View {
        HStack(spacing: 0) {
            modeSegment(label: "Auto-snap", icon: "wand.and.stars", active: useAutoSnap) {
                useAutoSnap = true
            }
            modeSegment(label: "Manual", icon: "hand.tap.fill", active: !useAutoSnap) {
                useAutoSnap = false
                cancelCountdown()
            }
        }
        .padding(3)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color.unbound.border.opacity(0.6), lineWidth: 1))
        .opacity(countdownSeconds == nil ? 1 : 0)
    }

    @ViewBuilder
    private func modeSegment(label: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.medium()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { action() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(Font.unbound.bodyS)
            }
            .foregroundStyle(active ? Color.unbound.accent : Color.unbound.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(active ? Color.unbound.accent.opacity(0.18) : Color.clear))
            .overlay(Capsule().strokeBorder(active ? Color.unbound.accent : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var captureButton: some View {
        Button(action: primaryAction) {
            ZStack {
                Circle()
                    .strokeBorder(
                        countdownSeconds != nil ? Color.unbound.accent : Color.unbound.textPrimary,
                        lineWidth: 3
                    )
                    .frame(width: 84, height: 84)
                    .shadow(
                        color: countdownSeconds != nil ? Color.unbound.accent.opacity(0.6) : .clear,
                        radius: 12
                    )

                if countdownSeconds != nil {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(Color.unbound.accent))
                } else {
                    Circle()
                        .fill(Color.unbound.textPrimary)
                        .frame(width: 70, height: 70)
                        .scaleEffect(isCapturing ? 0.82 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isCapturing)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }

    private func primaryAction() {
        if countdownSeconds != nil {
            cancelCountdown()
        } else {
            startCountdown(from: 3)
        }
    }

    // MARK: - Camera lifecycle

    private func startCamera() async {
        let granted = await services.imageCapture.requestPermission()
        guard granted else { return }
        try? await services.imageCapture.startSession()
        services.imageCapture.attachVideoSampleHandler(detector)
    }

    // MARK: - Alignment → countdown

    private func handleAlignmentChange(_ new: BodyAlignment) {
        guard useAutoSnap else { return }
        if new == .aligned, countdownTask == nil, !isCapturing {
            startCountdown(from: 3)
        } else if new != .aligned, countdownTask != nil {
            cancelCountdown()
        }
    }

    private func startCountdown(from start: Int = 3) {
        guard countdownTask == nil, !isCapturing else { return }
        UnboundHaptics.heavy()
        countdownTask = Task {
            for sec in stride(from: start, through: 1, by: -1) {
                if Task.isCancelled { break }
                await MainActor.run {
                    countdownSeconds = sec
                    UnboundHaptics.tick()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if !Task.isCancelled {
                await MainActor.run {
                    countdownSeconds = nil
                    countdownTask = nil
                    capture()
                }
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownSeconds = nil
    }

    // MARK: - Capture

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        UnboundHaptics.heavy()

        withAnimation(.easeOut(duration: 0.12)) { showsFlashOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.24)) { showsFlashOverlay = false }
        }

        Task {
            do {
                let image = try await services.imageCapture.capturePhoto()
                await MainActor.run {
                    viewModel.capturePhoto(image, for: viewModel.currentAngle)
                    isCapturing = false
                    // Reset alignment for the next angle so auto-snap doesn't
                    // fire again instantly while the user repositions.
                    detector.reset()
                    if viewModel.allPhotosCaptured {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showReview = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                }
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let service: any ImageCaptureServiceProtocol

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        if let previewLayer = service.previewLayer as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = UIScreen.main.bounds
            view.layer.addSublayer(previewLayer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
