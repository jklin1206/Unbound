import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unbound Native Primitives
//
// Shared screen furniture for the Premium Hollow language: dividers,
// scroll chrome, section headers, metric rails, row buttons.
// Split from View+UnboundStyle.swift (was 1,369 lines).

// MARK: Native screen primitives

struct UnboundNativeDivider: View {
    var opacity: Double = 0.54

    var body: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle.opacity(opacity))
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }
}

struct UnboundTopScrollChrome: View {
    var tint: Color = Color.unbound.accent
    var topOpacity: Double = 0.52
    var fadeOpacity: Double = 0.34

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(proxy.safeAreaInsets.top, 44)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.unbound.bg.opacity(topOpacity))
                    .frame(height: topInset + 6)

                LinearGradient(
                    stops: [
                        .init(color: Color.unbound.bg.opacity(fadeOpacity), location: 0),
                        .init(color: Color.unbound.bg.opacity(fadeOpacity * 0.42), location: 0.58),
                        .init(color: Color.clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 34)

                Spacer(minLength: 0)
            }
            .overlay(alignment: .topTrailing) {
                RadialGradient(
                    colors: [
                        tint.opacity(0.04),
                        tint.opacity(0.015),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 180
                )
                .frame(width: 180, height: topInset + 52)
            }
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }
}

struct UnboundSectionHeader: View {
    let eyebrow: String
    let title: String
    var detail: String? = nil
    var tint: Color = Color.unbound.textTertiary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(tint.opacity(0.92))
                    .lineLimit(1)

                Text(title.uppercased())
                    .font(.system(size: 18, weight: .black))
                    .tracking(0.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 12)

            if let detail {
                Text(detail.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }
}

struct UnboundNativeMetric {
    let label: String
    let value: String
    var detail: String? = nil
    var tint: Color = Color.unbound.textPrimary
}

struct UnboundNativeMetricRail: View {
    let metrics: [UnboundNativeMetric]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.label.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(metric.value.uppercased())
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(metric.tint)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    if let detail = metric.detail {
                        Text(detail.uppercased())
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, index == 0 ? 0 : 12)

                if index < metrics.count - 1 {
                    Rectangle()
                        .fill(Color.unbound.borderSubtle.opacity(0.64))
                        .frame(width: 0.5)
                        .padding(.vertical, 3)
                }
            }
        }
    }
}

struct UnboundNativeRowButton: View {
    let systemImage: String
    let eyebrow: String
    let title: String
    var detail: String? = nil
    var tint: Color = Color.unbound.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, alignment: .center)

                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)

                    Text(title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    if let detail {
                        Text(detail)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

