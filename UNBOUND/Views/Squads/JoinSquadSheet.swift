// UNBOUND/Views/Squads/JoinSquadSheet.swift
import SwiftUI

struct JoinSquadSheet: View {
    /// Pre-filled invite code — used by the universal-link flow.
    var prefilledCode: String? = nil
    var onCompleted: (() -> Void)?

    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    @State private var error: String?
    @State private var isJoining = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Enter invite code.")
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("6-character code", text: $code)
                            .textCase(.uppercase)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .font(.system(size: 22, weight: .heavy, design: .monospaced))
                            .tracking(6)
                            .focused($isCodeFocused)
                            .submitLabel(.join)
                            .onSubmit { submitIfReady() }
                            .onChange(of: code) { _, newValue in
                                // Strip non-alphanumeric, uppercase, cap at 6 chars.
                                let filtered = newValue
                                    .uppercased()
                                    .filter { $0.isLetter || $0.isNumber }
                                    .prefix(6)
                                let result = String(filtered)
                                if result != newValue { code = result }
                            }
                            .squadInputChrome(isFocused: isCodeFocused)

                        Text("\(code.count)/6")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let error {
                        Text(error)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.alert)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
            }
            // The footer must NOT ride the keyboard - lifted, it collides with
            // the keyboard toolbar's Done button. It stays seated at the screen
            // bottom (hidden while typing); the keyboard's return key submits.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Join Squad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let prefilled = prefilledCode {
                    let filtered = prefilled
                        .uppercased()
                        .filter { $0.isLetter || $0.isNumber }
                        .prefix(6)
                    code = String(filtered)
                }
                isCodeFocused = code.count != 6
            }
        }
    }

    private var footer: some View {
        UnboundButton(
            title: isJoining ? "Joining…" : "Join Squad",
            isEnabled: canJoin
        ) {
            submitIfReady()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.unbound.bg)
    }

    private var canJoin: Bool {
        code.count == 6 && !isJoining
    }

    private func submitIfReady() {
        guard canJoin else { return }
        Task { await join() }
    }

    @MainActor
    private func join() async {
        // Squads are cloud-only (RLS-gated RPCs); an anonymous local UUID can't
        // join. Require a real session so the failure reads "Sign in…" instead of
        // a dead RPC error. Forced auth at onboarding means this normally passes.
        guard let userId = services.auth.currentUserId, await services.auth.isCloudLinked else {
            error = "Sign in to join a squad."
            return
        }
        isJoining = true
        defer { isJoining = false }
        do {
            _ = try await services.squads.joinSquad(inviteCode: code, userId: userId)
            onCompleted?()
            dismiss()
        } catch SquadError.invalidInviteCode {
            error = "Invalid invite code. Double-check and try again."
        } catch SquadError.squadFull {
            error = "That squad is full (max 10 members)."
        } catch SquadError.alreadyInSquad {
            error = "You're already in a squad."
        } catch {
            self.error = "Couldn't join squad. Try again."
        }
    }
}

#Preview {
    JoinSquadSheet()
        .environmentObject(ServiceContainer.mock)
}

#Preview("Prefilled") {
    JoinSquadSheet(prefilledCode: "ABC123")
        .environmentObject(ServiceContainer.mock)
}
