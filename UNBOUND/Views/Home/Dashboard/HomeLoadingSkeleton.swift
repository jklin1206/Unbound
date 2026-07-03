import Foundation
import SwiftUI
import UIKit

struct HomeLoadingSkeleton: View {
    @State private var shimmer: CGFloat = -0.7

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    skeletonCircle(size: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        skeletonLine(width: 86, height: 10)
                        skeletonLine(width: 72, height: 8)
                    }
                    Spacer()
                    skeletonCapsule(width: 76, height: 30)
                }
                .frame(height: 44)

                VStack(alignment: .leading, spacing: 12) {
                    skeletonLine(width: 220, height: 30)
                    skeletonLine(width: 318, height: 13)
                    skeletonLine(width: 242, height: 13)
                }

                skeletonPanel(height: 238, cornerRadius: 16)

                VStack(spacing: 0) {
                    skeletonRailRow()
                    skeletonDivider
                    skeletonRailRow()
                    skeletonDivider
                    HStack(spacing: 0) {
                        skeletonRailRow()
                        Rectangle()
                            .fill(Color.unbound.borderSubtle)
                            .frame(width: 0.5, height: 42)
                        skeletonRailRow()
                    }
                }

                skeletonPanel(height: 154, cornerRadius: 16)
                skeletonPanel(height: 94, cornerRadius: 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .overlay(shimmerOverlay.mask(skeletonMask))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false)) {
                shimmer = 1.15
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.075),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * 0.48)
                .offset(x: proxy.size.width * shimmer)
        }
        .allowsHitTesting(false)
    }

    private var skeletonMask: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Circle().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 5).frame(width: 86, height: 10)
                    RoundedRectangle(cornerRadius: 4).frame(width: 72, height: 8)
                }
                Spacer()
                Capsule().frame(width: 76, height: 30)
            }
            .frame(height: 44)

            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 8).frame(width: 220, height: 30)
                RoundedRectangle(cornerRadius: 6).frame(width: 318, height: 13)
                RoundedRectangle(cornerRadius: 6).frame(width: 242, height: 13)
            }

            RoundedRectangle(cornerRadius: 16).frame(height: 238)
            RoundedRectangle(cornerRadius: 8).frame(height: 146)
            RoundedRectangle(cornerRadius: 16).frame(height: 154)
            RoundedRectangle(cornerRadius: 12).frame(height: 94)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var skeletonDivider: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func skeletonRailRow() -> some View {
        HStack(spacing: 12) {
            skeletonLine(width: 72, height: 9)
            skeletonLine(width: 48, height: 17)
            Spacer()
            skeletonLine(width: 62, height: 9)
        }
        .padding(.leading, 16)
        .padding(.vertical, 10)
    }

    private func skeletonPanel(height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.unbound.surfaceElevated)
            .frame(width: width, height: height)
    }

    private func skeletonCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color.unbound.surfaceElevated)
            .frame(width: size, height: size)
    }

    private func skeletonCapsule(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.unbound.surfaceElevated)
            .frame(width: width, height: height)
    }
}
