import Foundation

enum L10n {
    static let table = "Localizable"
    static let bundle = Bundle(for: BundleToken.self)

    enum Key: String, CaseIterable {
        case appName = "app.name"

        case appErrorAuthNotAuthenticatedDescription = "app.error.auth.notAuthenticated.description"
        case appErrorCameraAccessDeniedDescription = "app.error.camera.accessDenied.description"
        case appErrorAnalysisTimeoutDescription = "app.error.analysis.timeout.description"
        case appErrorNetworkNoConnectionDescription = "app.error.network.noConnection.description"
        case appErrorSubscriptionNoActiveEntitlementDescription = "app.error.subscription.noActiveEntitlement.description"
        case appErrorGenericDescription = "app.error.generic.description"
        case appErrorCameraAccessDeniedRecovery = "app.error.camera.accessDenied.recovery"
        case appErrorNetworkNoConnectionRecovery = "app.error.network.noConnection.recovery"
        case appErrorAnalysisTimeoutRecovery = "app.error.analysis.timeout.recovery"
        case appErrorGenericRecovery = "app.error.generic.recovery"

        case cardioRunDisplayName = "cardio.type.run.displayName"
        case cardioBikeDisplayName = "cardio.type.bike.displayName"
        case cardioRowDisplayName = "cardio.type.row.displayName"
        case cardioWalkDisplayName = "cardio.type.walk.displayName"
        case cardioSwimDisplayName = "cardio.type.swim.displayName"
        case cardioStairsDisplayName = "cardio.type.stairs.displayName"
        case cardioEllipticalDisplayName = "cardio.type.elliptical.displayName"

        case notificationWorkoutEarlyMorningTitle = "notification.workout.earlyMorning.title"
        case notificationWorkoutMorningTitle = "notification.workout.morning.title"
        case notificationWorkoutLunchTitle = "notification.workout.lunch.title"
        case notificationWorkoutAfternoonTitle = "notification.workout.afternoon.title"
        case notificationWorkoutEveningTitle = "notification.workout.evening.title"
        case notificationWorkoutLateNightTitle = "notification.workout.lateNight.title"
        case notificationWorkoutVariesTitle = "notification.workout.varies.title"
        case notificationWorkoutEarlyMorningBody = "notification.workout.earlyMorning.body"
        case notificationWorkoutMorningBody = "notification.workout.morning.body"
        case notificationWorkoutLunchBody = "notification.workout.lunch.body"
        case notificationWorkoutAfternoonBody = "notification.workout.afternoon.body"
        case notificationWorkoutEveningBody = "notification.workout.evening.body"
        case notificationWorkoutLateNightBody = "notification.workout.lateNight.body"
        case notificationWorkoutVariesBody = "notification.workout.varies.body"
        case notificationRetentionRescanTitle = "notification.retention.rescan.title"
        case notificationRetentionRescanBody = "notification.retention.rescan.body"

