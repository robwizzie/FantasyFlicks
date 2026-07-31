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

// MARK: - Exit Timing

/// Tuning for the card's exit animation.
///
/// A namespace rather than statics on `SwipeCardView` because that type is
/// generic over its content, and Swift doesn't allow static stored properties
/// in generic types. They're shared across every instantiation anyway.
private enum SwipeExit {
    /// The card's exit is one-way, so it's an ease-out rather than a spring.
    /// A spring has to settle, and `response: 0.35` was still visibly animating
    /// long after the card had left the screen — time the user reads as lag.
    ///
    /// A dragged card's exit is scaled between these by how hard it was thrown:
    /// a firm flick should snap away, while a card nudged just past the
    /// threshold should carry through at the pace the hand set. A single fixed
    /// duration made gentle swipes feel like the card was yanked out of reach.
    static let fastFlightDuration = 0.20
    static let slowFlightDuration = 0.32
    /// Release speed (pt/s) at which the exit is fully at `fastFlightDuration`.
    static let briskVelocity: CGFloat = 1400

    /// Button taps aren't throws, so they get a deliberate, readable flick with
    /// time to register the SKIP/WATCH stamp. At the drag speed this read as
    /// the card vanishing rather than being swiped.
    static let buttonFlightDuration = 0.40

    /// Exit duration for a drag released at `velocity`.
    static func flightDuration(forReleaseVelocity velocity: CGFloat) -> Double {
        let speed = min(abs(velocity), briskVelocity)
        let briskness = Double(speed / briskVelocity)
        return slowFlightDuration - (slowFlightDuration - fastFlightDuration) * briskness
    }

    /// How far the card travels on its way out.
    ///
    /// Generous on purpose. The exit only has to look right until the card is
    /// gone, and overshooting the screen edge buys margin for the handoff below
    /// — at 600pt the card was still clipping the edge of a large display when
    /// the deck advanced, and its removal visibly faded there.
    static let flightDistance: CGFloat = 750

    /// Fraction of the flight after which the deck advances.
    ///
    /// An ease-out is front-loaded: by 55% of the duration the card has covered
    /// ~74% of its travel — 552pt, comfortably clear of the widest supported
    /// screen (474pt needed, ~78pt spare). Handing off there lets the next card
    /// come forward while this one is still animating, so the two overlap
    /// instead of queueing.
    static let handoffFraction = 0.55
}

// MARK: - Swipe Card View

struct SwipeCardView<Content: View>: View {
    let content: Content
    let onSwipe: (SwipeDirection) -> Void
    /// False for the cards sitting behind the top one. They render through this
    /// same wrapper — identical view structure at every stack position is what
    /// lets a card be *promoted* to the top instead of torn down and rebuilt —
    /// but they don't take gestures until they get there.
    let isActive: Bool
    /// External trigger for a programmatic swipe (from check/X buttons). Setting
    /// this to a non-nil direction fires the same fly-off animation as a real
    /// swipe, including the SKIP/WATCH stamp, then calls `onSwipe`.
    @Binding var programmaticSwipe: SwipeDirection?

    @State private var offset: CGSize = .zero
    @State private var dragLocked = false  // true = confirmed horizontal, false = not yet decided
    @State private var dragRejected = false  // vertical drag detected, ignore until end
    /// When non-nil, drive the stamp from this value instead of the offset —
    /// lets programmatic swipes flash the stamp without relying on any drag.
    @State private var forcedStampDirection: SwipeDirection?

    private let swipeThreshold: CGFloat = 80
    private let maxRotation: Double = 10


    init(@ViewBuilder content: () -> Content,
         isActive: Bool = true,
         programmaticSwipe: Binding<SwipeDirection?> = .constant(nil),
         onSwipe: @escaping (SwipeDirection) -> Void) {
        self.content = content()
        self.isActive = isActive
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
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        // Decide direction lock on first significant movement
                        if !dragLocked && !dragRejected {
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)
                            if horizontal > 8 || vertical > 8 {
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

                        // Assigned directly — no animation. Wrapping this in an
                        // `interactiveSpring` put the card ~0.15s behind the
                        // finger for the whole drag, which is the single
                        // biggest reason a manual swipe felt heavy. A dragged
                        // card should be pinned to the touch, not chasing it.
                        offset = value.translation
                    }
                    .onEnded { value in
                        defer {
                            dragLocked = false
                            dragRejected = false
                        }
                        guard dragLocked else { return }
                        handleSwipeEnd(translation: value.translation, velocity: value.velocity)
                    },
                // Masked rather than conditionally attached: adding or removing
                // a gesture would change the view's structural identity, and a
                // card that changes identity on promotion is rebuilt from
                // scratch — the flash this whole arrangement exists to avoid.
                including: isActive ? .all : .none
            )
            // No implicit animation on `offset`. Every move that should animate
            // — spring-back, fly-off — states its own; the drag deliberately
            // doesn't. An implicit animation here competed with those explicit
            // transactions and re-animated the drag we just chose not to.
            .onChange(of: programmaticSwipe) { _, direction in
                guard isActive, let direction else { return }
                animateProgrammatic(direction: direction)
            }
    }

    // MARK: - Computed Properties

    /// Tilt with the drag, but never past `maxRotation`.
    ///
    /// This used to be unclamped, so at full exit travel the card reached 20° —
    /// double the stated maximum. A steeply rotated card sweeps a much wider
    /// footprint than its flat width, which is why it was still clipping the
    /// screen edge at the point the deck advanced.
    private var rotationAngle: Double {
        let progress = Double(offset.width) / 300
        return max(-maxRotation, min(maxRotation, progress * maxRotation))
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

        let exitDuration = SwipeExit.flightDuration(forReleaseVelocity: velocity.width)

        if horizontalAmount + velocityBoost > swipeThreshold {
            flyOff(direction: .right, startHeight: translation.height * 0.5, duration: exitDuration)
        } else if horizontalAmount + velocityBoost < -swipeThreshold {
            flyOff(direction: .left, startHeight: translation.height * 0.5, duration: exitDuration)
        } else {
            // Spring back with bounce
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                offset = .zero
            }
        }
    }

    /// Animate the card off-screen in the given direction, notifying the parent
    /// partway through so the next card starts coming forward while this one is
    /// still leaving. The two motions overlap rather than running back to back.
    private func flyOff(
        direction: SwipeDirection,
        startHeight: CGFloat = 0,
        duration: Double = SwipeExit.slowFlightDuration
    ) {
        let targetX: CGFloat = direction == .right ? SwipeExit.flightDistance : -SwipeExit.flightDistance

        withAnimation(.easeOut(duration: duration)) {
            offset = CGSize(width: targetX, height: startHeight)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration * SwipeExit.handoffFraction) {
            onSwipe(direction)
        }
    }

    /// External (button-tap) swipe. Stamps and leaves in one motion.
    private func animateProgrammatic(direction: SwipeDirection) {
        // Clear the binding right away so subsequent rapid taps all register
        // as fresh value changes, not deduped identical values.
        DispatchQueue.main.async {
            programmaticSwipe = nil
        }

        // Pin the stamp without waiting on it. The overlay fades it in over
        // 0.12s while the card is already moving; the previous version nudged
        // the card 120pt, waited a further 0.1s, and only then started the
        // exit — a tenth of a second of nothing happening on every tap.
        forcedStampDirection = direction

        flyOff(direction: direction, duration: SwipeExit.buttonFlightDuration)
    }
}

