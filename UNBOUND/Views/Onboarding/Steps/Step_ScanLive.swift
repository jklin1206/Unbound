import SwiftUI
import AVFoundation

// MARK: - Step_ScanLive
//
// Front-camera live preview for the onboarding scan step.
// Friction-free: open camera → see preview → tap shutter → done.
// No alignment gating, no auto-snap, no gesture detection.

struct Step_ScanLive: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onCaptured: () -> Void

    @EnvironmentObject var services: ServiceContainer

    // Local state
    @State private var sessionStatus: SessionStatus = .starting
    @State private var isCapturing = false
    @State private var showsFlashOverlay = false

    private enum SessionStatus: Equatable {
        case starting
        case running
        case denied
        case unavailable
    }

    var body: some View {
        ZStack {
            // Camera or fallback
            if sessionStatus == .running {
                ScanCameraPreview(service: services.imageCapture)
                    .ignoresSafeArea()
            } else {
                fallbackBackground
            }

            // Dimming scrim — keeps overlays legible against bright backgrounds
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

            // Flash on capture
            if showsFlashOverlay {
                Color.white.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Chrome
            VStack(spacing: 0) {
                topChrome
                Spacer()

                if sessionStatus == .running {
                    instructionBlock
                    captureButton
                        .padding(.top, 20)
                        .padding(.bottom, 36)
                } else {
                    fallbackPanel
                        .padding(.bottom, 48)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await startCamera()
        }
        .onDisappear {
            services.imageCapture.stopSession()
        }
    }

    // MARK: - Camera lifecycle

    private func startCamera() async {
        let granted = await services.imageCapture.requestPermission()
        guard granted else {
            sessionStatus = .denied
            return
        }
        do {
            try await services.imageCapture.startSession()
            sessionStatus = .running
        } catch {
            sessionStatus = .unavailable
        }
    }

    private func retryCamera() async {
        sessionStatus = .starting
        await startCamera()
    }

    // MARK: - Top chrome — back + progress

    private var topChrome: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)

            OnboardingProgressBar(progress: progress)

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Instruction block

    private var instructionBlock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("STAYS ON YOUR DEVICE")
                    .font(Font.unbound.captionS)
                    .tracking(1.6)
            }
            .foregroundStyle(Color.unbound.accent)

            Text("Fill the frame. Tap to snap.")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 18)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.unbound.bg.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Capture button

    private var captureButton: some View {
        Button(action: capture) {
            ZStack {
                Circle()
                    .strokeBorder(Color.unbound.textPrimary, lineWidth: 3)
                    .frame(width: 84, height: 84)

                Circle()
                    .fill(Color.unbound.textPrimary)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isCapturing ? 0.82 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isCapturing)
            }
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }

    // MARK: - Capture

    #if targetEnvironment(simulator)
    private func skipForSimulator() {
        UnboundHaptics.medium()
        let size = CGSize(width: 512, height: 768)
        let renderer = UIGraphicsImageRenderer(size: size)
        let placeholder = renderer.image { ctx in
            UIColor(Color.unbound.surface).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        flow.capturedPhotos[.front] = placeholder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onCaptured()
        }
    }
    #endif

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
                    flow.capturedPhotos[.front] = image
                    isCapturing = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onCaptured()
                    }
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                    sessionStatus = .unavailable
                }
            }
        }
    }

    // MARK: - Fallback (camera denied / unavailable / starting)

    private var fallbackBackground: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Color.unbound.accent.opacity(0.18), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var fallbackPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: fallbackIcon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.unbound.accent)

            Text(fallbackTitle)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)

            Text(fallbackBody)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            if sessionStatus != .starting {
                Button(action: { Task { await retryCamera() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Retry camera")
                            .font(Font.unbound.bodyMStrong)
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.unbound.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }

            #if targetEnvironment(simulator)
            Button(action: skipForSimulator) {
                HStack(spacing: 6) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Skip (dev · simulator)")
                        .font(Font.unbound.monoS)
                        .tracking(1.2)
                }
                .foregroundStyle(Color.unbound.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            #endif
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var fallbackIcon: String {
        switch sessionStatus {
        case .starting:    return "camera.viewfinder"
        case .denied:      return "lock.shield"
        case .unavailable: return "video.slash"
        case .running:     return "camera.fill"
        }
    }

    private var fallbackTitle: String {
        switch sessionStatus {
        case .starting:    return "Starting camera…"
        case .denied:      return "Camera access blocked"
        case .unavailable: return "Camera unavailable"
        case .running:     return ""
        }
    }

    private var fallbackBody: String {
        switch sessionStatus {
        case .starting:
            return "One sec — bringing up the front camera."
        case .denied:
            return "Open Settings → UNBOUND → Camera and turn it on. Then come back and retry."
        case .unavailable:
            #if targetEnvironment(simulator)
            return "Camera isn't available in the simulator. Build to a device to run the live scan."
            #else
            return "We couldn't reach your camera. Try again in a moment."
            #endif
        case .running:
            return ""
        }
    }
}