        case scanCadenceNextCheckpointIn = "scan.cadence.nextCheckpointIn"
        case scanCadenceDaysRemaining = "scan.cadence.daysRemaining"
        case scanCadenceBody = "scan.cadence.body"
        case scanCadenceOverride = "scan.cadence.override"
        case scanConsentEyebrow = "scan.consent.eyebrow"
        case scanConsentTitle = "scan.consent.title"
        case scanConsentBulletQualitativeTitle = "scan.consent.bullet.qualitative.title"
        case scanConsentBulletQualitativeBody = "scan.consent.bullet.qualitative.body"
        case scanConsentBulletDeleteTitle = "scan.consent.bullet.delete.title"
        case scanConsentBulletDeleteBody = "scan.consent.bullet.delete.body"
        case scanConsentBulletChoiceTitle = "scan.consent.bullet.choice.title"
        case scanConsentBulletChoiceBody = "scan.consent.bullet.choice.body"
        case scanConsentAccept = "scan.consent.accept"
        case scanConsentDecline = "scan.consent.decline"
        case scanCaptureIntroScanLabel = "scan.capture.intro.scan.label"
        case scanCaptureIntroPhotoLabel = "scan.capture.intro.photo.label"
        case scanCaptureIntroScanTitle = "scan.capture.intro.scan.title"
        case scanCaptureIntroPhotoTitle = "scan.capture.intro.photo.title"
        case scanCaptureIntroScanBody = "scan.capture.intro.scan.body"
        case scanCaptureIntroPhotoBody = "scan.capture.intro.photo.body"
        case scanCaptureOpenCamera = "scan.capture.cta.openCamera"
        case scanCaptureCameraScanMode = "scan.capture.camera.mode.scan"
        case scanCaptureCameraPhotoMode = "scan.capture.camera.mode.photo"
        case scanCaptureRetake = "scan.capture.review.retake"
        case scanCaptureAnalyze = "scan.capture.review.analyze"
        case scanCaptureLockItIn = "scan.capture.review.lockItIn"
        case scanCaptureAnalyzingTitle = "scan.capture.analyzing.title"
        case scanCaptureAnalyzingBody = "scan.capture.analyzing.body"
        case scanFirstArcTitle = "scan.firstArc.title"
        case scanFirstArcCadence = "scan.firstArc.cadence"
        case scanFirstArcPrimaryCTA = "scan.firstArc.cta.primary"
        case scanFirstArcShare = "scan.firstArc.cta.share"
        case scanEvolutionPriorPhotoLabel = "scan.evolution.photo.priorLabel"
        case scanEvolutionCurrentPhotoLabel = "scan.evolution.photo.currentLabel"
        case scanEvolutionTitle = "scan.evolution.title"
        case scanEvolutionFocusArea = "scan.evolution.focusArea"
        case scanEvolutionCadence = "scan.evolution.cadence"
        case scanEvolutionPrimaryCTA = "scan.evolution.cta.primary"
        case scanEvolutionShare = "scan.evolution.cta.share"
        case scanBuildDeltaTitle = "scan.buildDelta.title"
        case scanBuildDeltaFirstScan = "scan.buildDelta.firstScan"
        case scanBuildDeltaLatest = "scan.buildDelta.latest"

        case buildIdentityDisplayNameBalancedAthlete = "buildIdentity.displayName.balancedAthlete"
        case buildIdentityDisplayNameHybridAthlete = "buildIdentity.displayName.hybridAthlete"
        case buildIdentityDisplayNameSpecialist = "buildIdentity.displayName.specialist"
        case buildIdentityDisplayNameHybrid = "buildIdentity.displayName.hybrid"
        case buildIdentityDisplayNameLean = "buildIdentity.displayName.lean"
        case buildIdentityAxisBalanced = "buildIdentity.axis.balanced"
        case buildIdentityTaglineEven = "buildIdentity.tagline.even"
        case buildIdentityTaglineHybridAthlete = "buildIdentity.tagline.hybridAthlete"
        case buildIdentityTaglineSpecialist = "buildIdentity.tagline.specialist"
        case buildIdentityTaglineHybrid = "buildIdentity.tagline.hybrid"
        case buildIdentityTaglineLean = "buildIdentity.tagline.lean"
        case scanNarrativeFirstBalanced = "scan.narrative.first.balanced"
        case scanNarrativeFirstHybridAthlete = "scan.narrative.first.hybridAthlete"
        case scanNarrativeFirstSpecialist = "scan.narrative.first.specialist"
        case scanNarrativeFirstHybridWithSecondary = "scan.narrative.first.hybrid.withSecondary"
        case scanNarrativeFirstHybridWithoutSecondary = "scan.narrative.first.hybrid.withoutSecondary"
        case scanNarrativeFirstLean = "scan.narrative.first.lean"
        case scanNarrativeEvolutionSteady = "scan.narrative.evolution.steady"
        case scanNarrativeEvolutionPrimaryWithSecondary = "scan.narrative.evolution.primaryWithSecondary"
        case scanNarrativeEvolutionPrimaryOnly = "scan.narrative.evolution.primaryOnly"
        case scanNarrativeEvolutionMoved = "scan.narrative.evolution.moved"
        case scanPayoffFlavorFallback = "scan.payoffFlavor.fallback"

