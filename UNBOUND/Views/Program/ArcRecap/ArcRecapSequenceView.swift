import SwiftUI

// MARK: - ArcRecapSequenceView
//
// The end-of-Arc ceremony: mark the moment with a before/after photo, see
// what the block built (hex shift + stats), read its best work, answer the
// System's difficulty calibration, then watch it write the next Arc.
// Full-screen cover presented from the block-complete surface; mirrors the
// post-workout reward sequence's visual language.

/// What the optional "Adjust setup" sheet needs to present from inside the
/// recap cover (the Overview's own sheet would present underneath it).
struct ArcRecapFocusContext {
    let style: TrainingStyle
    let equipment: [Equipment]
    let experience: Experience?
    let pendingContext: ProgramTrainingContextOverride?
}

struct ArcRecapSequenceView: View {
    let summary: ArcRecapSummary
    let focusContext: ArcRecapFocusContext?
    /// Fired once when the final "writing" beat appears; the parent runs the
    /// rollover build and dismisses this cover when the new Arc lands.
    let onGenerateNextBlock: () -> Void

    enum Beat: Int, CaseIterable {
        case photo
        case build
        case highlights
        case nextArc
        case building
    }

    @State private var beatIndex = 0
    @State private var showPhotoCapture = false
    @State private var photoTaken = false
    @State private var hasRequestedBuild = false
    @State private var escalateNextArc = false
    @State private var focusSwitchPresentation: ProgramFocusSwitchPresentation?

    /// The next rung of the difficulty ladder, when one exists. Raising it is
    /// the System's offer at the block boundary — the answer to "how does a
    /// beginner ever stop getting the easy stuff."
    private var raisedExperience: Experience? {
        switch focusContext?.experience {
        case .never: return .tried
        case .tried: return .used
        case .used, .current, .none: return nil
        }
    }

    private var beats: [Beat] {
        var list: [Beat] = [.photo, .build]
        if !summary.highlights.isEmpty {
            list.append(.highlights)
        }
        list.append(contentsOf: [.nextArc, .building])
        return list
    }

    private var currentBeat: Beat { beats[min(beatIndex, beats.count - 1)] }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                progressRail
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                Group {
                    switch currentBeat {
                    case .photo:
                        ArcRecapPhotoBeat(
                            summary: summary,
                            photoTaken: photoTaken,
                            onAddPhoto: { showPhotoCapture = true }
                        )
                    case .build:
                        ArcRecapBuildBeat(summary: summary)
                    case .highlights:
                        ArcRecapHighlightsBeat(summary: summary)
                    case .nextArc:
                        ArcRecapSystemCalibrationBeat(
                            summary: summary,
                            raisedExperience: raisedExperience,
                            escalate: $escalateNextArc,
                            canAdjustSetup: focusContext != nil,
                            onAdjustSetup: presentFocusSwitch
                        )
                    case .building:
                        ArcRecapBuildingBeat(nextBlockNumber: summary.nextArcNumber)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentBeat)

                bottomActions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .interactiveDismissDisabled(true)
        .fullScreenCover(isPresented: $showPhotoCapture) {
            PhotoCaptureFlow(mode: .photo, onComplete: { outcome in
                showPhotoCapture = false
                if case .photoSaved = outcome {
                    photoTaken = true
                }
            })
        }
        .sheet(item: $focusSwitchPresentation) { presentation in
            ProgramFocusSwitchSheet(
                currentStyle: presentation.currentStyle,
                currentEquipment: presentation.currentEquipment,
                currentExperience: presentation.currentExperience,
                activeContext: presentation.activeContext,
                pendingContext: presentation.pendingContext,
                isApplying: false,
                errorMessage: nil,
                onClear: { target in
                    if case .pendingNextBlock = target {
                        ProgramTrainingContextStore.shared.clearPendingNextBlockContext(
                            userId: summary.userId,
                            programId: summary.programId
                        )
                    }
                    focusSwitchPresentation = nil
                },
                onApply: { selection in
                    // Everything chosen here lands on the NEXT Arc — the one
                    // the build about to run.
                    ProgramTrainingContextStore.shared.savePendingNextBlockContext(
                        selection: selection.contextSelection,
                        userId: summary.userId,
                        programId: summary.programId
                    )
                    UnboundHaptics.success()
                    focusSwitchPresentation = nil
                }
            )
        }
        .onChange(of: currentBeat) { _, beat in
            guard beat == .building, !hasRequestedBuild else { return }
            hasRequestedBuild = true
            if escalateNextArc, let raisedExperience {
                // Queue the difficulty raise for the Arc about to be written;
                // `.automatic` keeps style and equipment as they are.
                ProgramTrainingContextStore.shared.savePendingNextBlockContext(
                    selection: ProgramTrainingContextSelection(
                        scope: .nextBlock,
                        mode: .automatic,
                        equipment: [],
                        experience: raisedExperience
                    ),
                    userId: summary.userId,
                    programId: summary.programId
                )
            }
            onGenerateNextBlock()
        }
        #if DEBUG
        .task {
            // `--unbound-arc-recap-autoplay`: hands-free beat driver for
            // on-sim review recordings, mirroring the reward sequence's demo.
            guard ProcessInfo.processInfo.arguments.contains("--unbound-arc-recap-autoplay") else {
                return
            }
            try? await Task.sleep(for: .seconds(4))
            while currentBeat != .building {
                advance()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        #endif
    }

    // MARK: - Chrome

    private var backdrop: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Dedicated centered sigil-ring art, dimmed behind a scrim so the
            // beats' text and cards stay readable over the bright filigree —
            // same treatment the reward sequence gives its void backdrop.
            GeometryReader { proxy in
                Image("arc_recap_backdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(0.55)
            }
            .ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.25), Color.black.opacity(0.45), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var progressRail: some View {
        HStack(spacing: 6) {
            ForEach(Array(beats.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(index == beatIndex ? Color.rewardBlue : Color.white.opacity(0.18))
                    .frame(width: index == beatIndex ? 26 : 12, height: 4)
            }
            Spacer()
            Text("ARC \(summary.blockNumber)")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        switch currentBeat {
        case .photo:
            VStack(spacing: 10) {
                primaryButton(photoTaken ? "CONTINUE" : "ADD PHOTO") {
                    if photoTaken {
                        advance()
                    } else {
                        showPhotoCapture = true
                    }
                }
                if !photoTaken {
                    Button {
                        advance()
                    } label: {
                        Text("Skip")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .build, .highlights:
            primaryButton("CONTINUE") { advance() }
        case .nextArc:
            primaryButton("BEGIN ARC \(summary.nextArcNumber)") { advance() }
        case .building:
            EmptyView()
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.soft()
            action()
        } label: {
            Text(title)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.rewardBlue)
                )
        }
        .buttonStyle(.plain)
    }

    private func presentFocusSwitch() {
        guard let focusContext else { return }
        UnboundHaptics.soft()
        focusSwitchPresentation = ProgramFocusSwitchPresentation(
            currentStyle: focusContext.style,
            currentEquipment: focusContext.equipment,
            currentExperience: focusContext.experience,
            activeContext: nil,
            pendingContext: focusContext.pendingContext
        )
    }

    private func advance() {
        guard beatIndex < beats.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            beatIndex += 1
        }
    }
}
