// UNBOUND/App/AppLaunchLoadingView.swift
//
// The branded launch/loading screen shown while auth state resolves.
// Extracted from UnboundApp.swift byte-identically (the type was widened
// from `private struct` to `struct` so RootView in its own file can see it).
import SwiftUI
import UIKit

struct AppLaunchLoadingView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            launchBackground

            VStack(spacing: 20) {
                Spacer(minLength: 0)
                    .frame(maxHeight: .infinity)

                logoMark

                Text("UNBOUND")
                    .font(Font.unbound.displayXL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .tracking(4)
                    .shadow(color: Color.unbound.accent.opacity(glow ? 0.65 : 0.25), radius: glow ? 28 : 14)

                Spacer(minLength: 0)
                    .frame(maxHeight: 220)
            }
            .padding(.horizontal, 34)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private var launchBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.024, blue: 0.034),
                    Color(red: 0.055, green: 0.043, blue: 0.083),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(glow ? 0.28 : 0.16),
                    Color.unbound.accent.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 24,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color.unbound.ember.opacity(glow ? 0.16 : 0.08),
                    Color.clear
                ],
                center: UnitPoint(x: 0.22, y: 0.72),
                startRadius: 10,
                endRadius: 280
            )

            launchSigil
                .opacity(glow ? 0.72 : 0.46)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color.clear,
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var launchSigil: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.unbound.accent.opacity(0.22), lineWidth: 1)
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(45))
                .blur(radius: 0.2)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(45))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.unbound.accent.opacity(0.45),
                            Color.unbound.ember.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 430)
                .rotationEffect(.degrees(-34))
                .blur(radius: 0.4)
        }
        .offset(y: -10)
        .shadow(color: Color.unbound.accent.opacity(glow ? 0.24 : 0.12), radius: 40)
    }

    private var logoMark: some View {
        Group {
            if let image = Self.logoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "link")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .frame(width: 146, height: 146)
        .shadow(color: Color.unbound.accent.opacity(glow ? 0.55 : 0.28), radius: glow ? 30 : 16)
        .shadow(color: Color.unbound.ember.opacity(glow ? 0.22 : 0.08), radius: glow ? 46 : 22)
    }

    private static let logoImage: UIImage? = {
        guard let url = Bundle.main.url(forResource: "logo", withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }()
}