        case subscriptionLockedTitle = "subscription.locked.title"
        case subscriptionLockedSubtitle = "subscription.locked.subtitle"
        case subscriptionLockedCTA = "subscription.locked.cta"
        case subscriptionLockedDevUnlock = "subscription.locked.devUnlock"
        case subscriptionRestoreIdle = "subscription.restore.idle"
        case subscriptionRestoreRestoring = "subscription.restore.restoring"
        case subscriptionRestoreSuccess = "subscription.restore.success"
        case subscriptionRestoreNoActive = "subscription.restore.noActive"
        case subscriptionRestoreFailure = "subscription.restore.failure"

        case subscriptionPackagePitchQuarterlyTitle = "subscription.package.pitch.quarterly.title"
        case subscriptionPackagePitchDefaultTitle = "subscription.package.pitch.default.title"
        case subscriptionPackagePitchQuarterlyBody = "subscription.package.pitch.quarterly.body"
        case subscriptionPackagePitchDefaultBody = "subscription.package.pitch.default.body"
        case subscriptionPackageUnavailableTitle = "subscription.package.unavailable.title"
        case subscriptionPackageUnavailableBody = "subscription.package.unavailable.body"
        case subscriptionPackageOpeningCheckout = "subscription.package.openingCheckout"
        case subscriptionPackageStartQuarterly = "subscription.package.start.quarterly"
        case subscriptionPackageStartWeekly = "subscription.package.start.weekly"
        case subscriptionPackageStartAnnual = "subscription.package.start.annual"
        case subscriptionPackageStartMonthly = "subscription.package.start.monthly"
        case subscriptionPackageRevenueCatEmpty = "subscription.package.message.revenueCatEmpty"
        case subscriptionPackageLoadFailed = "subscription.package.message.loadFailed"
        case subscriptionPackagePurchaseNotCompleted = "subscription.package.message.purchaseNotCompleted"
        case subscriptionPackagePurchaseFailed = "subscription.package.message.purchaseFailed"
        case subscriptionPackagePlanQuarterly = "subscription.package.plan.quarterly"
        case subscriptionPackagePlanWeekly = "subscription.package.plan.weekly"
        case subscriptionPackagePlanAnnual = "subscription.package.plan.annual"
        case subscriptionPackagePlanMonthly = "subscription.package.plan.monthly"
        case subscriptionPackagePlanFallback = "subscription.package.plan.fallback"
        case subscriptionPackageBadgeQuarterly = "subscription.package.badge.quarterly"
        case subscriptionPackageBadgeWeekly = "subscription.package.badge.weekly"
        case subscriptionPackageBadgeAnnual = "subscription.package.badge.annual"
        case subscriptionPackagePricePerMonth = "subscription.package.price.perMonth"
        case subscriptionPackageQuarterlyBilling = "subscription.package.detail.quarterlyBilling"
        case subscriptionPackageAnnualBilling = "subscription.package.detail.annualBilling"
        case subscriptionPackageWeeklyTrial = "subscription.package.detail.weeklyTrial"
        case subscriptionPackageMonthlyTrial = "subscription.package.detail.monthlyTrial"
        case subscriptionPackageWeeklyFlexible = "subscription.package.detail.weeklyFlexible"
        case subscriptionPackageMonthlyFlexible = "subscription.package.detail.monthlyFlexible"
        case subscriptionPackageGeneric = "subscription.package.detail.generic"
        case subscriptionPackageTrialWithDuration = "subscription.package.trial.withDuration"
        case subscriptionPackageTrial = "subscription.package.trial"

