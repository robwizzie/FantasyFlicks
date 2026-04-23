//
//  SwipeCardView.swift
//  FantasyFlicks
//
//  Tinder-style swipeable card component for Movie Night
//

import SwiftUI

// MARK: - Swipe Direction

enum SwipeDirection {
    case left, right
}

// MARK: - Swipe Card View

struct SwipeCardView<Content: View>: View {
    let content: Content
    let onSwipe: (SwipeDirection) -> Void

    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragLocked = false  // true = confirmed horizontal, false = not yet decided
    @State private var dragRejected = false  // vertical drag detected, ignore until end

    private let swipeThreshold: CGFloat = 80
    private let maxRotation: Double = 10

    init(@ViewBuilder content: () -> Content, onSwipe: @escaping (SwipeDirection) -> Void) {
        self.content = content()
        self.onSwipe = onSwipe
    }

    var body: some View {
        content
            .rotationEffect(.degrees(rotationAngle), anchor: .bottom)
            .offset(x: offset.width, y: offset.height * 0.2)
            .overlay {
                swipeOverlay
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Decide direction lock on first significant movement
                        if !dragLocked && !dragRejected {
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)
                            if horizontal > 15 || vertical > 15 {
                                if horizontal > vertical * 0.8 {
                                    dragLocked = true
                                } else {
                                    dragRejected = true
                                    return
                                }
                            } else {
                                return  // Not enough movement to decide
                            }
                        }

                        guard dragLocked else { return }

                        isDragging = true
                        withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                            offset = value.translation
                        }
                    }
                    .onEnded { value in
                        defer {
                            dragLocked = false
                            dragRejected = false
                        }
                        guard dragLocked else {
                            isDragging = false
                            return
                        }
                        isDragging = false
                        handleSwipeEnd(translation: value.translation, velocity: value.velocity)
                    }
            )
            .animation(isDragging ? nil : .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.1), value: offset)
    }

    // MARK: - Computed Properties

    private var rotationAngle: Double {
        let progress = Double(offset.width) / 300
        return progress * maxRotation
    }

    private var swipeProgress: Double {
        min(abs(Double(offset.width)) / Double(swipeThreshold), 1.0)
    }

    // MARK: - Overlay

    private var swipeOverlay: some View {
        ZStack {
            // WATCH stamp (right swipe)
            swipeStamp(text: "WATCH", color: FFColors.success, alignment: .leading)
                .opacity(offset.width > 0 ? swipeProgress : 0)

            // SKIP stamp (left swipe)
            swipeStamp(text: "SKIP", color: FFColors.ruby, alignment: .trailing)
                .opacity(offset.width < 0 ? swipeProgress : 0)
        }
        .animation(.easeOut(duration: 0.1), value: swipeProgress)
    }

    private func swipeStamp(text: String, color: Color, alignment: Alignment) -> some View {
        VStack {
            Text(text)
                .font(.system(size: 42, weight: .black))
                .foregroundColor(color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: 4)
                }
                .rotationEffect(.degrees(alignment == .leading ? -15 : 15))
                .padding(40)
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    // MARK: - Gesture Handling

    private func handleSwipeEnd(translation: CGSize, velocity: CGSize) {
        let horizontalAmount = translation.width
        let velocityBoost = velocity.width / 4

        if horizontalAmount + velocityBoost > swipeThreshold {
            // Swipe right — fly off screen with natural curve
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                offset = CGSize(width: 600, height: translation.height * 0.5)
            }
            onSwipe(.right)
        } else if horizontalAmount + velocityBoost < -swipeThreshold {
            // Swipe left — fly off screen
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                offset = CGSize(width: -600, height: translation.height * 0.5)
            }
            onSwipe(.left)
        } else {
            // Spring back with bounce
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                offset = .zero
            }
        }
    }
}

// MARK: - Movie Night Card Content

struct MovieNightCardContent: View {
    let movie: FFMovie
    let providers: [WatchProvider]
    let hasSeenIt: Bool
    let onToggleSeen: () -> Void
    let onTapDetail: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Movie poster background
            posterBackground

            // Bottom info overlay
            cardInfoOverlay

