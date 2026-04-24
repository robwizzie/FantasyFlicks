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
    /// External trigger for a programmatic swipe (from check/X buttons). Setting
    /// this to a non-nil direction fires the same fly-off animation as a real
    /// swipe, including the SKIP/WATCH stamp, then calls `onSwipe`.
    @Binding var programmaticSwipe: SwipeDirection?

    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragLocked = false  // true = confirmed horizontal, false = not yet decided
    @State private var dragRejected = false  // vertical drag detected, ignore until end
    /// When non-nil, drive the stamp from this value instead of the offset —
    /// lets programmatic swipes flash the stamp without relying on any drag.
    @State private var forcedStampDirection: SwipeDirection?

    private let swipeThreshold: CGFloat = 80
    private let maxRotation: Double = 10

    init(@ViewBuilder content: () -> Content,
         programmaticSwipe: Binding<SwipeDirection?> = .constant(nil),
         onSwipe: @escaping (SwipeDirection) -> Void) {
        self.content = content()
        self._programmaticSwipe = programmaticSwipe
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
            .onChange(of: programmaticSwipe) { _, direction in
                guard let direction else { return }
                animateProgrammatic(direction: direction)
            }
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
            // WATCH stamp (right swipe) — honor a forced direction so
            // check-button taps still flash the stamp even before the
            // offset animation kicks in.
            swipeStamp(text: "WATCH", color: FFColors.success, alignment: .leading)
                .opacity(watchStampOpacity)

            // SKIP stamp (left swipe)
            swipeStamp(text: "SKIP", color: FFColors.ruby, alignment: .trailing)
                .opacity(skipStampOpacity)
        }
        .animation(.easeOut(duration: 0.12), value: swipeProgress)
        .animation(.easeOut(duration: 0.12), value: forcedStampDirection)
    }

    private var watchStampOpacity: Double {
        if forcedStampDirection == .right { return 1 }
        return offset.width > 0 ? swipeProgress : 0
    }

    private var skipStampOpacity: Double {
        if forcedStampDirection == .left { return 1 }
        return offset.width < 0 ? swipeProgress : 0
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
            flyOff(direction: .right, startHeight: translation.height * 0.5)
        } else if horizontalAmount + velocityBoost < -swipeThreshold {
            flyOff(direction: .left, startHeight: translation.height * 0.5)
        } else {
            // Spring back with bounce
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                offset = .zero
            }
        }
    }

    /// Animate the card off-screen in the given direction, then notify the
    /// parent. Slightly delaying `onSwipe` until the fly-off is mostly done
    /// keeps the next card from popping in while this one is still on screen,
    /// which was the "jump" users noticed.
    private func flyOff(direction: SwipeDirection, startHeight: CGFloat = 0) {
        let targetX: CGFloat = direction == .right ? 600 : -600
        let flightDuration = 0.34

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            offset = CGSize(width: targetX, height: startHeight)
        }

        // Hand off to the parent right as the card clears the viewport.
        // Parent advances currentIndex, which fades in the next card — by then
        // this card is >85% off-screen so there's no visible overlap.
        DispatchQueue.main.asyncAfter(deadline: .now() + flightDuration * 0.75) {
            onSwipe(direction)
        }
    }

    /// External (button-tap) swipe. Plays the stamp immediately and then
    /// performs the same fly-off animation as a real drag-swipe.
    private func animateProgrammatic(direction: SwipeDirection) {
        // Clear the binding right away so subsequent rapid taps all register
        // as fresh value changes, not deduped identical values.
        DispatchQueue.main.async {
            programmaticSwipe = nil
        }

        // Pin the stamp so it's visible even before offset-based progress
        // catches up.
        withAnimation(.easeIn(duration: 0.08)) {
            forcedStampDirection = direction
        }

        // Nudge the offset so the stamp's opacity transitions smoothly into
        // the fly-off animation.
        withAnimation(.spring(response: 0.18, dampingFraction: 0.9)) {
            offset = CGSize(width: direction == .right ? 120 : -120, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flyOff(direction: direction)
        }
    }
}

// MARK: - Movie Night Card Content

struct MovieNightCardContent: View {
    let movie: FFMovie
    let providers: [WatchProvider]
    let hasSeenIt: Bool
    var isOnWatchlist: Bool = false
    let onToggleSeen: () -> Void
    var onToggleWatchlist: () -> Void = {}
    let onTapDetail: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Movie poster background
            posterBackground

            // Bottom info overlay
            cardInfoOverlay

            // Seen it + watchlist toggles (top right)
            cornerActions
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

    // MARK: - Corner Actions (Seen + Watchlist)

    private var cornerActions: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    pill(
                        icon: hasSeenIt ? "eye.fill" : "eye",
                        label: hasSeenIt ? "Seen" : nil,
                        active: hasSeenIt,
                        action: onToggleSeen
                    )

                    pill(
                        icon: isOnWatchlist ? "bookmark.fill" : "bookmark",
                        label: isOnWatchlist ? "Saved" : nil,
                        active: isOnWatchlist,
                        action: onToggleWatchlist
                    )

