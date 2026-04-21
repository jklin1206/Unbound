import SwiftUI

struct LoadingStateView<T>: View {
    let state: LoadingState<T>
    var message: String = "Loading..."
    var retryAction: (() -> Void)? = nil

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            VStack(spacing: 16) {
                ProgressView()
                    .tint(Color.theme.primary)
                    .scaleEffect(1.2)
                if !message.isEmpty {
                    Text(message)
                        .font(.bodyText())
                        .foregroundColor(.theme.textSecondary)
                }
            }
        case .loaded:
            EmptyView()
        case .error(let error):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.theme.danger)
                Text(error.errorDescription ?? "Something went wrong")
                    .font(.bodyText())
                    .foregroundColor(.theme.textPrimary)
                    .multilineTextAlignment(.center)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption())
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if let retry = retryAction {
                    GradientButton(title: "Try Again", action: retry)
                        .padding(.horizontal, 40)
                }
            }
            .padding()
        }
    }
}