            // Seen it toggle (top right)
            seenItButton
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.xxl))
        .overlay {
            RoundedRectangle(cornerRadius: FFCornerRadius.xxl)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    // MARK: - Poster Background

    private var posterBackground: some View {
        Group {
            if let posterURL = movie.posterURLHighRes ?? movie.posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        FFColors.backgroundElevated
                        VStack(spacing: FFSpacing.md) {
                            Image(systemName: "film")
                                .font(.system(size: 48))
                                .foregroundColor(FFColors.textTertiary)
                            Text(movie.title)
                                .font(FFTypography.titleMedium)
                                .foregroundColor(FFColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
            } else {
                ZStack {
                    FFColors.backgroundElevated
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(FFColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Info Overlay

    private var cardInfoOverlay: some View {
        VStack(alignment: .leading, spacing: FFSpacing.xs) {
            Spacer()

            VStack(alignment: .leading, spacing: FFSpacing.xs) {
                // Title
                Text(movie.title)
                    .font(FFTypography.headlineMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(2)

                // Year + Rating + Runtime
                HStack(spacing: FFSpacing.sm) {
                    if let year = movie.year {
                        Text(String(year))
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.textSecondary)
                    }

                    if movie.voteAverage > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .foregroundColor(FFColors.goldPrimary)
                                .font(.system(size: 10))
                            Text(String(format: "%.1f", movie.voteAverage))
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.goldLight)
                        }
                    }

                    if let runtime = movie.formattedRuntime {
                        Text(runtime)
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                }

                // Genres (compact)
                if !movie.genres.isEmpty {
                    HStack(spacing: FFSpacing.xs) {
                        ForEach(movie.genres.prefix(3)) { genre in
                            Text(genre.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(FFColors.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Streaming providers (capped with "+N more")
                if !providers.isEmpty {
                    let visible = Array(providers.prefix(4))
                    let hidden = providers.count - visible.count
                    HStack(spacing: FFSpacing.xs) {
                        ForEach(visible) { provider in
                            if let logoURL = provider.logoURL {
                                CachedAsyncImage(url: logoURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(FFColors.backgroundElevated2)
                                }
                                .frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        if hidden > 0 {
                            Text("+\(hidden)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FFColors.textSecondary)
                                .frame(width: 22, height: 22)
                                .background(FFColors.backgroundElevated2)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }

                // Overview (brief)
                if !movie.overview.isEmpty {
                    Text(movie.overview)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, FFSpacing.lg)
            .padding(.bottom, FFSpacing.lg)
            .padding(.top, FFSpacing.xxl)
            .background {
                LinearGradient(
                    colors: [
                        .clear,
                        FFColors.backgroundDark.opacity(0.6),
                        FFColors.backgroundDark.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .onTapGesture {
            onTapDetail()
        }
    }

    // MARK: - Seen It Button

    private var seenItButton: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Button(action: onToggleSeen) {
                        HStack(spacing: 4) {
                            Image(systemName: hasSeenIt ? "eye.fill" : "eye")
                                .font(.system(size: 13, weight: .semibold))
                            if hasSeenIt {
                                Text("Seen")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .foregroundColor(hasSeenIt ? FFColors.goldPrimary : FFColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(hasSeenIt ? FFColors.goldPrimary.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                        }
                    }

                    // Star rating (shown when movie is marked as seen)
                    if hasSeenIt {
                        StarRatingView(
                            tmdbId: movie.tmdbId,
                            compact: true
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            Spacer()
        }
        .padding(FFSpacing.md)
    }
}

// MARK: - Card Stack View

struct CardStackView: View {
    let movies: [FFMovie]
    let currentIndex: Int
    let providers: [Int: [WatchProvider]] // tmdbId -> providers
    let seenMovies: Set<Int> // tmdb IDs
    let onSwipe: (SwipeDirection) -> Void
    let onToggleSeen: (Int) -> Void // tmdbId
    let onTapDetail: (FFMovie) -> Void

    var body: some View {
        ZStack {
            // Show up to 3 cards in the stack
            ForEach(visibleCardIndices.reversed(), id: \.self) { index in
                let movie = movies[index]
                let stackPosition = index - currentIndex

                if stackPosition == 0 {
                    // Top card — interactive
                    SwipeCardView {
                        MovieNightCardContent(
                            movie: movie,
                            providers: providers[movie.tmdbId] ?? [],
                            hasSeenIt: seenMovies.contains(movie.tmdbId),
                            onToggleSeen: { onToggleSeen(movie.tmdbId) },
                            onTapDetail: { onTapDetail(movie) }
                        )
                    } onSwipe: { direction in
                        onSwipe(direction)
                    }
                    .zIndex(3)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
                } else {
                    // Background cards — static, slightly offset
                    MovieNightCardContent(
                        movie: movie,
                        providers: providers[movie.tmdbId] ?? [],
                        hasSeenIt: false,
                        onToggleSeen: {},
                        onTapDetail: {}
                    )
                    .scaleEffect(1.0 - CGFloat(stackPosition) * 0.04)
                    .offset(y: CGFloat(stackPosition) * 10)
                    .opacity(1.0 - Double(stackPosition) * 0.3)
                    .zIndex(Double(3 - stackPosition))
                    .allowsHitTesting(false)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: currentIndex)
    }

    private var visibleCardIndices: [Int] {
        let start = currentIndex
        let end = min(currentIndex + 3, movies.count)
        guard start < end else { return [] }
        return Array(start..<end)
    }
}

// MARK: - Star Rating View

struct StarRatingView: View {
    let tmdbId: Int
    var compact: Bool = false
    @StateObject private var seenService = SeenMoviesService.shared

    private var currentRating: Int {
        seenService.rating(for: tmdbId) ?? 0
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 4) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        if currentRating == star {
                            seenService.removeRating(tmdbId: tmdbId)
                        } else {
                            seenService.setRating(tmdbId: tmdbId, stars: star)
                        }
                    }
                } label: {
                    Image(systemName: star <= currentRating ? "star.fill" : "star")
                        .font(.system(size: compact ? 12 : 18))
                        .foregroundColor(star <= currentRating ? FFColors.goldPrimary : FFColors.textTertiary)
                        .scaleEffect(star <= currentRating ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, compact ? 8 : 0)
        .padding(.vertical, compact ? 4 : 0)
        .background(compact ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        .clipShape(Capsule())
    }
}
