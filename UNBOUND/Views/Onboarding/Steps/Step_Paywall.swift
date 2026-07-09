import SwiftUI

// MARK: - Step_Paywall
//
// Hard paywall in the trial-timeline shape (Blinkist-style), dressed in the
// world the previous 38 screens built: the open-gate art bleeds in from the
// top, the header names the user's handle and the arc they just configured,
// and the pact they signed one screen group ago is what the gate "answered".
// Below that: a three-step "how the free trial works" timeline (today /
// reminder / billing date), then the RevenueCat-driven
// `SubscriptionPackagePicker` plus a restore link (App Review 3.1.1).
// Packages + pricing come from RevenueCat Offerings, so edits and A/B
// experiments are dashboard-configured with no app release. The trial
// headline, timeline, and billing date all track the plan selected in the
// picker: a no-trial plan (weekly) drops the free-trial claim and the
// timeline for honest billing-starts-today copy, so this screen never
// promises a trial the selected plan does not carry (App Review 2.3.1/3.1.2).

struct Step_Paywall: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onUnlock: () -> Void

    @State private var hasAnimated = false
    @State private var glow = false
    @State private var showPromo = false
    /// The plan currently highlighted in the picker. Drives the trial copy so
    /// the headline, timeline, and billing date never claim a free trial the
    /// selected plan does not carry.
    @State private var selectedPackage: SubscriptionPackage?
    @EnvironmentObject var services: ServiceContainer

    var body: some View {
        ZStack {
            background

            // RevenueCat-template anatomy: hero and features read as one
            // continuous block from the top; the purchase cluster (plans, CTA,
            // legal) anchors to the bottom. Exactly one flexible gap between
            // them — two symmetric voids read broken, one reads intentional.
            // Scrollable so the purchase cluster (plans, CTA, legal disclosure,
            // Terms/Privacy, Restore) is never clipped on shorter devices, while
            // minHeight keeps the flexible-gap distribution on tall screens.
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                            .padding(.top, 52)

                        // Equal flexible gaps float the timeline in the space between
                        // the hero and the purchase cluster, so leftover height reads
                        // as even breathing room instead of one dead band.
                        Spacer(minLength: 24)

                        if showsTrialCopy {
                            trialTimeline
                                .padding(.horizontal, 4)
                        }

                        Spacer(minLength: 24)

                        ctaSection
                            .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            // Exit lives top-right, out of the sell. On a hard gate "close"
            // routes to the exit promo — the discount is the answer to leaving.
            VStack {
                HStack {
                    Spacer()
                    Button {
                        UnboundHaptics.soft()
                        showPromo = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.unbound.surface.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.onboarding("paywall.close", defaultValue: "Maybe later"))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
        }
        .toolbar(.hidden, for: .navigationBar)
        .opacity(hasAnimated ? 1 : 0)
        .onAppear {
            services.analytics.track(.paywallViewed(placement: AppConstants.Paywall.hardGate))
            withAnimation(.easeOut(duration: 0.4)) { hasAnimated = true }
            glow = true
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--paywall-show-promo") {
                showPromo = true
            }
            #endif
        }
        .fullScreenCover(isPresented: $showPromo) {
            PromoExitSheet(onUnlock: onUnlock)
                .environmentObject(services)
        }
    }

    // MARK: Background

    // The open-gate art (chapterPath's payoff frame) bleeds in from the top
    // and dissolves into the base color before the plan cards, so the money
    // screen reads as the same world as the pact — not a template swap.
    private var background: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            TechGridBackground(opacity: 0.14)
                .ignoresSafeArea()

            Color.clear
                .frame(height: 330)
                .frame(maxWidth: .infinity)
                .overlay(
                    Image("onboarding_path_open_gate")
                        .resizable()
                        .scaledToFill()
                )
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.52),
                            Color.unbound.bg.opacity(0.5),
                            Color.unbound.bg
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .top)

            RadialGradient(
                colors: [Color.unbound.accent.opacity(glow ? 0.16 : 0.08), Color.clear],
                center: .top,
                startRadius: 24,
                endRadius: 440
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glow)
        }
    }

    // MARK: Header

    // Personalized close: the gate the user signed open, their handle, the
    // arc shape they chose — then the trial promise.
    private var header: some View {
        VStack(spacing: 9) {
            // Impact violet, not base accent: small purple text over the
            // bright gate art needs the lighter tone plus a hard dark shadow
            // to stay AA-readable.
            Text(L10n.onboarding("paywall.eyebrow", defaultValue: "THE GATE IS OPEN"))
                .font(Font.unbound.monoS)
                .tracking(2.4)
                .foregroundStyle(Color.unbound.impact)
                .shadow(color: Color.black.opacity(0.85), radius: 3, y: 1)
                .shadow(color: Color.unbound.accent.opacity(0.5), radius: 10)

            Text(headlineText)
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: Color.black.opacity(0.6), radius: 6, y: 1)

            Text(accessLineText)
                .font(Font.unbound.bodyL.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.92))
                .shadow(color: Color.black.opacity(0.5), radius: 4)

            if let arcMeta = arcMetaText {
                Text(arcMeta)
                    .font(Font.unbound.monoS)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
    }

    private var headlineText: String {
        let handle = flow.displayHandle.trimmingCharacters(in: .whitespaces)
        if handle.isEmpty {
            return L10n.onboarding("paywall.headline", defaultValue: "Your first arc is loaded.")
        }
        return L10n.onboardingFormat("paywall.headline.named", defaultValue: "Your first arc is loaded, @%@.", handle)
    }

    // "3 DAYS / WEEK · 45 MINUTES" — the plan they configured, echoed on the
    // screen where they decide whether to keep it.
    private var arcMetaText: String? {
        guard let frequency = flow.targetFrequency?.numericCount,
              let length = flow.sessionLength?.displayName else { return nil }
        let days = L10n.onboardingFormat("paywall.meta.days", defaultValue: "%d DAYS / WEEK", frequency)
        return "\(days) · \(length.uppercased())"
    }

    // MARK: Trial copy

    // Trial copy only when the selected plan actually carries a free trial.
    // `nil` (packages still loading) defaults to the trial copy because the
    // picker's default selection is a trial plan; the honest swap happens the
    // moment a no-trial plan (weekly) is highlighted.
    private var showsTrialCopy: Bool {
        selectedPackage?.hasFreeTrial ?? true
    }

    // The sub-headline under the hero: the trial promise when the selected
    // plan has one, an honest immediate-billing line when it does not.
    private var accessLineText: String {
        if showsTrialCopy {
            return L10n.onboardingFormat("paywall.trialLine", defaultValue: "First %d days free.", trialDays)
        }
        return L10n.onboarding("paywall.noTrialLine", defaultValue: "Billing starts today. Cancel anytime.")
    }

    /// Trial length in days for the selected plan. `SubscriptionPackage` only
    /// exposes the store's display string ("7 Days"), so parse it when it is
    /// day-denominated. Every live UNBOUND trial is 7 days, so 7 is the
    /// fallback for any other shape rather than a guess at all period units;
    /// revisit if a non-7-day trial ships.
    private var trialDays: Int {
        guard let duration = selectedPackage?.freeTrialDuration?.lowercased(),
              duration.contains("day"),
              let days = Int(duration.split(separator: " ").first ?? ""),
              days > 0 else { return 7 }
        return days
    }

    /// The reminder lands two days before billing, clamped for short trials.
    private var reminderDay: Int { max(1, trialDays - 2) }

    // MARK: Trial timeline

    // "How the free trial works" as three milestones down a rail: unlock
    // today, reminder before it ends, billing on a concrete date. The dated
    // last step is what makes the trial feel safe to start. Only rendered
    // when the selected plan carries a trial (see `showsTrialCopy`).
    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                icon: "lock.open.fill",
                title: "Today",
                detail: "Everything unlocks: your program, the skill tree, rank gates, vows.",
                isLast: false
            )
            timelineRow(
                icon: "bell.fill",
                title: "Day \(reminderDay): Reminder",
                detail: "We'll remind you that your trial is ending soon.",
                isLast: false
            )
            timelineRow(
                icon: "crown.fill",
                title: "Day \(trialDays): Billing starts",
                detail: "You'll be charged on \(billingDateText). Cancel anytime before.",
                isLast: true
            )
        }
    }

    private func timelineRow(icon: String, title: String, detail: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.unbound.accent.opacity(0.35), radius: 8)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                if isLast {
                    // The rail runs past the last node and fades out, so the
                    // track reads as one continuous piece (reference detail).
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.unbound.accent.opacity(0.45), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 30)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.unbound.accent.opacity(0.75), Color.unbound.accent.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font.unbound.bodyL.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            .padding(.bottom, isLast ? 0 : 26)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var billingDateText: String {
        let date = Calendar.current.date(byAdding: .day, value: trialDays, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: CTA

    // The picker renders the selected plan's own legal line; restore lives
    // right below it - a reinstalling subscriber's only pre-purchase surface
    // is this hard gate, and App Review expects a restore path here too.
    private var ctaSection: some View {
        VStack(spacing: 10) {
            SubscriptionPackagePicker(
                placement: AppConstants.Paywall.hardGate,
                ctaTitle: "Start my first arc",
                showsPitch: false,
                maxVisiblePackages: 2,
                onPurchased: onUnlock,
                onSelectedPackageChange: { package in
                    withAnimation(.easeInOut(duration: 0.2)) { selectedPackage = package }
                }
            )

            RestorePurchasesButton(onRestored: onUnlock)
        }
    }

}
