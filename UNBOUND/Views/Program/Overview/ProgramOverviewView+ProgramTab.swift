import SwiftUI

extension ProgramOverviewView {
    // MARK: - DAILY tab

    @ViewBuilder
    var programTab: some View {
        let surfaceState = ProgramSurfaceState.resolve(
            state: viewModel.state,
            selectedDate: selectedDayDate,
            now: programNow
        )
        Group {
            switch surfaceState.kind {
            case .noProgram:
                ProgramNoProgramState()
            case .loading:
                ProgramLoadingStateView()
            case .loadError:
                ProgramErrorStateView(error: viewModel.state.errorValue, onRetry: reloadProgramSurface)
            case .blockComplete:
                if let program = viewModel.state.value {
                    blockCompleteState(program: program)
                } else {
                    ProgramErrorStateView(error: nil, onRetry: reloadProgramSurface)
                }
            case .restDay, .trainingDay, .missingDay:
                if let program = viewModel.state.value {
                    programBody(program)
                } else {
                    ProgramNoProgramState()
                }
            }
        }
        // Attached above the surface switch so the cover survives the flip to
        // the new Arc underneath; dismissal is state-driven after the build.
        .fullScreenCover(item: $arcRecapSummary) { summary in
            ArcRecapSequenceView(
                summary: summary,
                focusContext: arcRecapFocusContext()
            ) {
                runArcRecapBuild()
            }
        }
    }

    // MARK: - Block-complete state
    //
    // Surfaces when the current Arc (Arc.durationDays) has elapsed. The tab
    // keeps its normal chrome (week strip, dock, coach chips); only the
    // day-card slot swaps to the compact block-complete card, since the next
    // block builds itself and this is a beat, not a destination.

    @ViewBuilder
    func blockCompleteState(program: TrainingProgram) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            // AnyView-wrapped for the same metadata-depth reason as
            // programBody — see the comment there before "simplifying".
            VStack(alignment: .leading, spacing: 16) {
                #if DEBUG
                if !ProcessInfo.processInfo.arguments.contains("--unbound-appstore-demo") {
                    AnyView(devDaySimulatorCard)
                    AnyView(devDynamicScenarioRail)
                }
                #endif
                AnyView(weekStrip(program: program))
                AnyView(blockCompleteCard(program: program))
                AnyView(programBelowDayTools(program: program))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .task {
            await loadBlockRolloverContext(program: program)
            await presentArcRecapIfNeeded(program: program)
        }
    }

    /// The block-complete beat opens with the Arc recap sequence (photo →
    /// build → highlights → next arc), whose final beat drives the build.
    /// Falls back to the silent auto-build when the recap can't be assembled.
    func presentArcRecapIfNeeded(program: TrainingProgram) async {
        guard !hasPresentedArcRecap, !isGeneratingNextBlock else { return }
        hasPresentedArcRecap = true

        guard let userId = services.auth.currentUserId,
              let summary = await ArcRecapBuilder.build(
                userId: userId,
                program: program,
                database: services.database
              ) else {
            await autoBuildNextBlockIfNeeded(program: program)
            return
        }
        arcRecapSummary = summary
    }

    /// Context for the recap's optional "Adjust setup" sheet — the same
    /// sources the command dock's Setup tile resolves from.
    func arcRecapFocusContext() -> ArcRecapFocusContext? {
        guard let program = viewModel.program else { return nil }
        return ArcRecapFocusContext(
            style: effectiveTrainingStyle(),
            equipment: currentEquipmentFallback(program: program),
            experience: viewModel.currentProfile?.experience,
            pendingContext: pendingNextBlockContext(program: program)
        )
    }

    /// Fired by the recap's final "writing" beat: run the rollover build and
    /// dismiss the recap once the next Arc lands (or after the bounded retry
    /// fails, so the compact card's manual CONTINUE takes over).
    func runArcRecapBuild() {
        guard let program = viewModel.program, !isGeneratingNextBlock else {
            arcRecapSummary = nil
            return
        }
        isGeneratingNextBlock = true
        let vm = viewModel
        Task {
            // The writing beat is a ceremony, not a loading state: hold it for
            // a couple of seconds even when generation returns instantly, so
            // the hand-off into the new Arc lands instead of flashing.
            let minimumDwell: TimeInterval = 2.5
            let start = Date()
            await runGenerateNextBlock(currentProgram: program, alreadyMarkedGenerating: true)
            if vm.program?.id == program.id {
                try? await Task.sleep(for: .seconds(2))
                await runGenerateNextBlock(currentProgram: program)
            }
            let remaining = minimumDwell - Date().timeIntervalSince(start)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            await MainActor.run { arcRecapSummary = nil }
        }
    }

