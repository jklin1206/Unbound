import SwiftUI

struct SubscriptionPackagePicker: View {
    @EnvironmentObject private var services: ServiceContainer

    let placement: String
    var ctaTitle: String = L10n.string(.subscriptionLockedCTA, defaultValue: "Subscribe to continue")
    var showsPitch: Bool = true
    var maxVisiblePackages: Int? = nil
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

            // The slot is always laid out and only fades — an `if` here makes
            // the whole cluster jump when switching to a no-trial plan.
            if !isLoading, !packages.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                    Text(L10n.string(.subscriptionPackageNoPaymentNow, defaultValue: "No payment now"))
                        .font(Font.unbound.bodyS.weight(.semibold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .opacity(selectedPackage?.hasFreeTrial == true ? 1 : 0)
            }

            UnboundButton(
                title: purchaseButtonTitle,
                variant: .prominent,
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

            // The selected plan's real terms, reference-style. Two lines are
            // always reserved so a shorter plan's terms don't shift the layout.
            if let selectedPackage, !isLoading {
                Text(legalLine(for: selectedPackage))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }

            // App Review requires functional Terms of Use + Privacy Policy
            // links on every subscription paywall.
            HStack(spacing: 14) {
                Link(L10n.string(.subscriptionPackageTermsLink, defaultValue: "Terms of Use"),
                     destination: AppConstants.Legal.termsURL)
                Text("·")
                Link(L10n.string(.subscriptionPackagePrivacyLink, defaultValue: "Privacy Policy"),
                     destination: AppConstants.Legal.privacyURL)
            }
            .font(Font.unbound.captionS)
            .foregroundStyle(Color.unbound.textTertiary)
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
                ForEach(displayedPackages) { package in
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

    // Every new user funnels through this picker, so the empty state must
    // never be a dead end: plans failing to load (offline, store outage,
    // products not yet live) always leaves a working retry.
    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string(.subscriptionPackageUnavailableTitle, defaultValue: "Plans didn't load"))
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(L10n.string(.subscriptionPackageUnavailableBody, defaultValue: "Check your connection and try again."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
            Button {
                UnboundHaptics.medium()
                Task { await loadPackages() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text(L10n.string(.subscriptionPackageRetry, defaultValue: "Try again"))
                        .font(Font.unbound.bodyS.weight(.semibold))
                }
                .foregroundStyle(Color.unbound.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .accessibilityIdentifier("paywall-retry")
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
            // Reference card: plan name over its price on the left, a filled
            // check on the right only when selected, the badge floating off
            // the top-right corner. Trial reassurance lives once, below the
            // cards — never repeated inside them.
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planTitle(for: package))
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(priceLine(for: package))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.unbound.accent))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(packageBackground(isSelected: isSelected))
            .overlay(alignment: .topTrailing) {
                if let badge = badgeText(for: package) {
                    planBadge(badge, emphasized: isSelected || isQuarterly(package))
                        .offset(x: -12, y: -9)
                }
            }
            .shadow(
                color: isSelected ? Color.unbound.accent.opacity(0.28) : .clear,
                radius: 12,
                x: 0,
                y: 0
            )
        }
        .buttonStyle(.plain)
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
            // Solid backing so the badge reads as sitting ON the card edge
            // when floated over its top-right corner.
            .background(Capsule().fill(Color.unbound.bg))
    }

    private func packageBackground(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.unbound.accent.opacity(0.13) : Color.unbound.surface.opacity(0.86))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.unbound.accent : Color.unbound.border,
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }

