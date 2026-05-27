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

    private var isPreviewMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-ScanLivePreview")
    }

    var body: some View {
        ZStack {
            // Camera or fallback
            if sessionStatus == .running && isPreviewMode {
                previewEntryBackground
            } else if sessionStatus == .running {
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
                entryHeader
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
        if isPreviewMode {
            sessionStatus = .running
            return
        }

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

    // MARK: - Entry header

    private var entryHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 10, weight: .black))
                Text(L10n.onboarding("scanLive.entry.eyebrow", defaultValue: "DAY ZERO ENTRY"))
                    .font(Font.unbound.monoS)
                    .tracking(2.0)
            }
            .foregroundStyle(Color.unbound.accent)

            Text(L10n.onboarding("scanLive.entry.title", defaultValue: "Step into Day Zero"))
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.84)

            Text(L10n.onboarding("scanLive.entry.subtitle", defaultValue: "One frame now. Proof in 30 days."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.82),
                    Color.unbound.bg.opacity(0.46),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private var previewEntryBackground: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            AnimeBackdrop(variant: .godRay, intensity: 0.84)
                .ignoresSafeArea()

            TechGridBackground(opacity: 0.14)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer().frame(height: 214)

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.unbound.accent.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 238, height: 372)
                        .shadow(color: Color.unbound.accent.opacity(0.2), radius: 22)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                        .frame(width: 238, height: 372)

                    SilhouetteView(
                        rimLight: .impact,
                        chromaticAberration: 0.24,
                        breathe: true,
                        scale: 0.68,
                        asset: .dormant
                    )
                    .frame(width: 190, height: 330)
                    .opacity(0.82)

                    VStack {
                        HStack {
                            cornerMark(rotation: 0)
                            Spacer()
                            cornerMark(rotation: 90)
                        }
                        Spacer()
                        HStack {
                            cornerMark(rotation: 270)
                            Spacer()
                            cornerMark(rotation: 180)
                        }
                    }
                    .frame(width: 222, height: 356)
                }

                Spacer()
            }
        }
    }

    private func cornerMark(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 22))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 22, y: 0))
        }
        .stroke(Color.unbound.accent.opacity(0.82), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        .frame(width: 22, height: 22)
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - Instruction block

    private var instructionBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(L10n.onboarding("scanLive.instruction.eyebrow", defaultValue: "MONTH ONE STARTS HERE"))
                    .font(Font.unbound.captionS)
                    .tracking(1.6)
            }
            .foregroundStyle(Color.unbound.accent)

            Text(L10n.onboarding("scanLive.instruction.title", defaultValue: "Set the before."))
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n.onboarding("scanLive.instruction.subtitle", defaultValue: "This is the first page of the climb."))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.unbound.accent.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: Color.unbound.accent.opacity(0.16), radius: 18)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var captureButton: some View {
        VStack(spacing: 12) {
            Button(action: capture) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.unbound.accent.opacity(0.5), lineWidth: 2)
                        .frame(width: 104, height: 104)
                        .shadow(color: Color.unbound.accent.opacity(0.42), radius: 18)

                    Circle()
                        .strokeBorder(Color.unbound.textPrimary.opacity(0.88), lineWidth: 3)
                        .frame(width: 84, height: 84)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.unbound.textPrimary,
                                    Color.unbound.accent.opacity(0.9)
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 40
                            )
                        )
                        .frame(width: 68, height: 68)
                        .scaleEffect(isCapturing ? 0.82 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isCapturing)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.unbound.bg.opacity(0.82))
                }
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)

            Text(L10n.onboarding("scanLive.capture", defaultValue: "BEGIN"))
                .font(Font.unbound.monoS)
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textPrimary)
        }
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
                        Text(L10n.onboarding("scanLive.retryCamera", defaultValue: "Retry camera"))
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
                    Text(L10n.onboarding("scanLive.skipSimulator", defaultValue: "Skip (dev · simulator)"))
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
        case .starting:    return L10n.onboarding("scanLive.fallback.starting.title", defaultValue: "Starting camera…")
        case .denied:      return L10n.onboarding("scanLive.fallback.denied.title", defaultValue: "Camera access blocked")
        case .unavailable: return L10n.onboarding("scanLive.fallback.unavailable.title", defaultValue: "Camera unavailable")
        case .running:     return ""
        }
    }

    private var fallbackBody: String {
        switch sessionStatus {
        case .starting:
            return L10n.onboarding("scanLive.fallback.starting.body", defaultValue: "One sec — bringing up the front camera.")
        case .denied:
            return L10n.onboarding("scanLive.fallback.denied.body", defaultValue: "Open Settings → UNBOUND → Camera and turn it on. Then come back and retry.")
        case .unavailable:
            #if targetEnvironment(simulator)
            return L10n.onboarding("scanLive.fallback.unavailable.simulatorBody", defaultValue: "Camera isn't available in the simulator. Build to a device to run the live scan.")
            #else
            return L10n.onboarding("scanLive.fallback.unavailable.body", defaultValue: "We couldn't reach your camera. Try again in a moment.")
            #endif
        case .running:
            return ""
        }
    }
}
