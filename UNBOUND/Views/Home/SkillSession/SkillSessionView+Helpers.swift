import SwiftUI

// MARK: - Session helpers: prescription lookup, AI session loading, timer, formatting, styling

extension SkillSessionView {

    // MARK: - Helpers

    func prescription(for id: String) -> TrainingPrescription? {
        guard let ex = aiSession?.exercises.first(where: { $0.id == id }) else { return nil }
        return ex.asLegacyPrescription
    }

    /// Loads (or regenerates) today's AI session. Drops any logged sets when
    /// the session is replaced so the slot strip rehydrates against fresh
    /// prescriptions.
    func loadSession(forceRefresh: Bool) async {
        guard let userId = AuthService.shared.currentUserId else {
            isLoadingSession = false
            loadError = "Sign in before starting a skill session."
            return
        }
        isLoadingSession = true
        loadError = nil
        if forceRefresh {
            loggedSets = [:]
            sessionStart = Date()
            elapsed = 0
        }
        do {
            let session = try await RPESessionService.shared.session(
                forSkillId: skillId,
                userId: userId,
                forceRefresh: forceRefresh
            )
            self.aiSession = session
        } catch {
            loadError = error.localizedDescription
            // Fallback path inside the service catches most cases — but if the
            // service itself rethrows, surface a generic AMRAP shell so the
            // user can still log work.
            self.aiSession = AISession(
                skillId: skillId,
                generatedAt: Date(),
                summary: "Train today's skill — quality over volume.",
                estimatedDurationMinutes: 20,
                exercises: [
                    AIExercise(
                        name: skillTitle,
                        description: "Train the skill directly. Log what you hit.",
                        cues: [],
                        setsCount: 3,
                        target: .amrap,
                        restSeconds: 90,
                        notes: nil,
                        isAccessory: false
                    )
                ],
                isAIGenerated: false
            )
        }
        isLoadingSession = false
    }

    func startTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsed = Int(Date().timeIntervalSince(sessionStart))
            }
        }
    }

    func stopTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func formatElapsed(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    // MARK: - Styling

    // Calm: fill-only section panel — no border-on-fill double chrome.
    var roundedCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
    }
}
