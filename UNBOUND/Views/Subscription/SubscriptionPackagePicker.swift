import SwiftUI

struct SubscriptionPackagePicker: View {
    @EnvironmentObject private var services: ServiceContainer

    let placement: String
    var ctaTitle: String = L10n.string(.subscriptionLockedCTA, defaultValue: "Subscribe to continue")
    var showsPitch: Bool = true
    var onPurchased: () -> Void = {}

    @State private var packages: [SubscriptionPackage] = []
    @State private var selectedPackageId: String?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            if showsPitch, !isLoading, !packages.isEmpty {
                paywallPitch
            }

            packageList

            UnboundButton(
                title: purchaseButtonTitle,
                icon: "crown.fill",
                action: { Task { await purchaseSelectedPackage() } }
            )
            .disabled(isLoading || isPurchasing || selectedPackageId == nil)

            if let message {
                Text(message)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .task { await loadPackages() }
        .animation(.easeInOut(duration: 0.2), value: message)
    }

    private var packageList: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(Color.unbound.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(packageBackground(isSelected: false))
            } else if packages.isEmpty {
                unavailableCard
            } else {
                ForEach(orderedPackages) { package in
                    packageCard(package)
                }
            }
        }
    }

    private var paywallPitch: some View {
        VStack(spacing: 8) {
            Text(hasQuarterlyPackage ? quarterlyPitchTitle : defaultPitchTitle)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)

            Text(hasQuarterlyPackage ? quarterlyPitchBody : defaultPitchBody)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string(.subscriptionPackageUnavailableTitle, defaultValue: "Subscription unavailable"))
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(L10n.string(.subscriptionPackageUnavailableBody, defaultValue: "Products are not configured for this build yet."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(packageBackground(isSelected: false))
    }

    private func packageCard(_ package: SubscriptionPackage) -> some View {
        let isSelected = selectedPackageId == package.id
        return Button {
            UnboundHaptics.medium()
            selectedPackageId = package.id
        } label: {
            HStack(spacing: 12) {
                selectionIndicator(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text(planTitle(for: package))
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)

                        if let badge = badgeText(for: package) {
                            planBadge(badge, emphasized: isQuarterly(package))
                        } else if package.hasFreeTrial {
                            planBadge(trialBadge(for: package), emphasized: false)
                        }
                    }

                    Text(detailLine(for: package))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(package.price)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()

                    if shouldShowPerMonth(for: package), let pricePerMonth = package.pricePerMonth {
                        Text(L10n.format(.subscriptionPackagePricePerMonth, defaultValue: "%@/mo", pricePerMonth))
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(16)
            .background(packageBackground(isSelected: isSelected))
            .shadow(
                color: isSelected ? Color.unbound.accent.opacity(0.35) : .clear,
                radius: 14,
                x: 0,
                y: 0
            )
        }
        .buttonStyle(.plain)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.unbound.accent : Color.unbound.border, lineWidth: 1.5)
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func planBadge(_ text: String, emphasized: Bool) -> some View {
        Text(text)
            .font(Font.unbound.captionS)
            .tracking(1.1)
            .foregroundStyle(emphasized ? Color.black : Color.unbound.impact)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(emphasized ? Color.unbound.impact : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(Color.unbound.impact.opacity(emphasized ? 0 : 0.6), lineWidth: 1)
            )
    }

    private func packageBackground(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.unbound.accent : Color.unbound.border,
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
    }

    private var purchaseButtonTitle: String {
        if isPurchasing {
            return L10n.string(.subscriptionPackageOpeningCheckout, defaultValue: "Opening checkout...")
        }
        if let selectedPackage {
            if isQuarterly(selectedPackage) {
                return L10n.string(.subscriptionPackageStartQuarterly, defaultValue: "Start 3-month arc")
            }
            if isWeekly(selectedPackage) {
                return L10n.string(.subscriptionPackageStartWeekly, defaultValue: "Start weekly access")
            }
            if isAnnual(selectedPackage) {
                return L10n.string(.subscriptionPackageStartAnnual, defaultValue: "Start annual arc")
            }
            if isMonthly(selectedPackage) {
                return L10n.string(.subscriptionPackageStartMonthly, defaultValue: "Start monthly arc")
            }
        }
        return ctaTitle
    }

    private var selectedPackage: SubscriptionPackage? {
        packages.first { $0.id == selectedPackageId }
    }

    private var orderedPackages: [SubscriptionPackage] {
        packages.sorted { lhs, rhs in
            packagePriority(lhs) < packagePriority(rhs)
        }
    }

    private var hasQuarterlyPackage: Bool {
        packages.contains { isQuarterly($0) }
    }

    private func loadPackages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            packages = try await services.subscription.fetchOfferings()
            selectedPackageId = preferredPackageId(from: packages)
            message = packages.isEmpty
                ? L10n.string(.subscriptionPackageRevenueCatEmpty, defaultValue: "RevenueCat returned no available packages.")
                : nil
        } catch {
            packages = []
            selectedPackageId = nil
            message = L10n.string(.subscriptionPackageLoadFailed, defaultValue: "Couldn't load subscription options.")
        }
    }

    private func purchaseSelectedPackage() async {
        guard let selectedPackageId, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        services.analytics.track(.paywallPresented(placement: placement))
        do {
            let success = try await services.subscription.purchase(packageId: selectedPackageId)
            if success {
                services.analytics.track(.paywallConverted(placement: placement, productId: selectedPackage?.productId ?? selectedPackageId))
                onPurchased()
            } else {
                services.analytics.track(.paywallDismissed(placement: placement))
                message = L10n.string(.subscriptionPackagePurchaseNotCompleted, defaultValue: "Purchase was not completed.")
            }
        } catch {
            services.analytics.track(.paywallDismissed(placement: placement))
            message = L10n.string(.subscriptionPackagePurchaseFailed, defaultValue: "Purchase failed. Please try again.")
        }
    }

    private func preferredPackageId(from packages: [SubscriptionPackage]) -> String? {
        packages.first(where: isQuarterly)?.id ??
        packages.first(where: isWeekly)?.id ??
        packages.first?.id
    }

    private func packagePriority(_ package: SubscriptionPackage) -> Int {
        if isQuarterly(package) { return 0 }
        if isWeekly(package) { return 1 }
        if isAnnual(package) { return 2 }
        if isMonthly(package) { return 3 }
        return 3
    }

    private func planTitle(for package: SubscriptionPackage) -> String {
        if isQuarterly(package) { return L10n.string(.subscriptionPackagePlanQuarterly, defaultValue: "3 Month Plan") }
        if isWeekly(package) { return L10n.string(.subscriptionPackagePlanWeekly, defaultValue: "Weekly Plan") }
        if isAnnual(package) { return L10n.string(.subscriptionPackagePlanAnnual, defaultValue: "Annual Plan") }
        if isMonthly(package) { return L10n.string(.subscriptionPackagePlanMonthly, defaultValue: "Monthly Plan") }
        if !package.title.isEmpty { return package.title }
        return L10n.string(.subscriptionPackagePlanFallback, defaultValue: "UNBOUND Pro")
    }

    private func badgeText(for package: SubscriptionPackage) -> String? {
        if isQuarterly(package) { return L10n.string(.subscriptionPackageBadgeQuarterly, defaultValue: "BEST START") }
        if isWeekly(package) { return L10n.string(.subscriptionPackageBadgeWeekly, defaultValue: "FLEXIBLE") }
        if isAnnual(package) { return L10n.string(.subscriptionPackageBadgeAnnual, defaultValue: "LOWEST MONTHLY") }
        return nil
    }

    private func detailLine(for package: SubscriptionPackage) -> String {
        if isQuarterly(package), let pricePerMonth = package.pricePerMonth {
            return L10n.format(.subscriptionPackageQuarterlyBilling, defaultValue: "%@/mo billed every 3 months", pricePerMonth)
        }
        if isAnnual(package), let pricePerMonth = package.pricePerMonth {
            return L10n.format(.subscriptionPackageAnnualBilling, defaultValue: "%@/mo billed annually", pricePerMonth)
        }
        if isWeekly(package) {
            return package.hasFreeTrial
                ? L10n.format(.subscriptionPackageWeeklyTrial, defaultValue: "%@ then weekly access", trialBadge(for: package).capitalized)
                : L10n.string(.subscriptionPackageWeeklyFlexible, defaultValue: "Flexible weekly access")
        }
        if isMonthly(package) {
            return package.hasFreeTrial
                ? L10n.format(.subscriptionPackageMonthlyTrial, defaultValue: "%@ then monthly access", trialBadge(for: package).capitalized)
                : L10n.string(.subscriptionPackageMonthlyFlexible, defaultValue: "Flexible monthly access")
        }
        return package.duration.isEmpty
            ? L10n.string(.subscriptionPackageGeneric, defaultValue: "Subscription")
            : package.duration
    }

    private func shouldShowPerMonth(for package: SubscriptionPackage) -> Bool {
        package.pricePerMonth != nil && (isQuarterly(package) || isAnnual(package))
    }

    private func isQuarterly(_ package: SubscriptionPackage) -> Bool {
        let haystack = normalized(package)
        return haystack.contains("3 month") ||
            haystack.contains("three month") ||
            haystack.contains("month_3") ||
            haystack.contains("3_month") ||
            haystack.contains("quarter") ||
            haystack.contains("tri_month")
    }

    private func isWeekly(_ package: SubscriptionPackage) -> Bool {
        let haystack = normalized(package)
        return haystack.contains("week") || haystack.contains("weekly")
    }

    private func isAnnual(_ package: SubscriptionPackage) -> Bool {
        let haystack = normalized(package)
        return haystack.contains("annual") || haystack.contains("year")
    }

    private func isMonthly(_ package: SubscriptionPackage) -> Bool {
        let haystack = normalized(package)
        return !isQuarterly(package) &&
            (haystack.contains("month") || haystack.contains("monthly"))
    }

    private func normalized(_ package: SubscriptionPackage) -> String {
        "\(package.id) \(package.productId) \(package.title) \(package.duration)".lowercased()
    }

    private func trialBadge(for package: SubscriptionPackage) -> String {
        if let duration = package.freeTrialDuration, !duration.isEmpty {
            return L10n.format(.subscriptionPackageTrialWithDuration, defaultValue: "%@ TRIAL", duration).uppercased()
        }
        return L10n.string(.subscriptionPackageTrial, defaultValue: "TRIAL")
    }

    private var quarterlyPitchTitle: String {
        L10n.string(.subscriptionPackagePitchQuarterlyTitle, defaultValue: "Start with the 3-month arc")
    }

    private var defaultPitchTitle: String {
        L10n.string(.subscriptionPackagePitchDefaultTitle, defaultValue: "Choose your training arc")
    }

    private var quarterlyPitchBody: String {
        L10n.string(
            .subscriptionPackagePitchQuarterlyBody,
            defaultValue: "Best value for your first block. Weekly is there if you want maximum flexibility."
        )
    }

    private var defaultPitchBody: String {
        L10n.string(
            .subscriptionPackagePitchDefaultBody,
            defaultValue: "Unlock training, progression, scans, squads, and recovery guidance."
        )
    }
}
