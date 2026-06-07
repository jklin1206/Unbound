// UNBOUND/Views/Squads/CreateSquadSheet.swift
import SwiftUI

struct CreateSquadSheet: View {
    var onCompleted: (() -> Void)?

    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedLogoId = SquadLogoCatalog.defaultId
    @State private var error: String?
    @State private var isCreating = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Name your crew.")
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Squad name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onSubmit { submitIfReady() }
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 30 { name = String(newValue.prefix(30)) }
                            }

                        Text("\(name.count)/30")
                            .font(.caption)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }

                    SquadLogoPicker(selectedLogoId: $selectedLogoId)
                        .padding(.top, 2)

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
            .navigationTitle("New Squad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isNameFocused = false }
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }

    private var footer: some View {
        Button {
            submitIfReady()
        } label: {
            Text(isCreating ? "Creating..." : "Create")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canCreate)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.unbound.bg)
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating
    }

    private func submitIfReady() {
        guard canCreate else { return }
        Task { await create() }
    }

    @MainActor
    private func create() async {
        guard let userId = services.auth.currentUserId else {
            error = "Sign in to create a squad."
            return
        }
        isCreating = true
        defer { isCreating = false }
        do {
            let squad = try await services.squads.createSquad(name: name.trimmingCharacters(in: .whitespaces), userId: userId)
            if squad.resolvedLogoId != selectedLogoId {
                do {
                    try await services.squads.setLogo(selectedLogoId, userId: userId)
                } catch {
                    services.logging.log("CreateSquadSheet.setLogo failed: \(error)", level: .warning)
                }
            }
            onCompleted?()
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
        .environmentObject(ServiceContainer.mock)
}
