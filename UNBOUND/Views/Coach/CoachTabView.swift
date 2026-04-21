import SwiftUI

struct CoachTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var viewModel = CoachViewModel()
    @State private var showPaywall = false
    @State private var draft: String = ""
    @State private var toastEntry: AppliedCoachAction?

    private let suggestionChips = [
        "Build my programme",
        "Swap an exercise",
        "Deload week",
        "Why is my bench stuck?",
        "What should I do next session?",
        "First time setup"
    ]

    init(prefill: String? = nil) {
        if let prefill {
            _draft = State(initialValue: prefill)
        }
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messageList
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("COACH")
                    .font(Font.unbound.captionS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
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

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("Your coach")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer()
            NavigationLink {
                CoachActionHistoryView()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.unbound.surface)
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.unbound.border, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WHAT'S ON YOUR MIND?")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Ask the coach anything — swaps, deloads, plateaus, what to do today.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 10) {
                    ForEach(suggestionChips, id: \.self) { prompt in
                        Button {
                            draft = prompt
                            UnboundHaptics.soft()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .semibold))
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
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.unbound.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.unbound.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
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
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: Input

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
                        .strokeBorder(Color.unbound.border, lineWidth: 1)
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
                        Circle().strokeBorder(Color.unbound.border, lineWidth: 1)
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

    // MARK: Locked overlay

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

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: CoachMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
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
                        message.role == .user ? Color.unbound.accent.opacity(0.4) : Color.unbound.border,
                        lineWidth: 1
                    )
            )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack {
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
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
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
