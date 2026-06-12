import SwiftUI

extension SkillSessionView {
    // MARK: - Header

    var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                if loggedCount > 0 {
                    isDiscardAlertPresented = true
                } else {
                    UnboundHaptics.soft()
                    stopTimer()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY'S SESSION")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                HStack(spacing: 6) {
                    Text(skillTitle)
                        .font(.system(.title3).weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if aiSession?.isAIGenerated == true {
                        aiBadge
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    UnboundHaptics.soft()
                    Task { await loadSession(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .disabled(isLoadingSession)

                Text(formatElapsed(elapsed))
                    .font(Font.unbound.monoM)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var aiBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("AI")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.8)
        }
        .foregroundStyle(Color.unbound.accent)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(Color.unbound.accent.opacity(0.14))
        )
    }

    // MARK: - Today's work (the single workout list)

    @ViewBuilder
    func todaysWorkList(_ items: [AIExercise]) -> some View {
        VStack(spacing: 12) {
            ForEach(items) { ex in
                workoutRow(ex)
            }
        }
    }

    /// One row per exercise: name (tap → explainer), one-line target meta,
    /// and a horizontal slot-chip strip to log every set inline.
    private func workoutRow(_ ex: AIExercise) -> some View {
        let logged = loggedSets[ex.id] ?? [:]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    UnboundHaptics.soft()
                    explainerExercise = ExplainerPayload(
                        name: ex.name,
                        description: ex.description,
                        cues: ex.cues,
                        notes: ex.notes
                    )
                } label: {
                    HStack(spacing: 6) {
                        Text(ex.name)
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                if logged.count == ex.setsCount {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
            }

            Text(targetSummary(ex))
                .font(Font.unbound.captionS.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textSecondary)

            slotsRow(ex: ex, logged: logged)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    /// "5 sets × 3 reps · 120s rest" / "3 × max hold · 60s rest"
    private func targetSummary(_ ex: AIExercise) -> String {
        "\(ex.setsCount) sets × \(ex.target.displayString) · \(ex.restSeconds)s rest"
    }

    private func slotsRow(ex: AIExercise, logged: [Int: LoggedSet]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(max(ex.setsCount, 1), 5))
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<ex.setsCount, id: \.self) { idx in
                slotChip(ex: ex, idx: idx, logged: logged[idx])
            }
        }
    }

    private func slotChip(ex: AIExercise, idx: Int, logged: LoggedSet?) -> some View {
        Button {
            UnboundHaptics.soft()
            activeSlot = ActiveSlot(prescriptionId: ex.id, slotIndex: idx)
        } label: {
            VStack(spacing: 2) {
                Text("SET \(idx + 1)")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(
                        logged == nil
                            ? Color.unbound.textTertiary
                            : Color.unbound.accent
                    )
                if let logged {
                    Text(loggedSummary(logged, target: ex.target))
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("—")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                // Calm: state via fill only — full surfaceElevated keeps the
                // unlogged tap target legible without a border.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(logged == nil
                        ? Color.unbound.surfaceElevated
                        : Color.unbound.accent.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }

    private func loggedSummary(_ s: LoggedSet, target: AIPrescriptionTarget) -> String {
        switch target {
        case .hold:
            let secs = s.holdSeconds ?? 0
            return "\(secs)s"
        default:
            if let kg = s.weightKg, kg > 0 {
                return "\(s.reps) · \(formatWeight(kg))"
            }
            return "\(s.reps) reps"
        }
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private func formatWeight(_ kg: Double) -> String {
        WeightPlatePolicy.formatLoggedWeightWithUnit(kg, unit: weightUnit)
    }

    // MARK: - Disclosure sections (regressions / accessories)

    @ViewBuilder
    func accessoriesDisclosure(_ items: [AIExercise]) -> some View {
        VStack(spacing: 0) {
            Button {
                UnboundHaptics.soft()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                    isAccessoriesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isAccessoriesExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Optional Accessories")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text("Add-on work for extra volume — skip if pressed for time")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(roundedCard)
            }
            .buttonStyle(.plain)

            if isAccessoriesExpanded {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        helperRow(item)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func helperRow(_ ex: AIExercise) -> some View {
        Button {
            UnboundHaptics.soft()
            explainerExercise = ExplainerPayload(
                name: ex.name,
                description: ex.description,
                cues: ex.cues,
                notes: ex.notes
            )
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 18, alignment: .center)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ex.name)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text("\(ex.setsCount) × \(ex.target.displayString)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(roundedCard)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading + summary

    var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.unbound.accent)
                .scaleEffect(1.3)
            Text("Generating today's session…")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
            if let err = loadError {
                Text(err)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    func summaryCard(_ session: AISession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY'S FOCUS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.accent)
            Text(session.summary)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("~\(session.estimatedDurationMinutes) min")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Generic fallback

    var genericFallback: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No detailed plan yet")
                .font(.system(.headline).weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text("This skill doesn't have a structured training plan in V1. Train the movement on your own — sets, reps, holds — and tap FINISH SESSION when you're done.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Finish bar

    var finishBar: some View {
        let title: String
        if !canFinish {
            title = "Log a set to finish"
        } else if isFinishing {
            title = "Saving session"
        } else if loggedCount == totalSlots && totalSlots > 0 {
            title = "Finish session"
        } else {
            title = "Finish session (\(loggedCount)/\(totalSlots))"
        }
        return UnboundButton(
            title: title,
            icon: "checkmark.seal.fill",
            isEnabled: canFinish && !isFinishing
        ) {
            Task { await finish() }
        }
        .accessibilityIdentifier("skillSession.finish")
    }

    // MARK: - Styling

    // Calm: fill-only section panel — no border-on-fill double chrome.
    private var roundedCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
    }
}
