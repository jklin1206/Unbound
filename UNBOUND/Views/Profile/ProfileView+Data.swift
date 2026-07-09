// UNBOUND/Views/Profile/ProfileView+Data.swift
//
// Data loading + refresh for ProfileView: initial load, reward/cosmetic
// refreshes, flair publishing, and identity saves.
import SwiftUI

extension ProfileView {

    // MARK: - Load

    @MainActor
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

        // Load trials state — quiet title backfill first so retroactively
        // entitled rank/axis titles appear without waiting for a live event.
        TitleGrants.reconcile(userId: userId)
        trialsState = services.trials.state(userId: userId)

        isLoading = false

        // Publish this profile's resolved flair so squadmates can render it 1:1
        // (their cosmetics/showcase/hex are otherwise device-local). No-ops unless
        // signed in as the owner.
        await publishFlairIfOwned(userId: userId)
    }

    @MainActor
    private func publishFlairIfOwned(userId: String) async {
        let flair = SquadMemberFlair(
            backdropAssetName: activeProfileBackgroundAsset,
            borderId: equippedShopProfileBorder,
            frameTier: equippedFrameTier,
            rankTier: aggregateTier,
            showcaseSkillName: showcaseSkillName,
            showcaseSkillTier: showcaseSkillTier,
            showcaseLiftName: showcaseLiftName,
            showcaseLiftTier: showcaseLiftTier,
            attributeProfile: attributeProfile
        )
        await SquadFlairService.publish(flair, userId: userId)
    }

    @MainActor
    func refreshRewardReadouts(userId: String) async {
        sessionXP = services.sessionXP.record(userId: userId)
        overallLevel = (try? await services.database.read(
            collection: "overall_level_progress",
            documentId: userId
        )) ?? OverallLevelProgress(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
        trialsState = services.trials.state(userId: userId)
        totalWorkouts = max(totalWorkouts, sessionXP?.totalSessions ?? 0)
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
        // anything earned permanent). `aggregateTier` hydrates before this
        // runs in load(); on the first pass it can be .initiate — the sheet
        // and ratchet recompute with the live value on open/equip.
        let confirmedRank = OverallRankTrialStore.shared.load(userId: userId).currentRank
        let cosmeticTier = RankCosmetics.equipped(highestRank: max(confirmedRank, aggregateTier))
        _ = RankCosmetics.unlockedTiers(userId: userId, currentTier: cosmeticTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: cosmeticTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: cosmeticTier)
        refreshShopCosmetics(userId: userId)
    }

    func profileCosmeticChangeAppliesToCurrentUser(_ note: Notification) -> Bool {
        guard let eventUserId = note.userInfo?["userId"] as? String else { return true }
        return eventUserId == (services.auth.currentUserId ?? "anonymous")
    }

    @MainActor
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
}