    private var purchaseButtonTitle: String {
        if isPurchasing {
            return L10n.string(.subscriptionPackageOpeningCheckout, defaultValue: "Opening checkout...")
        }
        if let selectedPackage {
            // The trial leads when the plan has one — "Start 7-day free trial"
            // converts the hesitant better than any arc language.
            if selectedPackage.hasFreeTrial {
                return L10n.format(
                    .subscriptionPackageStartTrial,
                    defaultValue: "Start %@ free trial",
                    compactTrialDuration(for: selectedPackage)
                )
            }
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

    private var displayedPackages: [SubscriptionPackage] {
        guard let maxVisiblePackages else { return orderedPackages }
        return Array(orderedPackages.prefix(maxVisiblePackages))
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
        if isAnnual(package) { return L10n.string(.subscriptionPackageBadgeAnnual, defaultValue: "BEST VALUE") }
        return nil
    }

    // The card's second line: just the price, with the per-month framing in
    // parentheses where it helps. Anything longer belongs outside the cards.
    private func priceLine(for package: SubscriptionPackage) -> String {
        if isQuarterly(package) || isAnnual(package), let pricePerMonth = package.pricePerMonth {
            let perMonth = L10n.format(.subscriptionPackagePricePerMonth, defaultValue: "%@/mo", pricePerMonth)
            return "\(package.price) (\(perMonth))"
        }
        return package.price
    }

    // Reference-style footer: the selected plan's real terms in one line,
    // e.g. "Free for 7 days, then $24.99 / 3 months ($8.33/mo). Cancel anytime."
    private func legalLine(for package: SubscriptionPackage) -> String {
        var terms = "\(package.price) / \(cadenceText(for: package))"
        if isQuarterly(package) || isAnnual(package), let pricePerMonth = package.pricePerMonth {
            let perMonth = L10n.format(.subscriptionPackagePricePerMonth, defaultValue: "%@/mo", pricePerMonth)
            terms += " (\(perMonth))"
        }
        if package.hasFreeTrial {
            let trial = package.freeTrialDuration?.lowercased() ?? "7 days"
            return L10n.format(.subscriptionPackageLegalTrial, defaultValue: "Free for %@, then %@. Cancel anytime.", trial, terms)
        }
        return L10n.format(.subscriptionPackageLegalDirect, defaultValue: "%@. Cancel anytime.", terms)
    }

    private func cadenceText(for package: SubscriptionPackage) -> String {
        if isQuarterly(package) { return L10n.string(.subscriptionPackageCadenceQuarterly, defaultValue: "3 months") }
        if isWeekly(package) { return L10n.string(.subscriptionPackageCadenceWeekly, defaultValue: "week") }
        if isAnnual(package) { return L10n.string(.subscriptionPackageCadenceAnnual, defaultValue: "year") }
        if isMonthly(package) { return L10n.string(.subscriptionPackageCadenceMonthly, defaultValue: "month") }
        return package.duration.lowercased()
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
        // Mutually exclusive with the others so a package whose lookup_key
        // contains "month" but holds a weekly/quarterly product (e.g. the
        // `$rc_monthly` package holding `unbound_weekly`) can't double-match.
        // Keeps classification correct no matter how an A/B variant offering
        // maps products to package keys.
        guard !isQuarterly(package), !isWeekly(package), !isAnnual(package) else { return false }
        let haystack = normalized(package)
        return haystack.contains("month") || haystack.contains("monthly")
    }

    private func normalized(_ package: SubscriptionPackage) -> String {
        "\(package.id) \(package.productId) \(package.title) \(package.duration)".lowercased()
    }

    /// "7 Days" → "7-day" for inline CTA copy.
    private func compactTrialDuration(for package: SubscriptionPackage) -> String {
        guard let duration = package.freeTrialDuration, !duration.isEmpty else {
            return L10n.string(.subscriptionPackageTrialDurationFallback, defaultValue: "7-day")
        }
        return duration
            .lowercased()
            .replacingOccurrences(of: " days", with: "-day")
            .replacingOccurrences(of: " day", with: "-day")
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
            defaultValue: "Best value for your first arc. Weekly is there if you want maximum flexibility."
        )
    }

    private var defaultPitchBody: String {
        L10n.string(
            .subscriptionPackagePitchDefaultBody,
            defaultValue: "Unlock training, progression, scans, squads, and recovery guidance."
        )
    }
}