    private func blockCompleteCard(program: TrainingProgram) -> some View {
        // Calibration Week is the only 7-day period; every block is Arc.durationDays.
        // Duration distinguishes the one-time calibration→first-block rollover, which
        // gets its own "Calibration complete → your first 30" copy.
        let isCalibrationComplete = program.durationDays <= DeterministicProgramGenerator.calibrationDurationDays

        return ProgramBlockCompleteView(
            trainedDays: trainedDayCount(in: program),
            totalDays: program.durationDays,
            isCalibrationComplete: isCalibrationComplete,
            isGeneratingNextBlock: isGeneratingNextBlock,
            onBuildNextBlock: {
                UnboundHaptics.soft()
                Task { await runGenerateNextBlock(currentProgram: program) }
            }
        )
    }

    // MARK: - Block-complete data + actions

    /// Pull block number + latest delta report so the CTA + teaser are
    /// populated when the block-complete card first appears.
    func loadBlockRolloverContext(program: TrainingProgram) async {
        guard let userId = services.auth.currentUserId else { return }
        let context = await ProgramBlockRolloverCoordinator.loadContext(
            userId: userId,
            database: services.database
        )

        await MainActor.run {
            self.currentBlockNumberPreview = context.currentBlock
            self.nextBlockNumberPreview = context.nextBlock
            self.rolloverDeltaReport = context.deltaReport
            self.rolloverProposal = context.proposal
        }
    }

    /// Auto-build: the current block (Calibration Week or an Arc) has elapsed, so
    /// build the next Arc automatically instead of dead-ending on a manual "Build
    /// Next Arc" tap. Marks the building state immediately so the card reads as a
    /// transition, holds briefly so the "complete" beat registers, then generates.
    /// Fires once per block-complete; a manual tap or an in-flight build pre-empts it.
    func autoBuildNextBlockIfNeeded(program: TrainingProgram) async {
        guard !hasAutoTriggeredRollover, !isGeneratingNextBlock else { return }
        hasAutoTriggeredRollover = true
        isGeneratingNextBlock = true
        try? await Task.sleep(for: .seconds(1.4))
        // Run the build in an UNSTRUCTURED task, never in this view-bound
        // .task: runGenerateNextBlock flips the surface away from
        // .blockComplete, which tears down this view and cancels its .task —
        // awaiting the build here cancelled the build itself mid-flight
        // (fetchProfile threw CancellationError, the catch silently restored
        // the finished block, and hasAutoTriggeredRollover blocked a retry).
        // The manual CONTINUE button already builds from a Task {}; this
        // matches it.
        let vm = viewModel
        Task {
            await runGenerateNextBlock(currentProgram: program, alreadyMarkedGenerating: true)
            // The build can fail transiently (remote profile/log fetches);
            // the failure is silent by design, so give the auto path ONE
            // bounded retry before falling back to the manual CONTINUE.
            // Unchanged program id == the first attempt didn't land.
            if vm.program?.id == program.id {
                try? await Task.sleep(for: .seconds(2))
                await runGenerateNextBlock(currentProgram: program)
            }
        }
    }

