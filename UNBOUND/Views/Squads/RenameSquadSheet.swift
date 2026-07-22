// UNBOUND/Views/Squads/RenameSquadSheet.swift
import SwiftUI

/// Captain-only sheet to rename an existing squad. Mirrors the create sheet's
/// input chrome + 1–30 char validation; the caller persists via
/// `SquadService.renameSquad`.
struct RenameSquadSheet: View {
    let initialName: String
    let onRename: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(initialName: String, onRename: @escaping (String) -> Void) {
        self.initialName = initialName
        self.onRename = onRename
        _name = State(initialValue: initialName)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmed.isEmpty && trimmed != initialName }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Rename your crew.")
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Squad name", text: $name)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onSubmit { submitIfReady() }
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 30 { name = String(newValue.prefix(30)) }
                            }
                            .squadInputChrome(isFocused: isNameFocused)

                        Text("\(name.count)/30")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                UnboundButton(title: "Save Name", isEnabled: canSave) {
                    submitIfReady()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color.unbound.bg)
            }
            // The footer must NOT ride the keyboard - lifted, it collides with
            // the keyboard toolbar's Done button. It stays seated at the screen
            // bottom (hidden while typing); the keyboard's return key submits.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Rename Squad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isNameFocused = true }
        }
    }

    private func submitIfReady() {
        guard canSave else { return }
        onRename(trimmed)
        dismiss()
    }
}

#Preview {
    RenameSquadSheet(initialName: "Night Crew") { _ in }
}
