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

    // MARK: - Block-complete state (Chunk 3)
    //
    // Surfaces when the current 28-day block has elapsed. Shows a single
    // premium card with one primary CTA ("BUILD BLOCK N+1") and a secondary
    // RESCAN affordance. Pulls the latest ScanDeltaReport (if any) so we can
    // surface a small "what changed" teaser before the user commits.

    @ViewBuilder
    func blockCompleteState(program: TrainingProgram) -> some View {
        let nextBlock = nextBlockNumberPreview
        let currentBlock = currentBlockNumberPreview
        let arc = ProgramBlockRolloverCoordinator.arcLabel(for: nextBlock)

        ProgramBlockCompleteView(
            currentBlock: currentBlock,
            nextBlock: nextBlock,
            arc: arc,
            trainedDays: trainedDayCount(in: program),
            totalDays: program.durationDays,
            deltaReport: rolloverDeltaReport,
            proposal: rolloverProposal,
            isGeneratingNextBlock: isGeneratingNextBlock,
            onProgressSnapshot: {
                UnboundHaptics.soft()
                showProgressReveal = true
            },
            onBuildNextBlock: {
                UnboundHaptics.soft()
                Task { await runGenerateNextBlock(currentProgram: program) }
            },
            onCheckpoint: {
                UnboundHaptics.soft()
                showCheckpointFlow = true
            }
        )
        .task { await loadBlockRolloverContext(program: program) }
        .sheet(isPresented: $showProgressReveal) {
            if let delta = rolloverDeltaReport {
                BlockProgressRevealView(
                    deltaReport: delta,
                    blockNumber: currentBlock,
                    nextBlockNumber: nextBlock,
                    onBuildNextBlock: {
                        showProgressReveal = false
                        Task { await runGenerateNextBlock(currentProgram: program) }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
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

    /// Drives the BUILD BLOCK N CTA: spinner → generate → swap state to the
    /// new program. Failures restore the loaded state silently so the user
    /// can retry; production telemetry catches the failure path.
    func runGenerateNextBlock(currentProgram: TrainingProgram) async {
        guard let userId = services.auth.currentUserId,
              !isGeneratingNextBlock else { return }
        let vm = viewModel

        isGeneratingNextBlock = true
        let restoreState: LoadingState<TrainingProgram> = vm.state
        vm.state = .loading

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
            vm.state = restoreState
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
                AnyView(devDaySimulatorCard)
                AnyView(devDynamicScenarioRail)
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
            viewModel.refreshWaveAdjustments(asOf: selectedDayDate)
        }
        .task(id: selectedDayDate) {
            viewModel.refreshWaveAdjustments(asOf: selectedDayDate)
        }
    }

    func programBelowDayTools(program: TrainingProgram) -> some View {
        VStack(spacing: 8) {
            CoachActionsRow(
                program: program,
                todayDay: programDay(for: programToday, in: program)
            )
            .environmentObject(services)

            programControlDock(program: program)
        }
    }
}
