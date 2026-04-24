import SwiftUI

// MARK: - CoachTabView
//
// AI chat with the UNBOUND coach. Real messaging (per the
// `project_unbound_redesign_decisions` memory — no mascot, no character
// portrait). User sends questions, coach responds with text + applied
// program actions (swap exercise, deload, etc.) that can be undone via
// a toast.
//
// Visual language matches Home / Program / Profile:
//   - Inline top bar (custom, no system nav title)
//   - Empty state has grouped suggestion chips (Training / Body / Strategy)
//   - Quick-ask strip appears above input once a conversation is active
//   - Message bubbles carry a subtle timestamp + tier-tinted applied
//     actions chip so program edits feel earned, not buried

struct CoachTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var viewModel = CoachViewModel()
    @State private var showPaywall = false
    @State private var draft: String = ""
    @State private var toastEntry: AppliedCoachAction?

    init(prefill: String? = nil) {
        if let prefill {
            _draft = State(initialValue: prefill)
        }
    }

    // Grouped prompt suggestions. Flat list felt like a menu — grouped
    // reads like a coach offering you three lanes of help.
    private let suggestionGroups: [SuggestionGroup] = [
        SuggestionGroup(
            label: "TRAINING",
            prompts: [
                "What should I do next session?",
                "Swap an exercise",
                "Deload week"
            ]
        ),
        SuggestionGroup(
            label: "BODY",
            prompts: [
                "Why is my bench stuck?",
                "Which muscle is lagging?",
                "Recovery check"
            ]
        ),
        SuggestionGroup(
            label: "STRATEGY",
            prompts: [
                "Build my programme",
                "First-time setup",
                "Break my plateau"
            ]
        )
    ]

    private let quickActions = [
        "Why am I stuck?",
        "Swap today's workout",
        "What should I do next?"
    ]

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                    quickAskStrip
                }
                inputBar
            }

            if !services.entitlement.isEntitled {
                lockedOverlay
            }

            if let entry = toastEntry {
                VStack {
                    Spacer()
                    ActionUndoToast(
                        entry: entry,
                        onUndo: {
                            Task { await viewModel.undoLast(userId: userId) }
                        },
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.3)) { toastEntry = nil }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 94)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(20)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPaywall) {
            PaywallPlaceholderView()
                .environmentObject(services)
        }
        .task {
            await viewModel.load(userId: userId)
        }
        .onChange(of: viewModel.lastApplied) { _, newValue in
            guard let newValue else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                toastEntry = newValue
            }
        }
    }

    private var userId: String {
        services.auth.currentUserId ?? "anonymous"
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("COACH")
                .font(Font.unbound.titleS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)

            statusPill

            Spacer()

            NavigationLink {
                CoachActionHistoryView()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    /// Tiny pill next to the COACH title that mirrors the coach's state.
    /// Violet when idle (standing by), animated when typing.
    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(viewModel.isTyping ? Color.unbound.accent : Color.unbound.accent.opacity(0.55))
                .frame(width: 6, height: 6)
                .shadow(
                    color: Color.unbound.accent.opacity(viewModel.isTyping ? 0.9 : 0.35),
                    radius: viewModel.isTyping ? 5 : 2
                )
            Text(viewModel.isTyping ? "TYPING" : "READY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(
                    viewModel.isTyping ? Color.unbound.accent : Color.unbound.textTertiary
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color.unbound.surface)
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.isTyping)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT'S ON YOUR MIND?")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Ask anything. Program edits, plateaus, body-part focus, strategy calls — the coach has your full context.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                ForEach(suggestionGroups) { group in
                    suggestionGroupView(group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func suggestionGroupView(_ group: SuggestionGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.label)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.accent)

            VStack(spacing: 8) {
                ForEach(group.prompts, id: \.self) { prompt in
                    suggestionChip(prompt: prompt)
                }
            }
        }
    }

    private func suggestionChip(prompt: String) -> some View {
        Button {
            UnboundHaptics.soft()
            draft = prompt
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text(prompt)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if viewModel.isTyping {
                        TypingIndicator()
                    }
                    Color.clear.frame(height: 6).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Quick-ask strip

    private var quickAskStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickActions, id: \.self) { action in
                    Button {
                        UnboundHaptics.soft()
                        draft = action
                    } label: {
                        Text(action)
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.unbound.surface)
                            )
                            .overlay(
                                Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask the coach…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .tint(Color.unbound.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSend ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(canSend ? Color.unbound.accent : Color.unbound.surface)
                    )
                    .overlay(
                        Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                    .shadow(
                        color: canSend ? Color.unbound.accent.opacity(0.45) : .clear,
                        radius: 8, y: 2
                    )
            }
            .disabled(!canSend)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.unbound.bg
                .overlay(Rectangle().fill(Color.unbound.borderSubtle).frame(height: 1), alignment: .top)
        )
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isTyping
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        UnboundHaptics.medium()
        draft = ""
        Task {
            await viewModel.send(text, userId: userId, analytics: services.analytics)
        }
    }

    // MARK: - Locked overlay

    private var lockedOverlay: some View {
        ZStack {
            Color.unbound.bg.opacity(0.85).ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text("Coach is Pro")
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Unlimited chats, context-aware answers, programme edits.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                UnboundButton(title: "Unlock Coach", icon: "arrow.right") {
                    showPaywall = true
                }
                .padding(.horizontal, 28)
            }
        }
    }
}

