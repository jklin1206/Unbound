// UNBOUND/Views/Squads/CreateSquadSheet.swift
//
// Note: uses SquadService.shared + AuthService.shared directly.
// ServiceContainer wiring deferred to Phase 16.
import SwiftUI

struct CreateSquadSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var error: String?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Name your crew.")
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                TextField("Squad name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 30 { name = String(newValue.prefix(30)) }
                    }
                Text("\(name.count)/30")
                    .font(.caption)
                    .foregroundStyle(Color.unbound.textSecondary)
                if let error {
                    Text(error).foregroundStyle(.red)
                }
                Spacer()
                Button {
                    Task { await create() }
                } label: {
                    Text(isCreating ? "Creating…" : "Create")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("New Squad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func create() async {
        guard let userId = AuthService.shared.currentUserId else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            _ = try await SquadService.shared.createSquad(name: name.trimmingCharacters(in: .whitespaces), userId: userId)
            dismiss()
        } catch SquadError.invalidName {
            error = "Squad name must be 1–30 characters."
        } catch SquadError.alreadyInSquad {
            error = "You're already in a squad."
        } catch {
            self.error = "Couldn't create squad. Try again."
        }
    }
}

#Preview {
    CreateSquadSheet()
}
