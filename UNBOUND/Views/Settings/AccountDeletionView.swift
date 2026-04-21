import SwiftUI

struct AccountDeletionView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    private let deletedItems = [
        "Your account and profile",
        "All body scan photos",
        "All analysis reports",
        "Your training programs",
        "Your progress history",
    ]

    private var canDelete: Bool {
        viewModel.deleteConfirmationText.lowercased() == "delete"
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(Color.theme.danger.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.theme.danger)
                    }
                    .padding(.top, 24)

                    // Headline
                    VStack(spacing: 8) {
                        Text("Delete Your Account")
                            .font(.headline(26))
                            .foregroundColor(.theme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("This will permanently delete your account, all scan data, photos, programs, and progress. This cannot be undone.")
                            .font(.bodyText(15))
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Bullet list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What will be deleted:")
                            .font(.bodyMedium(14))
                            .foregroundColor(.theme.textSecondary)

                        ForEach(deletedItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.theme.danger)
                                    .padding(.top, 1)
                                Text(item)
                                    .font(.bodyText(14))
                                    .foregroundColor(.theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Confirmation text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type 'delete' to confirm")
                            .font(.bodyMedium(14))
                            .foregroundColor(.theme.textSecondary)

                        TextField("delete", text: $viewModel.deleteConfirmationText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.bodyText(16))
                            .foregroundColor(.theme.textPrimary)
                            .padding(14)
                            .background(Color.theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        canDelete ? Color.theme.danger : Color.theme.surfaceLight,
                                        lineWidth: 1
                                    )
                            )
                    }

                    // Delete button
                    Button {
                        Task {
                            await viewModel.deleteAccount()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(viewModel.isLoading ? "Deleting…" : "Delete My Account")
                                .font(.bodyMedium(17))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canDelete ? Color.theme.danger : Color.theme.danger.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canDelete || viewModel.isLoading)

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.bodyText(14))
                            .foregroundColor(.theme.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.isLoading) { _, isLoading in
            // If loading finished with no error, dismiss (account deleted — handled by app root auth state)
        }
    }
}

#Preview {
    NavigationStack {
        AccountDeletionView(viewModel: SettingsViewModel(services: .mock))
    }
}