        case paywallUnlockTitle = "paywall.unlock.title"
        case paywallUnlockSubtitle = "paywall.unlock.subtitle"
        case paywallFeatureCustomProgram = "paywall.feature.customProgram"
        case paywallFeatureNutritionRecovery = "paywall.feature.nutritionRecovery"
        case paywallFeatureProgressScans = "paywall.feature.progressScans"
        case paywallFeatureSkillTree = "paywall.feature.skillTree"
        case paywallFeatureSquadsVowsUnlocks = "paywall.feature.squadsVowsUnlocks"
        case paywallSubscribeToUnlock = "paywall.cta.subscribeToUnlock"
        case legalTermsShort = "legal.terms.short"
        case legalPrivacyShort = "legal.privacy.short"
        case legalTermsOfService = "legal.termsOfService"
        case legalPrivacyPolicy = "legal.privacyPolicy"

        case authSignInSubtitle = "auth.signIn.subtitle"
        case authAppleSignIn = "auth.apple.signIn"
        case authEmailDivider = "auth.email.divider"
        case authLegalPrefix = "auth.legal.prefix"
        case authLegalAnd = "auth.legal.and"
        case authEmailPlaceholder = "auth.email.placeholder"
        case authPasswordPlaceholder = "auth.password.placeholder"
        case authCreateAccount = "auth.email.createAccount"
        case authSignIn = "auth.email.signIn"
        case authToggleSignIn = "auth.email.toggle.signIn"
        case authToggleCreateAccount = "auth.email.toggle.createAccount"

        case settingsTitle = "settings.title"
        case settingsSectionAccount = "settings.section.account"
        case settingsSectionSubscription = "settings.section.subscription"
        case settingsSectionPrivacy = "settings.section.privacy"
        case settingsSectionTraining = "settings.section.training"
        case settingsSectionAppearance = "settings.section.appearance"
        case settingsSectionSupport = "settings.section.support"
        case settingsSectionLegal = "settings.section.legal"
        case settingsSectionDangerZone = "settings.section.dangerZone"
        case settingsEmail = "settings.account.email"
        case settingsSignOut = "settings.account.signOut"
        case settingsPlan = "settings.subscription.plan"
        case settingsPlanPro = "settings.subscription.plan.pro"
        case settingsPlanFree = "settings.subscription.plan.free"
        case settingsManageSubscription = "settings.subscription.manage"
        case settingsShareUsageData = "settings.privacy.shareUsageData"
        case settingsNotifications = "settings.privacy.notifications"
        case settingsWeightUnit = "settings.training.weightUnit"
        case settingsMicroPlates = "settings.training.microPlates"
        case settingsExerciseLibrary = "settings.training.exerciseLibrary"
        case settingsEquipment = "settings.training.equipment"
        case settingsPlanChanges = "settings.training.planChanges"
        case settingsBadges = "settings.training.badges"
        case settingsTrainingFooter = "settings.training.footer"
        case settingsProfileCosmetics = "settings.appearance.profileCosmetics"
        case settingsSkillTreeCosmetics = "settings.appearance.skillTreeCosmetics"
        case settingsAppearanceFooter = "settings.appearance.footer"
        case settingsContactUs = "settings.support.contactUs"
        case settingsFAQ = "settings.support.faq"
        case settingsFAQComingSoon = "settings.support.faq.comingSoon"
        case settingsDeleteAccount = "settings.danger.deleteAccount"
        case settingsAlertError = "settings.alert.error"
        case settingsAlertOK = "settings.alert.ok"

        case notificationSettingsChecking = "settings.notifications.authorization.checking"
        case notificationSettingsPermission = "settings.notifications.permission"
        case notificationSettingsAllowNotifications = "settings.notifications.allow"
        case notificationSettingsSectionSystem = "settings.notifications.section.system"
        case notificationSettingsWorkoutReminders = "settings.notifications.workoutReminders"
        case notificationSettingsTime = "settings.notifications.time"
        case notificationSettingsRescanNudge = "settings.notifications.rescanNudge"
        case notificationSettingsDaysAfterScan = "settings.notifications.daysAfterScan"
        case notificationSettingsSectionProgress = "settings.notifications.section.progress"
        case notificationSettingsMilestones = "settings.notifications.milestones"
        case notificationAuthorizationAllowed = "settings.notifications.authorization.allowed"
        case notificationAuthorizationProvisional = "settings.notifications.authorization.provisional"
        case notificationAuthorizationTemporary = "settings.notifications.authorization.temporary"
        case notificationAuthorizationDenied = "settings.notifications.authorization.denied"
        case notificationAuthorizationNotAsked = "settings.notifications.authorization.notAsked"
        case notificationAuthorizationUnknown = "settings.notifications.authorization.unknown"

