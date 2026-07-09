import SwiftUI

/// Matches `AppleSignInButton`'s geometry (white, 56pt tall, 12pt radius,
/// semibold 17) so the two providers read as one stack. The multicolor "G"
/// is the vendored brand asset rendered in its original colors.
struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image("GoogleG")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(L10n.string(.authGoogleSignIn, defaultValue: "Sign in with Google"))
                    .font(.bodyMedium(17))
                    .fontWeight(.semibold)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 16) {
            AppleSignInButton(action: {})
            GoogleSignInButton(action: {})
        }
        .padding(.horizontal, 24)
    }
}
