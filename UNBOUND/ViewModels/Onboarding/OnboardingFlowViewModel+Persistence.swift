import Foundation

// MARK: - Validation (per-screen Continue-enabled rules)

extension OnboardingFlowViewModel {

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .problemFrame, .restartLoop,
             .arc01Opening, .arc03Path,
             .lifeChangeEnergy, .lifeChangeStrength, .lifeChangeConfidence,
             .lifeChangeSleep, .lifeChangeLooksFeel,
             .chapterMapping, .chapterScan, .chapterPath:
            return true
        case .goals:
            return !goals.isEmpty
        case .targetAreas:
            return !targetAreas.isEmpty
        case .motivation:
            return !motivations.isEmpty
        case .workoutTime:
            return workoutTime != nil
        case .age, .height, .weight:
            return true  // scroll pickers always have a value
        case .gender:
            return true
        case .experience:
            return experience != nil
        case .targetFrequency:
            return targetFrequency != nil
        case .trainingDays:
            return !trainingDays.isEmpty && trainingDays.count == (targetFrequency?.numericCount ?? 3)
        case .equipment:
            return !equipment.isEmpty
        case .exerciseStyle:
            return !exerciseStyles.isEmpty
        case .obstacles:
            return !obstacles.isEmpty
        case .sessionLength:
            return sessionLength != nil
        case .resultsSnapshot:
            return true
        case .diet, .sleep, .stress, .commitment:
            return true
        case .priorAttempts:
            return !priorAttempts.isEmpty
        case .name:
            return !displayHandle.trimmingCharacters(in: .whitespaces).isEmpty
        case .notifications, .scanAnalyzing,
             .verdict, .appPainSolution, .workoutPreviewDemo,
             .workoutLogDemo, .workoutRewardDemo, .appRatingPrompt,
             .trajectory, .obstacleFix, .whyThisProgram,
             .socialProofGallery, .commitDay30, .commitDay90, .commitToday, .planReady, .paywall:
            return true
        case .scanLive, .scanReview:
            return capturedPhotos[.front] != nil
        }
    }
}

// MARK: - Finish — persist answers

extension OnboardingFlowViewModel {

    /// Called from Screen 30 (scan prep). Writes answers to Firestore and
    /// sets the legacy onboardingCompleted flag so the existing route gate
    /// advances to HomeTabView.
    ///
    /// Returns `true` on success. Throws nothing — network errors are logged
    /// but don't block the user from proceeding (answers retry on next app
    /// open via the legacy UserDefaults flag).
    @discardableResult
    func finish(userId: String) async -> Bool {
        let fields: [String: Any] = buildFirestorePayload()
        // Onboarding runs BEFORE sign-in, so `userId` is usually the "anonymous"
        // placeholder and this write only reaches the local store. Stash the
        // payload so it is replayed onto the real account at sign-in (cleared
        // there once it lands). Without this, the authed user starts blank and
        // program generation runs on defaults.
        PendingOnboardingProfile.stash(fields)
        do {
            try await userService.updateProfile(userId: userId, fields: fields)
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            await MainActor.run {
                BadgeService.shared.bind(userId: userId)
            }
            await scheduleNotifications()
            AnalyticsService.shared.track(.onboardingCompleted)
            logger.info("Onboarding answers persisted for user \(userId, privacy: .private)")
            return true
        } catch {
            logger.error("Failed to persist onboarding answers: \(String(describing: error))")
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            await scheduleNotifications()
            AnalyticsService.shared.track(.onboardingCompleted)
            return false
        }
    }

    private func scheduleNotifications() async {
        guard notificationsRequested, let workoutTime else { return }
        await NotificationService.scheduleWorkoutReminders(
            workoutTime: workoutTime,
            trainingDays: trainingDays,
            minuteOfDay: workoutMinuteOfDay
        )
    }

    func buildFirestorePayload() -> [String: Any] {
        var fields: [String: Any] = [
            "onboardingCompleted": true,
            "displayHandle": displayHandle,
            "age": age,
            "heightCm": heightCm,
            "weightKg": weightKg,
            "gender": gender.rawValue,
            "dietQuality": dietQuality,
            "sleepQuality": sleepQuality,
            "stressLevel": stressLevel,
            "commitment": commitment,
            "motivations": motivations.map(\.rawValue),
            "goals": goals.map(\.rawValue),
            "targetAreas": targetAreas.map(\.rawValue),
            "equipment": equipment.map(\.rawValue),
            "exerciseStyles": exerciseStyles.map(\.rawValue),
            "obstacles": obstacles.map(\.rawValue),
            "priorAttempts": priorAttempts.map(\.rawValue)
        ]
        if let workoutTime { fields["workoutTime"] = workoutTime.rawValue }
        if let workoutMinuteOfDay { fields["workoutMinuteOfDay"] = workoutMinuteOfDay }
        fields["seededAttributes"] = effectiveSeededAttributes.map(\.rawValue)
        // preferredArchetype field removed — inferred attribute sparks drive Build instead
        if let experience { fields["experience"] = experience.rawValue }
        // Auto-default training feedback mode from experience level.
        // Beginner-equivalent (never/tried) → silent; active (used/current) → quick.
        // User can promote to .detailed in Settings.
        if fields["trainingFeedbackMode"] == nil, let exp = experience {
            fields["trainingFeedbackMode"] = TrainingFeedbackMode.default(for: exp).rawValue
        }
        if let currentFrequency { fields["currentFrequency"] = currentFrequency.rawValue }
        if let targetFrequency { fields["targetFrequency"] = targetFrequency.rawValue }
        if !trainingDays.isEmpty { fields["trainingDays"] = trainingDays.map(\.rawValue) }
        if let sessionLength { fields["sessionLength"] = sessionLength.rawValue }
        return fields
    }
}