                    // Star rating (shown when movie is marked as seen)
                    if hasSeenIt {
                        StarRatingView(tmdbId: movie.tmdbId, compact: true)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            Spacer()
        }
        .padding(FFSpacing.md)
    }

    private func pill(icon: String, label: String?, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundColor(active ? FFColors.goldPrimary : FFColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(active ? FFColors.goldPrimary.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Stack View

struct CardStackView: View {
    let movies: [FFMovie]
    let currentIndex: Int
    let providers: [Int: [WatchProvider]] // tmdbId -> providers
    let seenMovies: Set<Int> // tmdb IDs
    var watchlistMovies: Set<Int> = []  // tmdb IDs on the current user's watchlist
    /// External programmatic swipe trigger (from action buttons). CardStackView
    /// forwards the binding to the active top card so the stamp animates
    /// regardless of whether the user dragged or tapped.
    @Binding var programmaticSwipe: SwipeDirection?
    let onSwipe: (SwipeDirection) -> Void
    let onToggleSeen: (Int) -> Void
    var onToggleWatchlist: (Int) -> Void = { _ in }
    let onTapDetail: (FFMovie) -> Void

    init(movies: [FFMovie],
         currentIndex: Int,
         providers: [Int: [WatchProvider]],
         seenMovies: Set<Int>,
         watchlistMovies: Set<Int> = [],
         programmaticSwipe: Binding<SwipeDirection?> = .constant(nil),
         onSwipe: @escaping (SwipeDirection) -> Void,
         onToggleSeen: @escaping (Int) -> Void,
         onToggleWatchlist: @escaping (Int) -> Void = { _ in },
         onTapDetail: @escaping (FFMovie) -> Void) {
        self.movies = movies
        self.currentIndex = currentIndex
        self.providers = providers
        self.seenMovies = seenMovies
        self.watchlistMovies = watchlistMovies
        self._programmaticSwipe = programmaticSwipe
        self.onSwipe = onSwipe
        self.onToggleSeen = onToggleSeen
        self.onToggleWatchlist = onToggleWatchlist
        self.onTapDetail = onTapDetail
    }

    var body: some View {
        ZStack {
            // Show up to 3 cards in the stack
            ForEach(visibleCardIndices.reversed(), id: \.self) { index in
                let movie = movies[index]
                let stackPosition = index - currentIndex

                if stackPosition == 0 {
                    // Top card — interactive
                    SwipeCardView(
                        content: {
                            MovieNightCardContent(
                                movie: movie,
                                providers: providers[movie.tmdbId] ?? [],
                                hasSeenIt: seenMovies.contains(movie.tmdbId),
                                isOnWatchlist: watchlistMovies.contains(movie.tmdbId),
                                onToggleSeen: { onToggleSeen(movie.tmdbId) },
                                onToggleWatchlist: { onToggleWatchlist(movie.tmdbId) },
                                onTapDetail: { onTapDetail(movie) }
                            )
                        },
                        programmaticSwipe: $programmaticSwipe,
                        onSwipe: { direction in
                            onSwipe(direction)
                        }
                    )
                    .id(movie.tmdbId)   // force state reset per card to avoid stale offset
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

    private var currentRating: Double {
        seenService.rating(for: tmdbId) ?? 0
    }

    /// Letterboxd-style tap behavior:
    ///   - Empty → tap N = set to N whole stars
    ///   - Same whole star (e.g. 4 → tap 4) = set to 3.5 (halve down)
    ///   - Same half star (e.g. 3.5 → tap 4) = set to 4 (fill up)
    ///   - Different star = jump to that whole value
    private func tap(_ star: Int) {
        let current = currentRating
        let starDouble = Double(star)
        let newRating: Double
        if current == starDouble {
            // Tapping the exact filled star halves it
            newRating = starDouble - 0.5
        } else if current == starDouble - 0.5 {
            // Tapping the half-filled star fills it
            newRating = starDouble
        } else {
            newRating = starDouble
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            if newRating <= 0 {
                seenService.removeRating(tmdbId: tmdbId)
            } else {
                seenService.setRating(tmdbId: tmdbId, stars: newRating)
            }
        }
    }

    /// Icon + color for star index N.
    private func icon(for star: Int) -> (name: String, filled: Bool) {
        let starDouble = Double(star)
        if currentRating >= starDouble {
            return ("star.fill", true)
        } else if currentRating >= starDouble - 0.5 {
            return ("star.leadinghalf.filled", true)
        } else {
            return ("star", false)
        }
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 4) {
            ForEach(1...5, id: \.self) { star in
                let appearance = icon(for: star)
                Button {
                    tap(star)
                } label: {
                    Image(systemName: appearance.name)
                        .font(.system(size: compact ? 14 : 20))
                        .foregroundColor(appearance.filled ? FFColors.goldPrimary : FFColors.textTertiary)
                        .symbolRenderingMode(.hierarchical)
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

/// Read-only half-star display for when you want to show someone else's rating,
/// or show a legacy integer rating on a diary row.
struct StarRatingDisplay: View {
    let rating: Double
    var size: CGFloat = 12
    var dimColor: Color = FFColors.textTertiary.opacity(0.4)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                let starDouble = Double(star)
                let name: String = {
                    if rating >= starDouble { return "star.fill" }
                    if rating >= starDouble - 0.5 { return "star.leadinghalf.filled" }
                    return "star"
                }()
                let color: Color = (rating >= starDouble - 0.5) ? FFColors.goldPrimary : dimColor
                Image(systemName: name)
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
    }
}
