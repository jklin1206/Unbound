import Foundation
import UserNotifications

final class MilestoneNotificationNotifier {
    private let store: NotificationPreferencesStore
    private let center: any LocalNotificationScheduling
    private let notificationCenter: NotificationCenter
    private let planner = MilestoneNotificationPlanner()
    private var tokens: [NSObjectProtocol] = []

    init(
        store: NotificationPreferencesStore,
        center: any LocalNotificationScheduling,
        notificationCenter: NotificationCenter = .default
    ) {
        self.store = store
        self.center = center
        self.notificationCenter = notificationCenter
    }

    deinit {
        stop()
    }

    func start() {
        guard store.load().milestones.isEnabled else {
            stop()
            return
        }
        guard tokens.isEmpty else { return }

        let names: [Notification.Name] = [
            .badgeUnlocked,
            .rankAdvanced,
            .skillTierAdvanced,
            .progressionAdvanced,
            .titleUnlocked,
            .attributeRankUp
        ]

        tokens = names.map { name in
            notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handle(note)
            }
        }
    }

    func stop() {
        tokens.forEach { token in
            notificationCenter.removeObserver(token)
        }
        tokens.removeAll()
    }

    private func handle(_ notification: Notification) {
        guard store.load().milestones.isEnabled,
              let descriptor = planner.descriptor(for: notification)
        else {
            return
        }

        Task { [center] in
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus.allowsMilestoneScheduling else {
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [descriptor.identifier])
            try? await center.add(descriptor.makeRequest())
        }
    }
}

struct MilestoneNotificationPlanner {
    static let identifierPrefix = "com.unbound.milestone"

    func descriptor(for notification: Notification) -> LocalNotificationRequestDescriptor? {
        switch notification.name {
        case .badgeUnlocked:
            return badgeDescriptor(from: notification)
        case .rankAdvanced:
            return rankDescriptor(from: notification)
        case .skillTierAdvanced:
            return skillTierDescriptor(from: notification)
        case .progressionAdvanced:
            return progressionDescriptor(from: notification)
        case .titleUnlocked:
            return titleDescriptor(from: notification)
        case .attributeRankUp:
            return attributeDescriptor(from: notification)
        default:
            return nil
        }
    }

    private func badgeDescriptor(from notification: Notification) -> LocalNotificationRequestDescriptor? {
        guard let event = notification.userInfo?["event"] as? BadgeUnlockEvent else {
            return genericDescriptor(
                kind: "badge",
                subject: "unlocked",
                title: "[ SYSTEM ] PROOF REGISTERED",
                body: "A new badge is in your proof archive."
            )
        }

        return genericDescriptor(
            kind: "badge",
            subject: event.badge.id,
            title: "[ SYSTEM ] PROOF REGISTERED",
            body: "\(event.badge.displayName) is now in your archive."
        )
    }

    private func rankDescriptor(from notification: Notification) -> LocalNotificationRequestDescriptor? {
        guard let event = notification.userInfo?["event"] as? RankAdvance else {
            return genericDescriptor(
                kind: "rank",
                subject: "advanced",
                title: "[ SYSTEM ] RANK ADVANCED",
                body: "A movement crossed into a new rank."
            )
        }

        return genericDescriptor(
            kind: "rank",
            subject: "\(event.exerciseKey)-\(event.toRank.token)",
            title: "[ SYSTEM ] RANK ADVANCED",
            body: "\(event.displayName): \(event.fromRank.displayName) → \(event.toRank.displayName)."
        )
    }

    private func skillTierDescriptor(from notification: Notification) -> LocalNotificationRequestDescriptor? {
        guard let advance = notification.object as? SkillTierAdvance else {
            return genericDescriptor(
                kind: "skill",
                subject: "advanced",
                title: "[ SYSTEM ] SKILL ADVANCED",
                body: "A skill reached a new rank."
            )
        }

        return genericDescriptor(
            kind: "skill",
            subject: advance.id,
            title: "[ SYSTEM ] SKILL ADVANCED",
            body: "New rank: \(advance.to.displayName)."
        )
    }

    private func progressionDescriptor(from notification: Notification) -> LocalNotificationRequestDescriptor? {
        guard let event = notification.userInfo?["event"] as? ProgressionAdvance else {
            return genericDescriptor(
                kind: "progression",
                subject: "advanced",
                title: "[ SYSTEM ] LOAD INCREASED",
                body: "Your next working weight is ready."
            )
        }

        return genericDescriptor(
            kind: "progression",
            subject: "\(event.exerciseKey)-\(event.newWeightKg)",
            title: "[ SYSTEM ] LOAD INCREASED",
            body: "\(event.displayName): \(WeightPlatePolicy.formatLoggedWeightWithUnit(event.newWeightKg, separator: " ")) is next."
        )
    }

    private func titleDescriptor(from notification: Notification) -> LocalNotificationRequestDescriptor? {
        guard let titleId = notification.object as? TitleID else {
            return genericDescriptor(
                kind: "title",
                subject: "unlocked",
                title: "[ SYSTEM ] TITLE UNLOCKED",
                body: "A new title is ready on your profile."
            )
        }

        let displayName = TitleCatalog.displayName(for: titleId)
        return genericDescriptor(
            kind: "title",
            subject: displayName,
            title: "[ SYSTEM ] TITLE UNLOCKED",
            body: "\(displayName) is ready to equip."
        )
    }

    private func attributeDescriptor(from notification: Notification) -> LocalNotificationRequestDescriptor? {
        guard let event = notification.object as? AttributeRankUpEvent else {
            return genericDescriptor(
                kind: "attribute",
                subject: "advanced",
                title: "[ SYSTEM ] BUILD ADVANCED",
                body: "An attribute reached a new rank."
            )
        }

        return genericDescriptor(
            kind: "attribute",
            subject: "\(event.axis.rawValue)-\(event.toTitle.token)",
            title: "[ SYSTEM ] BUILD ADVANCED",
            body: "\(event.axis.displayName): \(event.fromTitle.displayName) → \(event.toTitle.displayName)."
        )
    }

    private func genericDescriptor(
        kind: String,
        subject: String,
        title: String,
        body: String
    ) -> LocalNotificationRequestDescriptor {
        LocalNotificationRequestDescriptor(
            identifier: identifier(kind: kind, subject: subject),
            title: title,
            body: body,
            trigger: .timeInterval(1, repeats: false)
        )
    }

    private func identifier(kind: String, subject: String) -> String {
        "\(Self.identifierPrefix).\(sanitized(kind)).\(sanitized(subject))"
    }

    private func sanitized(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = raw.lowercased().unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
        return String(collapsed.prefix(80))
    }
}

private extension UNAuthorizationStatus {
    var allowsMilestoneScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
