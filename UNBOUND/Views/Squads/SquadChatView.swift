import SwiftUI

struct SquadChatView: View {
    let squad: Squad
    let roster: [SquadMember]
    let initialMessages: [SquadMessage]
    let currentUserId: UUID?
    let messageService: SquadMessageService
    let onMessagesChanged: (([SquadMessage]) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [SquadMessage]
    @State private var draft = ""
    @State private var reportingMessage: SquadMessage?
    @FocusState private var isDraftFocused: Bool

    init(
        squad: Squad,
        roster: [SquadMember],
        initialMessages: [SquadMessage],
        currentUserId: UUID?,
        messageService: SquadMessageService = .shared,
        onMessagesChanged: (([SquadMessage]) -> Void)? = nil
    ) {
        self.squad = squad
        self.roster = roster
        self.initialMessages = initialMessages
        self.currentUserId = currentUserId
        self.messageService = messageService
        self.onMessagesChanged = onMessagesChanged
        _messages = State(initialValue: initialMessages.sorted { $0.createdAt < $1.createdAt })
    }

    var body: some View {
        messageList
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider().overlay(Color.unbound.borderSubtle)
                    composeBar
                }
            }
        .navigationTitle(squad.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isDraftFocused = false }
            }
        }
        .confirmationDialog(
            "Message options",
            isPresented: Binding(
                get: { reportingMessage != nil },
                set: { if !$0 { reportingMessage = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Report Message", role: .destructive) {
                reportCurrentMessage()
            }
            Button("Block User", role: .destructive) {
                reportCurrentMessage()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reports help keep crew chat safe.")
        }
        .task(id: squad.id) {
            await refreshMessagesLoop()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        bubble(for: message)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
            .background(Color.unbound.bg)
            .onChange(of: messages.count) { _, _ in
                scrollToLastMessage(proxy)
            }
            .onChange(of: isDraftFocused) { _, isFocused in
                guard isFocused else { return }
                scrollToLastMessage(proxy)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func bubble(for message: SquadMessage) -> some View {
        SquadMessageBubble(
            message: message,
            authorName: displayName(for: message.authorUserId),
            isMine: message.authorUserId == currentUserId,
            onReact: { emoji in addReaction(emoji, to: message.id) },
            onReport: { reportingMessage = message }
        )
        .id(message.id)
    }

    private var composeBar: some View {
        HStack(spacing: 10) {
            TextField("Message the crew", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .focused($isDraftFocused)
                .submitLabel(.send)
                .onSubmit { send() }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.unbound.surfaceElevated.opacity(0.92)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                .onChange(of: draft) { _, newValue in
                    if newValue.count > 280 {
                        draft = String(newValue.prefix(280))
                    }
                }

            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(canSend ? Color.unbound.accent : Color.unbound.surfaceElevated))
                    .foregroundStyle(canSend ? Color.unbound.bg : Color.unbound.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(12)
        .background(Color.unbound.bg.opacity(0.96))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let pending = SquadMessage(
            id: UUID(),
            squadId: squad.id,
            authorUserId: currentUserId,
            kind: .text(.init(body: String(body.prefix(1000)))),
            reactions: [],
            createdAt: Date()
        )
        messages.append(pending)
        publishMessages()
        draft = ""
        isDraftFocused = true

        Task {
            let saved = await messageService.sendMessage(pending)
            await MainActor.run {
                replaceMessage(id: pending.id, with: saved)
            }
        }
    }

    private func addReaction(_ emoji: SquadMessageReaction.Emoji, to messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              let userId = currentUserId else { return }
        let alreadyReacted = messages[index].reactions.contains { $0.userId == userId && $0.emoji == emoji }
        if alreadyReacted {
            messages[index].reactions.removeAll { $0.userId == userId && $0.emoji == emoji }
        } else {
            messages[index].reactions.append(
                SquadMessageReaction(
                    id: UUID(),
                    messageId: messageId,
                    userId: userId,
                    emoji: emoji,
                    createdAt: Date()
                )
            )
        }
        publishMessages()

        Task {
            await messageService.setReaction(
                emoji: emoji,
                messageId: messageId,
                squadId: squad.id,
                userId: userId,
                shouldAdd: !alreadyReacted
            )
        }
    }

    private func scrollToLastMessage(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation(.snappy) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func displayName(for userId: UUID?) -> String {
        guard let userId else { return "UNBOUND" }
        return roster.first(where: { $0.userId == userId })?.displayName ?? "Crewmate"
    }

    @MainActor
    private func refreshMessagesLoop() async {
        await refreshMessages()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await refreshMessages()
        }
    }

    @MainActor
    private func refreshMessages() async {
        let merged = await messageService.fetchRecent(
            squadId: squad.id,
            fallbackMessages: messages,
            limit: 80
        )
        messages = merged.sorted { $0.createdAt < $1.createdAt }
        publishMessages()
    }

    private func replaceMessage(id: UUID, with saved: SquadMessage) {
        messages.removeAll { $0.id == id || $0.id == saved.id }
        messages.append(saved)
        messages.sort { $0.createdAt < $1.createdAt }
        publishMessages()
    }

    private func publishMessages() {
        onMessagesChanged?(messages.sorted { $0.createdAt > $1.createdAt })
    }

    private func reportCurrentMessage() {
        guard let message = reportingMessage else { return }
        Task {
            await messageService.report(
                messageId: message.id,
                reporterUserId: currentUserId,
                reason: "inappropriate"
            )
        }
    }
}

struct SquadMessageBubble: View {
    let message: SquadMessage
    let authorName: String
    let isMine: Bool
    let onReact: (SquadMessageReaction.Emoji) -> Void
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
            Text(authorName.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(alignment: .leading, spacing: 8) {
                messageContent
                if !message.reactions.isEmpty {
                    reactionSummary
                }
                reactionStrip
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: bubbleColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isMine ? Color.unbound.accent.opacity(0.36) : Color.unbound.borderSubtle, lineWidth: 1)
            )
            .frame(maxWidth: 310, alignment: isMine ? .trailing : .leading)
            .contextMenu {
                Button("Report", role: .destructive, action: onReport)
                Button("Block User", role: .destructive, action: onReport)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    private var bubbleColors: [Color] {
        if isMine {
            return [
                Color.unbound.accent.opacity(0.22),
                Color.unbound.surface.opacity(0.92),
                Color.unbound.bg.opacity(0.66)
            ]
        }
        return [
            Color.unbound.surfaceElevated.opacity(0.92),
            Color.unbound.surface.opacity(0.88),
            Color.unbound.bg.opacity(0.62)
        ]
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.kind {
        case .text(let payload):
            Text(payload.body)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
        case .workout(let payload):
            card("Workout completed", payload.title, payload.durationMinutes.map { "\($0) min" })
        case .pr(let payload):
            card(payload.title, payload.detail, nil)
        case .vowSeal(let payload):
            card("Binding Vow cleared", payload.title, nil)
        case .challengeEvent(let payload):
            card(payload.title, payload.detail, nil)
        case .savedWorkoutShare(let payload):
            card("Saved workout shared", payload.workoutTitle, "Add to my library")
        case .system(let payload):
            Text(payload.body)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    private func card(_ title: String, _ detail: String, _ meta: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.accent)
            Text(detail)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            if let meta {
                Text(meta)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var reactionSummary: some View {
        let grouped = Dictionary(grouping: message.reactions, by: \.emoji)
        return HStack(spacing: 6) {
            ForEach(SquadMessageReaction.Emoji.allCases.filter { grouped[$0] != nil }, id: \.self) { emoji in
                Text("\(emoji.rawValue) \(grouped[emoji]?.count ?? 0)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
            }
        }
    }

    private var reactionStrip: some View {
        HStack(spacing: 4) {
            ForEach(SquadMessageReaction.Emoji.allCases, id: \.self) { emoji in
                Button {
                    onReact(emoji)
                } label: {
                    Text(emoji.rawValue)
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.8)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SquadMessagePreviewRow: View {
    let message: SquadMessage
    let authorName: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconTint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(iconTint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            iconTint.opacity(0.12),
                            Color.unbound.surface.opacity(0.88),
                            Color.unbound.bg.opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var title: String {
        switch message.kind {
        case .text: return authorName
        case .workout: return "Workout"
        case .pr: return "PR"
        case .vowSeal: return "Vow"
        case .challengeEvent: return "Challenge"
        case .savedWorkoutShare: return "Saved workout"
        case .system: return "System"
        }
    }

    private var subtitle: String {
        switch message.kind {
        case .text(let payload): return payload.body
        case .workout(let payload): return payload.title
        case .pr(let payload): return payload.detail
        case .vowSeal(let payload): return payload.title
        case .challengeEvent(let payload): return payload.detail
        case .savedWorkoutShare(let payload): return payload.workoutTitle
        case .system(let payload): return payload.body
        }
    }

    private var iconName: String {
        switch message.kind {
        case .text: return "bubble.left.fill"
        case .workout: return "figure.strengthtraining.traditional"
        case .pr: return "bolt.fill"
        case .vowSeal: return "seal.fill"
        case .challengeEvent: return "flag.checkered"
        case .savedWorkoutShare: return "square.and.arrow.up.fill"
        case .system: return "info.circle.fill"
        }
    }

    private var iconTint: Color {
        switch message.kind {
        case .challengeEvent, .pr: return Color.unbound.warnOrange
        case .system: return Color.unbound.textTertiary
        default: return Color.unbound.accent
        }
    }
}

struct ChallengeDashboardRow: View {
    let challenge: FriendChallenge
    let roster: [SquadMember]
    let currentUserId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CO-OP PAIR")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(challenge.kind.displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Text(challenge.isPending ? "INVITED" : "ACTIVE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(challenge.isPending ? Color.unbound.warnOrange : Color.unbound.accent)
            }

            HStack(spacing: 10) {
                progressColumn(name: displayName(for: challenge.challengerId), progress: challenge.challengerProgress)
                progressColumn(name: displayName(for: challenge.challengedId), progress: challenge.challengedProgress)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.warnOrange.opacity(challenge.isPending ? 0.13 : 0.05),
                            Color.unbound.surface.opacity(0.90),
                            Color.unbound.bg.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    challenge.isPending ? Color.unbound.warnOrange.opacity(0.30) : Color.unbound.borderSubtle,
                    lineWidth: 1
                )
        )
    }

    private func progressColumn(name: String, progress: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
            ProgressView(value: min(1, Double(progress) / 7.0))
                .tint(Color.unbound.accent)
            Text("\(progress) sessions")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private func displayName(for userId: UUID) -> String {
        roster.first(where: { $0.userId == userId })?.displayName ?? "Crewmate"
    }
}