    /// Drives the BUILD ARC N CTA: spinner → generate → swap state to the
    /// new program. Failures restore the loaded state silently so the user
    /// can retry; production telemetry catches the failure path. `alreadyMarkedGenerating`
    /// is set by the auto-build path, which has already flipped `isGeneratingNextBlock`.
    func runGenerateNextBlock(
        currentProgram: TrainingProgram,
        alreadyMarkedGenerating: Bool = false
    ) async {
        guard let userId = services.auth.currentUserId else { return }
        if !alreadyMarkedGenerating, isGeneratingNextBlock { return }
        let vm = viewModel

        // The block-complete card's inline spinner carries the build — the
        // surface stays put (no full-screen loading flash) until the new
        // program lands and swaps it in place.
        isGeneratingNextBlock = true

        do {
            let profile = try await services.user.fetchProfile(userId: userId)
            let newProgram = try await ProgramBlockRolloverCoordinator.generateNextBlock(
                userId: userId,
                profile: profile,
                currentBlockNumber: currentBlockNumberPreview,
                proposal: rolloverProposal,
                deltaReport: rolloverDeltaReport
            )
            vm.program = newProgram
            vm.state = .loaded(newProgram)
            await vm.loadTrackingData()
        } catch {
            services.logging.log(
                "BlockRolloverService.performRollover failed: \(error)",
                level: .error,
                context: ["currentProgramId": currentProgram.id]
            )
            #if DEBUG
            // os_log is unreadable from `simctl spawn log show` in practice;
            // this breadcrumb makes a silent rollover failure diagnosable
            // on-sim via `defaults read com.unboundapp.ios unbound.debug.lastRolloverError`.
            UserDefaults.standard.set(
                "\(Date()): \(error)",
                forKey: "unbound.debug.lastRolloverError"
            )
            #endif
            // A transient failure must not burn the one-shot auto-build for
            // the whole session: the next time the block-complete card
            // appears, the auto attempt runs again (each retry needs a fresh
            // card appearance, so this cannot tight-loop). CONTINUE remains
            // the always-available manual path.
            hasAutoTriggeredRollover = false
        }

        isGeneratingNextBlock = false
    }

    // MARK: - Block-complete copy helpers

    func trainedDayCount(in program: TrainingProgram) -> Int {
        program.days.reduce(0) { count, day in
            day.isRestDay ? count : (viewModel.isCompleted(dayNumber: day.dayNumber) ? count + 1 : count)
        }
    }

    func programBody(_ program: TrainingProgram) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            // AnyView-wrap the heavy section builders. Inlined, their combined
            // `some View` generic type is deep enough that the Swift runtime
            // overflows the stack instantiating its metadata on device
            // (EXC_BAD_ACCESS in SubstGenericParametersFromMetadata on the
            // Program tab; the simulator's larger budget hid it). Each AnyView
            // caps that subtree's metadata depth. Do NOT "simplify" these back to
            // bare calls — the crash returns.
            VStack(alignment: .leading, spacing: 16) {
                #if DEBUG
                if !ProcessInfo.processInfo.arguments.contains("--unbound-appstore-demo") {
                    AnyView(devDaySimulatorCard)
                    AnyView(devDynamicScenarioRail)
                }
                #endif
                AnyView(weekStrip(program: program))
                AnyView(dayCard(program: program))
                AnyView(programBelowDayTools(program: program))
                if let proposal = rolloverProposal,
                   shouldShowCheckpointPrompt(for: program, proposal: proposal) {
                    AnyView(
                        ProgramMidBlockProposalCard(
                            proposal: proposal,
                            onCheckpoint: openCheckpointFlow
                        )
                    )
                }
                if !services.entitlement.isEntitled {
                    AnyView(ProgramSubscriptionBanner(onOpen: openPaywall))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .fullScreenCover(item: $resumeDraft) { draft in
            ActiveWorkoutContainerView(
                workout: Workout(name: "", targetMuscleGroups: [], warmup: [],
                                mainExercises: [], cooldown: [], estimatedMinutes: 0,
                                notes: nil, blockType: nil),
                programId: "",
                dayNumber: 0,
                services: services,
                resuming: draft
            ) {
                UserDefaults.standard.set(0, forKey: "unbound.shortSessionDate")
                resumeDraft = nil
                Task { await viewModel.refreshCompletionState(asOf: selectedDayDate) }
            }
        }
        .task(id: program.id) {
            await loadBlockRolloverContext(program: program)
        }
    }

    func programBelowDayTools(program: TrainingProgram) -> some View {
        VStack(spacing: 8) {
            CoachActionsRow(
                program: program,
                todayDay: programDay(for: programToday, in: program),
                onTravelPlanAccepted: {
                    // The day resolver reads viewModel.activeTravelOverride —
                    // without this refresh an accepted travel plan stays
                    // invisible until the whole surface reloads.
                    Task { await viewModel.refreshTravelOverride() }
                }
            )
            .environmentObject(services)

            programControlDock(program: program)
        }
    }
}
