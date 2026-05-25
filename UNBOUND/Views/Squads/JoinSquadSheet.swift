// UNBOUND/Views/Squads/JoinSquadSheet.swift
//
// Note: uses SquadService.shared + AuthService.shared directly.
// ServiceContainer wiring deferred to Phase 16.
import SwiftUI

struct JoinSquadSheet: View {
    /// Pre-filled invite code — used by the universal-link flow.
    var prefilledCode: String? = nil
    var onCompleted: (() -> Void)?

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
                            .textFieldStyle(.roundedBorder)
                            .textCase(.uppercase)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
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

                        Text("\(code.count)/6")
                            .font(.caption)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }

                    if let error {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
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
            .navigationTitle("Join Squad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isCodeFocused = false }
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
        Button {
            submitIfReady()
        } label: {
            Text(isJoining ? "Joining..." : "Join Squad")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canJoin)
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
        guard let userId = AuthService.shared.currentUserId else {
            error = "Sign in to join a squad."
            return
        }
        isJoining = true
        defer { isJoining = false }
        do {
            _ = try await SquadService.shared.joinSquad(inviteCode: code, userId: userId)
            onCompleted?()
            dismiss()
        } catch SquadError.invalidInviteCode {
            error = "Invalid invite code. Double-check and try again."
        } catch SquadError.squadFull {
            error = "That squad is full (max 8 members)."
        } catch SquadError.alreadyInSquad {
            error = "You're already in a squad."
        } catch {
            self.error = "Couldn't join squad. Try again."
        }
    }
}

#Preview {
    JoinSquadSheet()
}

#Preview("Prefilled") {
    JoinSquadSheet(prefilledCode: "ABC123")
}
