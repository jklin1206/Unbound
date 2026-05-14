// UNBOUND/Views/Squads/JoinSquadSheet.swift
//
// Note: uses SquadService.shared + AuthService.shared directly.
// ServiceContainer wiring deferred to Phase 16.
import SwiftUI

struct JoinSquadSheet: View {
    /// Pre-filled invite code — used by the universal-link flow.
    var prefilledCode: String? = nil

    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    @State private var error: String?
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter invite code.")
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)

                TextField("6-character code", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal)
                    .onChange(of: code) { _, newValue in
                        // Strip non-alphanumeric, uppercase, cap at 6 chars
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

                if let error {
                    Text(error).foregroundStyle(.red)
                }

                Spacer()

                Button {
                    Task { await join() }
                } label: {
                    Text(isJoining ? "Joining…" : "Join Squad")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.count != 6 || isJoining)
                .padding(.horizontal)
            }
            .padding(.vertical)
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
            }
        }
    }

    @MainActor
    private func join() async {
        guard let userId = AuthService.shared.currentUserId else { return }
        isJoining = true
        defer { isJoining = false }
        do {
            _ = try await SquadService.shared.joinSquad(inviteCode: code, userId: userId)
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