// MARK: - Movie Night Card Content

struct MovieNightCardContent: View {
    let movie: FFMovie
    let providers: [WatchProvider]
    let hasSeenIt: Bool
    var isOnWatchlist: Bool = false
    /// Only the top card casts one. A drop shadow forces an offscreen render
    /// pass per card per frame, and the stack's shadows are almost entirely
    /// occluded by the card in front anyway — three of them animating at once
    /// cost frames for something nobody can see. Kept as a *value* change
    /// rather than a conditional modifier so the view's identity is unaffected.
    var showsShadow: Bool = true
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
        .shadow(
            color: Color.black.opacity(showsShadow ? 0.35 : 0),
            radius: showsShadow ? 16 : 0,
            x: 0,
            y: showsShadow ? 8 : 0
        )
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
        // Both pills change width when they activate (they gain a label), and
        // the rating row appears with the seen state. Without these the change
        // lands as a hard snap — and the star row's transition never plays,
        // since nothing was driving an animation for it.
        .animation(FFAnimations.smooth, value: isOnWatchlist)
        .animation(FFAnimations.smooth, value: hasSeenIt)
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

    /// A film plus where it currently sits in the stack.
    ///
    /// A concrete `Identifiable` type rather than an index, because `ForEach`
    /// identity has to follow the *film*. Keying on the array index meant that
    /// after a swipe the element at index N+1 kept its identity while its
    /// content changed from a background card to the top card — SwiftUI tore
    /// the subtree down and rebuilt it, which reset the poster's
    /// `CachedAsyncImage` back to its placeholder and re-ran the insertion
    /// transition on a card the user could already see. That was the flash.
    private struct StackedCard: Identifiable {
        let movie: FFMovie
        let stackPosition: Int
        var id: Int { movie.tmdbId }
    }

    var body: some View {
        ZStack {
            // Every card — top or background — renders through the same
            // wrapper. Promotion is then just a change of modifier values
            // (scale, offset, opacity), which animates smoothly, instead of a
            // teardown and rebuild.
            ForEach(visibleCards) { card in
                SwipeCardView(
                    content: {
                        MovieNightCardContent(
                            movie: card.movie,
                            providers: providers[card.movie.tmdbId] ?? [],
                            hasSeenIt: seenMovies.contains(card.movie.tmdbId),
                            isOnWatchlist: watchlistMovies.contains(card.movie.tmdbId),
                            showsShadow: card.stackPosition == 0,
                            onToggleSeen: { onToggleSeen(card.movie.tmdbId) },
                            onToggleWatchlist: { onToggleWatchlist(card.movie.tmdbId) },
                            onTapDetail: { onTapDetail(card.movie) }
                        )
                    },
                    isActive: card.stackPosition == 0,
                    programmaticSwipe: card.stackPosition == 0 ? $programmaticSwipe : .constant(nil),
                    onSwipe: onSwipe
                )
                .scaleEffect(1.0 - CGFloat(card.stackPosition) * 0.04)
                .offset(y: CGFloat(card.stackPosition) * 10)
                .opacity(1.0 - Double(card.stackPosition) * 0.3)
                .zIndex(Double(-card.stackPosition))
                .allowsHitTesting(card.stackPosition == 0)
                // Only ever plays for a card entering the back of the stack or
                // the swiped card leaving it — both off-screen or fully behind
                // another card, so nothing visibly fades in place.
                .transition(.opacity)
            }
        }
        // Tightened from `response: 0.45`. The card behind only has to travel
        // 10pt and scale 4% to reach the front — at 0.45 that read as the deck
        // easing forward long after the swipe was over. High damping keeps it
        // from overshooting at the faster rate.
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: currentIndex)
    }

    private var visibleCards: [StackedCard] {
        let start = currentIndex
        let end = min(currentIndex + 3, movies.count)
        guard start < end else { return [] }
        return (start..<end).map {
            StackedCard(movie: movies[$0], stackPosition: $0 - currentIndex)
        }
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