// MARK: - Suggestion group

private struct SuggestionGroup: Identifiable {
    let id = UUID()
    let label: String
    let prompts: [String]
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: CoachMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 40)
            } else {
                coachBadge
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(message.content)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !message.appliedActions.isEmpty {
                    Divider().background(Color.unbound.borderSubtle)
                    ForEach(message.appliedActions) { action in
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.unbound.accent)
                            Text(action.description)
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }
                    }
                }

                Text(timestampLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(message.role == .user ? Color.unbound.accent.opacity(0.18) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        message.role == .user ? Color.unbound.accent.opacity(0.4) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    private var coachBadge: some View {
        ZStack {
            Circle()
                .fill(Color.unbound.surface)
            Circle()
                .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1)
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        }
        .frame(width: 22, height: 22)
    }

    private var timestampLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: message.timestamp).lowercased()
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Color.unbound.surface)
                Circle().strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .frame(width: 22, height: 22)

            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.unbound.textSecondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(phase > CGFloat(i) * 0.3 ? 1.2 : 0.7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class CoachViewModel: ObservableObject {
    @Published var messages: [CoachMessage] = []
    @Published var isTyping = false
    @Published var lastApplied: AppliedCoachAction?

    private let client: CoachClientProtocol = MockCoachClient.shared
    private let database = DatabaseService.shared
    private let executor = CoachActionExecutor.shared

    func load(userId: String) async {
        let existing: [CoachMessage] = (try? await database.query(
            collection: "coach_messages",
            field: "userId",
            isEqualTo: userId,
            orderBy: "timestamp",
            descending: false,
            limit: nil
        )) ?? []
        messages = existing
    }

    func send(_ text: String, userId: String, analytics: any AnalyticsServiceProtocol) async {
        let userMsg = CoachMessage(userId: userId, role: .user, content: text)
        messages.append(userMsg)
        try? await database.create(userMsg, collection: "coach_messages", documentId: userMsg.id.uuidString)
        analytics.track(.coachMessageSent(promptKind: promptKind(for: text)))

        isTyping = true
        let context = await PTContextBuilder.shared.buildCompact(userId: userId)
        do {
            let response = try await client.send(messages: messages, context: context)
            let assistantMsg = CoachMessage(
                userId: userId,
                role: .assistant,
                content: response.text,
                appliedActions: response.actions
            )
            messages.append(assistantMsg)
            try? await database.create(assistantMsg, collection: "coach_messages", documentId: assistantMsg.id.uuidString)

            for action in response.actions {
                try? await executor.apply(action, userId: userId)
                if let newest = executor.undoStack.last {
                    lastApplied = newest
                }
            }
        } catch {
            let errorMsg = CoachMessage(userId: userId, role: .assistant, content: "Connection trouble. Try again.")
            messages.append(errorMsg)
        }
        isTyping = false
    }

    func undoLast(userId: String) async {
        try? await executor.undo(userId: userId)
        lastApplied = nil
    }

    private func promptKind(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("stuck") || lower.contains("stalled") { return "plateau" }
        if lower.contains("swap") || lower.contains("replace") { return "swap" }
        if lower.contains("deload") { return "deload" }
        if lower.contains("next session") { return "next_session" }
        if lower.contains("build") { return "build_programme" }
        return "other"
    }
}
