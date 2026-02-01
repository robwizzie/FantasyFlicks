//
//  MoviePosterCard.swift
//  FantasyFlicks
//
//  Movie poster card component with various display modes
//

import SwiftUI

/// Display size for movie poster cards
enum MoviePosterSize {
    case small       // For lists, grids
    case medium      // For carousels
    case large       // For featured displays
    case backdrop    // Wide format for headers

    var width: CGFloat {
        switch self {
        case .small: return 100
        case .medium: return 140
        case .large: return 200
        case .backdrop: return 300
        }
    }

    var height: CGFloat {
        switch self {
        case .small: return 150
        case .medium: return 210
        case .large: return 300
        case .backdrop: return 170
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .backdrop: return 16
        }
    }
}

/// Movie poster card with hover effects and optional info overlay
struct MoviePosterCard: View {
    let movie: FFMovie
    var size: MoviePosterSize = .medium
    var showTitle: Bool = true
    var showDraftedBadge: Bool = true
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                // Poster image
                posterImage
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)

                // Title and info
                if showTitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(movie.title)
                            .font(size == .small ? FFTypography.labelSmall : FFTypography.labelMedium)
                            .foregroundColor(FFColors.textPrimary)
                            .lineLimit(2)

                        if let date = movie.releaseDate {
                            Text(date, format: .dateTime.month(.abbreviated).day().year())
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textSecondary)
                        }
                    }
                    .frame(width: size.width, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .pressEffect()
    }

    @ViewBuilder
    private var posterImage: some View {
        ZStack {
            // Poster
            if let posterURL = movie.posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }

            // Gradient overlay at bottom
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, FFColors.backgroundDark.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: size.height * 0.3)
            }

            // Drafted badge
            if showDraftedBadge && movie.isDrafted {
                VStack {
                    HStack {
                        Spacer()
                        draftedBadge
                    }
                    Spacer()
                }
                .padding(FFSpacing.sm)
            }
        }
    }

    private var placeholderView: some View {
        ZStack {
            FFColors.backgroundElevated

            VStack(spacing: FFSpacing.sm) {
                Image(systemName: "film")
                    .font(.system(size: size == .small ? 24 : 36))
                    .foregroundColor(FFColors.textTertiary)

                if size != .small {
                    Text(movie.title)
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FFSpacing.sm)
                }
            }
        }
    }

    private var draftedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
            Text("DRAFTED")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundColor(FFColors.backgroundDark)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(FFColors.goldGradientHorizontal)
        .clipShape(Capsule())
    }
}

// MARK: - Horizontal Movie Carousel

struct MovieCarousel: View {
    let title: String
    let movies: [FFMovie]
    var size: MoviePosterSize = .medium
    var onMovieTap: ((FFMovie) -> Void)?
    var onSeeAllTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            // Header
            HStack {
                Text(title)
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if onSeeAllTap != nil {
                    Button {
                        onSeeAllTap?()
                    } label: {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(FFTypography.labelMedium)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
            .padding(.horizontal)

            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FFSpacing.md) {
                    ForEach(movies) { movie in
                        MoviePosterCard(movie: movie, size: size) {
                            onMovieTap?(movie)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Featured Movie Card

struct FeaturedMovieCard: View {
    let movie: FFMovie
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Backdrop image
                if let backdropURL = movie.backdropURL {
                    CachedAsyncImage(url: backdropURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        FFColors.backgroundElevated
                    }
                } else if let posterURL = movie.posterURL {
                    CachedAsyncImage(url: posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        FFColors.backgroundElevated
                    }
                } else {
                    FFColors.backgroundElevated
                }

                // Gradient overlay
                LinearGradient(
                    colors: [
                        .clear,
                        FFColors.backgroundDark.opacity(0.6),
                        FFColors.backgroundDark.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    // Badges
                    HStack(spacing: FFSpacing.sm) {
                        if movie.isDrafted {
                            Badge(text: "Drafted", style: .gold)
                        }

                        if movie.isReleased {
                            Badge(text: "Now Playing", style: .ruby)
                        }
                    }

                    Text(movie.title)
                        .font(FFTypography.headlineLarge)
                        .foregroundColor(FFColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: FFSpacing.md) {
                        if let director = movie.director {
                            Label(director, systemImage: "video.fill")
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.textSecondary)
                        }

                        if let year = movie.year {
                            Text(String(year))
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.textSecondary)
                        }
                    }
                }
                .padding(FFSpacing.xl)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.xxl))
            .overlay {
                RoundedRectangle(cornerRadius: FFCornerRadius.xxl)
                    .stroke(FFColors.goldPrimary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .pressEffect()
    }
}

// MARK: - Badge Component

struct Badge: View {
    let text: String
    var style: BadgeStyle = .default

    enum BadgeStyle {
        case `default`
        case gold
        case ruby
        case success
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch style {
        case .default: return FFColors.textPrimary
        case .gold: return FFColors.backgroundDark
        case .ruby: return .white
        case .success: return .white
        }
    }

    private var backgroundColor: some View {
        Group {
            switch style {
            case .default:
                Color.white.opacity(0.2)
            case .gold:
                FFColors.goldGradientHorizontal
            case .ruby:
                FFColors.ruby
            case .success:
                FFColors.success
            }
        }
    }
}

// MARK: - Previews

#Preview("Movie Poster Cards") {
    ZStack {
        FFColors.backgroundDark.ignoresSafeArea()

        ScrollView {
            VStack(spacing: FFSpacing.xxl) {
                // Carousel
                MovieCarousel(
                    title: "Upcoming Releases",
                    movies: FFMovie.sampleMovies,
                    onSeeAllTap: {}
                )

                // Featured
                FeaturedMovieCard(movie: .sample)
                    .padding(.horizontal)

                // Size variants
                HStack(spacing: FFSpacing.md) {
                    MoviePosterCard(movie: .sample, size: .small)
                    MoviePosterCard(movie: .sample, size: .medium)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}
