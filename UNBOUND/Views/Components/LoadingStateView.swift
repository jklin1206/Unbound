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
                    .tint(Color.unbound.accent)
                    .scaleEffect(1.2)
                if !message.isEmpty {
                    Text(message)
                        .font(.bodyText())
                        .foregroundColor(Color.unbound.textSecondary)
                }
            }
        case .loaded:
            EmptyView()
        case .error(let error):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color.unbound.alert)
                Text(error.errorDescription ?? "Something went wrong")
                    .font(.bodyText())
                    .foregroundColor(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption())
                        .foregroundColor(Color.unbound.textSecondary)
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
