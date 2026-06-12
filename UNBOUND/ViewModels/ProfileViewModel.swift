import Combine
import Foundation

// MARK: - ProfileViewModel
//
// Owns the Profile screen's data state: profile identity, aggregate tier,
// badges, showcase picks, equipped cosmetics, photo counts, XP/level, and
// trials. Loading/refresh/save logic moved verbatim from `ProfileView` —
// presentation state (sheets, pickers, header sizing) stays on the view.

@MainActor
final class ProfileViewModel: ObservableObject {

    // Identity + rank
    @Published var profile: UserProfile?
    @Published var aggregateTier: SkillTier = .initiate
    @Published var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)

    // Badges + lifetime stats
    @Published var unlockedBadges: [Badge] = []
    @Published var totalBadgeCount: Int = 0
    @Published var totalWorkouts: Int = 0

    // Showcase
    @Published var showcaseSkillId: String?
    @Published var showcaseSkillName: String = "None yet"
    @Published var showcaseSkillTier: SkillTier = .initiate
    @Published var showcaseLiftId: String?
    @Published var showcaseLiftName: String = "None yet"
    @Published var showcaseLiftTier: SkillTier = .initiate
    @Published var showcaseSkillOptions: [ProfileShowcaseOption] = []
    @Published var showcaseLiftOptions: [ProfileShowcaseOption] = []

    // Equipped cosmetics
    @Published var equippedFrameTier: RankTitle = .initiate
    @Published var equippedBackgroundTier: RankTitle = .initiate
    @Published var equippedShopProfileBorder: ShopProfileBorderID?
    @Published var equippedProfileBackdrop: ShopItem?

    // XP / level
    @Published var sessionXP: SessionXPRecord?
    @Published var overallLevel: OverallLevelProgress?

    // Photos
    @Published var manualPhotoCount: Int = 0
    @Published var scanPhotoCount: Int = 0
    @Published var beforePhoto: ProgressPhoto?
    @Published var afterPhoto: ProgressPhoto?

    // Trials
    @Published var trialsState: TrialsState = .empty
    @Published var overallRankTrialReadiness: OverallRankTrialReadiness?

    @Published var isLoading = true

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    // MARK: - Load

    func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        services.badges.bind(userId: userId)

        do {
            profile = try await services.user.fetchProfile(userId: userId)
        } catch {
            profile = nil
        }

        aggregateTier = await services.rank.aggregateTier(userId: userId)
        refreshEquippedCosmetics(userId: userId)
        attributeProfile = services.attribute.profile(userId: userId)

        unlockedBadges = services.badges.unlockedBadges(userId: userId)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        totalBadgeCount = BadgeCatalog.all.count
        sessionXP = services.sessionXP.record(userId: userId)
        overallLevel = (try? await services.database.read(collection: "overall_level_progress", documentId: userId)) ?? OverallLevelProgress(userId: userId)

        let photos: [ProgressPhoto] = (try? await services.database.query(
            collection: "progressPhotos",
            field: "userId",
            isEqualTo: userId,
            orderBy: "capturedAt",
            descending: true,
            limit: 500
        )) ?? []
        manualPhotoCount = photos.filter { $0.source == .manual }.count
        scanPhotoCount = photos.filter { $0.source == .scan }.count
        let orderedPhotos = photos.sorted { $0.capturedAt < $1.capturedAt }
        beforePhoto = orderedPhotos.first
        afterPhoto = orderedPhotos.last

        let workoutLogs: [WorkoutLog] = (try? await services.database.query(
            collection: "workoutLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "startedAt",
            descending: true,
            limit: nil
        )) ?? []
        totalWorkouts = max(workoutLogs.count, sessionXP?.totalSessions ?? 0)
        resolveProfileShowcase(
            userId: userId,
            workoutLogs: workoutLogs,
            bodyweightKg: profile?.weightKg,
            sex: profile?.biologicalSex
        )

        // Load trials state
        trialsState = services.trials.state(userId: userId)
        overallRankTrialReadiness = await TrialReadinessService.shared.readiness(userId: userId, services: services)

        isLoading = false
    }

    // MARK: - Refresh

    func refreshRewardReadouts() async {
        guard let userId = services.auth.currentUserId else { return }
        sessionXP = services.sessionXP.record(userId: userId)
        overallLevel = (try? await services.database.read(
            collection: "overall_level_progress",
            documentId: userId
        )) ?? OverallLevelProgress(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
        trialsState = services.trials.state(userId: userId)
        totalWorkouts = max(totalWorkouts, sessionXP?.totalSessions ?? 0)
    }

    func handleAttributeRankUp() async {
        guard let userId = services.auth.currentUserId else { return }
        attributeProfile = services.attribute.profile(userId: userId)
        await refreshRewardReadouts()
    }

    func refreshShopCosmetics(userId overrideUserId: String? = nil) {
        let userId = overrideUserId ?? services.auth.currentUserId ?? "anonymous"
        equippedShopProfileBorder = ShopInventoryStore.equippedProfileBorder(userId: userId)
        equippedProfileBackdrop = ShopInventoryStore.equippedBackdrop(for: .profile, userId: userId)
    }

    func refreshEquippedCosmetics(userId overrideUserId: String? = nil) {
        let userId = overrideUserId ?? services.auth.currentUserId ?? "anonymous"
        // Cosmetic unlocks follow the rank the app SHOWS the user: the rank
        // plate displays the skill-aggregate tier, so the aggregate counts
        // alongside the trial-confirmed rank (the unlock ratchet keeps
        // anything earned permanent).
        let confirmedRank = OverallRankTrialStore.shared.load(userId: userId).currentRank
        let cosmeticTier = RankCosmetics.equipped(highestRank: max(confirmedRank, aggregateTier))
        _ = RankCosmetics.unlockedTiers(userId: userId, currentTier: cosmeticTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: cosmeticTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: cosmeticTier)
        refreshShopCosmetics(userId: userId)
    }

    func cosmeticChangeAppliesToCurrentUser(_ note: Notification) -> Bool {
        guard let eventUserId = note.userInfo?["userId"] as? String else { return true }
        return eventUserId == (services.auth.currentUserId ?? "anonymous")
    }

    // MARK: - Rank trial

    func overallRankTrialDraft(for definition: OverallRankTrialDefinition) -> TrainingSessionDraft {
        let userId = services.auth.currentUserId ?? "anonymous"
        let resolvedTrial = overallRankTrialReadiness?.resolvedTrial?.definitionId == definition.id
            ? overallRankTrialReadiness?.resolvedTrial
            : nil
        return OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: userId,
            resolvedTrial: resolvedTrial,
            bodyweightKg: profile?.weightKg
        )
    }

    // MARK: - Save

    func saveProfileIdentity(
        displayHandle: String,
        equippedTitle: TitleID?,
        showcaseSelection: ProfileShowcaseSelection
    ) async throws {
        let userId = services.auth.currentUserId ?? "anonymous"
        let cleanedHandle = displayHandle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))

        try await services.user.updateProfile(
            userId: userId,
            fields: [
                "displayName": NSNull(),
                "displayHandle": cleanedHandle.isEmpty ? NSNull() : cleanedHandle
            ]
        )

        services.trials.equipTitle(equippedTitle, userId: userId)
        trialsState = services.trials.state(userId: userId)
        ProfileShowcaseStore.save(showcaseSelection, userId: userId)
        applyProfileShowcase(
            selection: showcaseSelection,
            skillOptions: showcaseSkillOptions,
            liftOptions: showcaseLiftOptions
        )

        if var profile {
            profile.displayName = nil
            profile.displayHandle = cleanedHandle.isEmpty ? nil : cleanedHandle
            self.profile = profile
        }
    }

    // MARK: - Showcase resolution

    private func resolveProfileShowcase(
        userId: String,
        workoutLogs: [WorkoutLog],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) {
        let selection = ProfileShowcaseStore.load(userId: userId)
        let skillOptions = Self.skillShowcaseOptions(userId: userId)
        let liftOptions = Self.loggedLiftCandidates(
            logs: workoutLogs,
            bodyweightKg: bodyweightKg,
            sex: sex
        )

        showcaseSkillOptions = skillOptions
        showcaseLiftOptions = liftOptions
        applyProfileShowcase(selection: selection, skillOptions: skillOptions, liftOptions: liftOptions)
    }

    private func applyProfileShowcase(
        selection: ProfileShowcaseSelection,
        skillOptions: [ProfileShowcaseOption],
        liftOptions: [ProfileShowcaseOption]
    ) {
        let skill = Self.selectedShowcaseOption(selection.skillId, options: skillOptions) ?? skillOptions.first
        showcaseSkillId = skill?.id
        showcaseSkillName = skill?.name ?? "None yet"
        showcaseSkillTier = skill?.tier ?? .initiate

        let lift = Self.selectedShowcaseOption(selection.liftId, options: liftOptions) ?? liftOptions.first
        showcaseLiftId = lift?.id
        showcaseLiftName = lift?.name ?? "None yet"
        showcaseLiftTier = lift?.tier ?? .initiate
    }

    private static func selectedShowcaseOption(
        _ id: String?,
        options: [ProfileShowcaseOption]
    ) -> ProfileShowcaseOption? {
        guard let id else { return nil }
        return options.first { $0.id == id }
    }

    private static func skillShowcaseOptions(userId: String) -> [ProfileShowcaseOption] {
        let skillTiers = UserSkillTierStore.shared.load(userId: userId).perSkill
        let nodeStates = SkillProgressService.shared.nodeStates
        let options = SkillGraph.shared.nodes.compactMap { node -> ProfileShowcaseOption? in
            guard nodeStates[node.id] == .proven else { return nil }
            return ProfileShowcaseOption(
                id: node.id,
                name: node.title,
                tier: skillTiers[node.id] ?? .initiate,
                metricSort: Double(node.placementRank.rawValue),
                repsSort: node.tier
            )
        }
        return sortedShowcaseOptions(options)
    }

    private static func displayLiftName(_ lift: String) -> String {
        lift.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func loggedLiftCandidates(
        logs: [WorkoutLog],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> [ProfileShowcaseOption] {
        var bestById: [String: ProfileShowcaseOption] = [:]
        for entry in logs.flatMap(\.exerciseEntries) {
            let rankKey = rankExerciseKey(for: entry)
            let liftId = MovementCatalog.normalized(entry.exerciseName)
            let liftName = displayLiftName(entry.exerciseName)

            for set in entry.sets {
                guard !set.isWarmup, let weightKg = set.weightKg, weightKg > 0 else { continue }
                guard let tier = Self.liftTier(
                    for: rankKey,
                    weightKg: weightKg,
                    bodyweightKg: bodyweightKg,
                    sex: sex
                ) else { continue }
                let option = ProfileShowcaseOption(
                    id: liftId,
                    name: liftName,
                    tier: tier,
                    metricSort: weightKg,
                    repsSort: set.reps
                )
                if let existing = bestById[liftId] {
                    if isShowcaseOption(option, betterThan: existing) {
                        bestById[liftId] = option
                    }
                } else {
                    bestById[liftId] = option
                }
            }
        }
        return sortedShowcaseOptions(Array(bestById.values))
    }

    private static func liftTier(
        for lift: String,
        weightKg: Double,
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> SkillTier? {
        guard weightKg > 0 else { return nil }
        if let bodyweightKg, bodyweightKg > 0 {
            return StrengthStandards.progressToNextRank(
                metricValue: weightKg,
                bodyweightKg: bodyweightKg,
                exerciseKey: lift,
                sex: sex
            )?.current
        }

        if StrengthStandards.canonicalKey(for: lift) != nil ||
            StrengthStandards.accessoryFamily(for: lift) != nil {
            return .initiate
        }

        return nil
    }

    private static func rankExerciseKey(for entry: ExerciseLogEntry) -> String {
        if let key = canonicalMovementExerciseKey(for: entry.rankStandardMovementId) {
            return key
        }
        if let key = canonicalMovementExerciseKey(for: entry.movementId) {
            return key
        }

        let resolved = MovementResolver.resolve(entry.exerciseName)
        if let key = canonicalMovementExerciseKey(for: resolved.rankStandardMovementId) {
            return key
        }
        return MovementResolution.normalizedKey(entry.exerciseName)
    }

    private static func canonicalMovementExerciseKey(for movementId: String?) -> String? {
        guard let movementId, let definition = MovementCatalog.definition(for: movementId) else {
            return nil
        }
        if let canonical = definition.canonicalExerciseName {
            return MovementResolution.normalizedKey(canonical)
        }
        return MovementResolution.normalizedKey(definition.displayName)
    }

    private static func sortedShowcaseOptions(_ options: [ProfileShowcaseOption]) -> [ProfileShowcaseOption] {
        options.sorted { lhs, rhs in
            isShowcaseOption(lhs, betterThan: rhs)
        }
    }

    private static func isShowcaseOption(
        _ lhs: ProfileShowcaseOption,
        betterThan rhs: ProfileShowcaseOption
    ) -> Bool {
        if lhs.tier != rhs.tier { return lhs.tier > rhs.tier }
        if lhs.metricSort != rhs.metricSort { return lhs.metricSort > rhs.metricSort }
        if lhs.repsSort != rhs.repsSort { return lhs.repsSort > rhs.repsSort }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    // MARK: - Derived

    var vowsCompletedCount: Int {
        trialsState.completionsByCardKind.values.reduce(0, +)
    }

    var profileIdentityName: String {
        playerHandle
    }

    var profileTitleLine: String {
        trialsState.equippedTitle.map(TitleCatalog.displayName(for:)) ?? "No title"
    }

    var avatarInitial: String {
        if let handle = cleanedStoredHandle, let first = handle.first {
            return String(first).uppercased()
        }
        return "U"
    }

    var playerHandle: String {
        if let handle = cleanedStoredHandle {
            return handle.uppercased()
        }
        return "PLAYER"
    }

    private var cleanedStoredHandle: String? {
        guard let handle = profile?.displayHandle else { return nil }
        let cleaned = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return cleaned.isEmpty ? nil : cleaned
    }
}