        case weekdayMondayShort = "weekday.monday.short"
        case weekdayTuesdayShort = "weekday.tuesday.short"
        case weekdayWednesdayShort = "weekday.wednesday.short"
        case weekdayThursdayShort = "weekday.thursday.short"
        case weekdayFridayShort = "weekday.friday.short"
        case weekdaySaturdayShort = "weekday.saturday.short"
        case weekdaySundayShort = "weekday.sunday.short"

        case workoutTimeEarlyMorningDisplayName = "workoutTime.earlyMorning.displayName"
        case workoutTimeMorningDisplayName = "workoutTime.morning.displayName"
        case workoutTimeLunchDisplayName = "workoutTime.lunch.displayName"
        case workoutTimeAfternoonDisplayName = "workoutTime.afternoon.displayName"
        case workoutTimeEveningDisplayName = "workoutTime.evening.displayName"
        case workoutTimeLateNightDisplayName = "workoutTime.lateNight.displayName"
        case workoutTimeVariesDisplayName = "workoutTime.varies.displayName"
        case workoutTimeEarlyMorningSubtitle = "workoutTime.earlyMorning.subtitle"
        case workoutTimeMorningSubtitle = "workoutTime.morning.subtitle"
        case workoutTimeLunchSubtitle = "workoutTime.lunch.subtitle"
        case workoutTimeAfternoonSubtitle = "workoutTime.afternoon.subtitle"
        case workoutTimeEveningSubtitle = "workoutTime.evening.subtitle"
        case workoutTimeLateNightSubtitle = "workoutTime.lateNight.subtitle"
        case workoutTimeVariesSubtitle = "workoutTime.varies.subtitle"

        case trainingWeightUnitKilograms = "trainingWeightUnit.kilograms.displayName"
        case trainingWeightUnitPounds = "trainingWeightUnit.pounds.displayName"
    }

    static func string(
        _ key: Key,
        defaultValue: String,
        table: String = L10n.table,
        bundle: Bundle = L10n.bundle
    ) -> String {
        string(key.rawValue, defaultValue: defaultValue, table: table, bundle: bundle)
    }

    static func string(
        _ key: String,
        defaultValue: String,
        table: String = L10n.table,
        bundle: Bundle = L10n.bundle
    ) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: table)
    }

    static func format(
        _ key: Key,
        defaultValue: String,
        _ arguments: CVarArg...
    ) -> String {
        let localizedFormat = string(key, defaultValue: defaultValue)
        return String(format: localizedFormat, locale: Locale.current, arguments: arguments)
    }

    static func onboardingAnswer(
        group: String,
        id: String,
        field: String,
        defaultValue: String
    ) -> String {
        string("onboarding.answer.\(group).\(id).\(field)", defaultValue: defaultValue)
    }

    static func attribute(id: String, field: String, defaultValue: String) -> String {
        string("attribute.\(id).\(field)", defaultValue: defaultValue)
    }

    static func onboarding(_ key: String, defaultValue: String) -> String {
        string("onboarding.\(key)", defaultValue: defaultValue)
    }

    static func onboardingFormat(_ key: String, defaultValue: String, _ arguments: CVarArg...) -> String {
        let localizedFormat = onboarding(key, defaultValue: defaultValue)
        return String(format: localizedFormat, locale: Locale.current, arguments: arguments)
    }
}

private final class BundleToken {}
