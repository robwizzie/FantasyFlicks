//
//  LoadingViews.swift
//  FantasyFlicks
//
//  Shared loading indicators: full-screen loader, shimmer skeletons,
//  and inline indicators for consistent UX across the app
//

import SwiftUI

// Note: `.shimmer()` extension is defined in Core/Theme/FFAnimations.swift

// MARK: - Full Screen Loading View

struct FullScreenLoadingView: View {
    let message: String
    @State private var rotate = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            VStack(spacing: FFSpacing.xl) {
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .fill(FFColors.goldPrimary.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                        .opacity(pulse ? 0 : 1)

                    // Rotating arc
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(FFColors.goldGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotate ? 360 : 0))

                    Image(systemName: "popcorn.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(FFColors.goldGradient)
                }

                Text(message)
                    .font(FFTypography.titleMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FFSpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotate = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Inline Loading Indicator

struct InlineLoader: View {
    var tint: Color = FFColors.goldPrimary
    var size: CGFloat = 20
    @State private var rotate = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotate = true
                }
            }
    }
}

// MARK: - Poster Skeleton

struct PosterSkeleton: View {
    var aspectRatio: CGFloat = 2.0 / 3.0
    var cornerRadius: CGFloat = FFCornerRadius.medium

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(FFColors.backgroundElevated)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .shimmer()
    }
}

// MARK: - Card Skeleton

struct CardSkeleton: View {
    var height: CGFloat = 80
    var cornerRadius: CGFloat = FFCornerRadius.large

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(FFColors.backgroundElevated)
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Row Skeleton (for lists)

struct RowSkeleton: View {
    var body: some View {
        HStack(spacing: FFSpacing.md) {
            RoundedRectangle(cornerRadius: 6)
                .fill(FFColors.backgroundElevated)
                .frame(width: 44, height: 66)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(FFColors.backgroundElevated)
                    .frame(width: 160, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(FFColors.backgroundElevated)
                    .frame(width: 100, height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(FFColors.backgroundElevated)
                    .frame(width: 80, height: 10)
            }

            Spacer()
        }
        .padding(FFSpacing.sm)
        .shimmer()
    }
}
