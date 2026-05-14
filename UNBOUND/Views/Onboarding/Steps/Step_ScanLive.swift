import SwiftUI
import AVFoundation

// MARK: - Step_ScanLive
//
// Front-camera live preview + silhouette guide + auto-snap on alignment.
// Replaces the old Step30_ScanPrep + Step_ScanCapture split — instructions
// live ON the live preview so the user lines themselves up while reading.
//
// Auto-snap fires when `BodyAlignmentDetector` reports `.aligned` for ~1s.
// Manual capture button is still present for users who want to override.
// No skip button — if the camera fails (e.g. simulator), the fallback shows
// a retry instead.

struct Step_ScanLive: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onCaptured: () -> Void

    @EnvironmentObject var services: ServiceContainer

    // Local state
    @State private var detector = BodyAlignmentDetector()
    @State private var sessionStatus: SessionStatus = .starting
    @State private var isCapturing = false
    @State private var showsFlashOverlay = false
    @State private var useWaveSnap: Bool = true
    @State private var countdownSeconds: Int? = nil
    @State private var countdownTask: Task<Void, Never>? = nil

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

            // Countdown overlay — big number when auto-snap is firing
            if let s = countdownSeconds {
                countdownDisplay(seconds: s)
            }

            // Flash flash on capture
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
                    captureModePill
                    captureButton
                        .padding(.top, 12)
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
            countdownTask?.cancel()
            countdownTask = nil
            countdownSeconds = nil
            services.imageCapture.attachVideoSampleHandler(nil)
            services.imageCapture.stopSession()
        }
        .onChange(of: detector.alignment) { _, new in
            handleAlignmentChange(new)
        }
        .onChange(of: detector.gestureDetected) { _, detected in
            guard detected, useWaveSnap, sessionStatus == .running else {
                if detected { detector.resetGesture() }
                return
            }
            guard countdownTask == nil, !isCapturing else { return }
            startCountdown(from: 3)
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
            services.imageCapture.attachVideoSampleHandler(detector)
            sessionStatus = .running
        } catch {
            sessionStatus = .unavailable
        }
    }

    private func retryCamera() async {
        sessionStatus = .starting
        detector.reset()
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

            Text(useWaveSnap ? "Fill the frame. Raise your hand." : "Fill the frame. Tap to snap.")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.7), radius: 6)
                Text(detector.alignment.statusLabel)
                    .font(Font.unbound.monoS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .contentTransition(.identity)
            }
            .padding(.top, 4)
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

    private var statusColor: Color {
        switch detector.alignment {
        case .noBody, .outOfFrame: return Color.unbound.textTertiary
        case .closeToAligned:      return Color.unbound.accent
        case .aligned:             return Color.unbound.success
        }
    }

    // MARK: - Snap mode toggle

    private var captureModePill: some View {
        HStack(spacing: 0) {
            modeSegment(label: "Wave", icon: "hand.wave.fill", active: useWaveSnap) {
                useWaveSnap = true
                detector.resetGesture()
            }
            modeSegment(label: "Manual", icon: "hand.tap.fill", active: !useWaveSnap) {
                useWaveSnap = false
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
        Button(action: {
            UnboundHaptics.medium()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                action()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(Font.unbound.bodyS)
            }
            .foregroundStyle(active ? Color.unbound.accent : Color.unbound.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(active ? Color.unbound.accent.opacity(0.18) : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(active ? Color.unbound.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Capture button (manual override always available)

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
                        radius: 12, x: 0, y: 0
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
            // Manual override always available, even in auto-snap mode.
            startCountdown(from: 3)
        }
    }

    // MARK: - Countdown

    private func countdownDisplay(seconds: Int) -> some View {
        Text("\(seconds)")
            .font(.system(size: 220, weight: .black, design: .default))
            .foregroundStyle(Color.unbound.textPrimary)
            .shadow(color: Color.unbound.accent.opacity(0.6), radius: 30, x: 0, y: 0)
            .contentTransition(.numericText(value: Double(seconds)))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: seconds)
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
        detector.resetGesture()
        UnboundHaptics.medium()
    }

    // MARK: - Alignment change

    private func handleAlignmentChange(_ new: BodyAlignment) {
        guard countdownTask != nil else { return }
        // Cancel an in-progress countdown only if the body fully leaves frame.
        if case .noBody = new { cancelCountdown() }
    }

    // MARK: - Capture

    #if targetEnvironment(simulator)
    private func skipForSimulator() {
        UnboundHaptics.medium()
        // Seed a placeholder UIImage so downstream (review/verdict) has a non-nil photo to render.
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
        detector.resetGesture()
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

// MARK: - SilhouetteGuide retired
// Moved to Views/Components/Unbound/BodyAlignmentGuide.swift and renamed.
// This file now only references the shared component.
