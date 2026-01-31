//
//  MoviesView.swift
//  FantasyFlicks
//
//  Movies tab - browse and search movies
//

import SwiftUI

struct MoviesView: View {
    @State private var searchText = ""
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedGenre: Int? = nil
    @State private var showFilters = false

    private let movies = FFMovie.sampleMovies
    private let years = Array((2024...2027).reversed())
    private let genres = [
        (28, "Action"),
        (12, "Adventure"),
        (16, "Animation"),
        (35, "Comedy"),
        (18, "Drama"),
        (14, "Fantasy"),
        (27, "Horror"),
        (878, "Sci-Fi"),
        (53, "Thriller")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FFSpacing.xl) {
                        // Year selector
                        yearSelector

                        // Genre filter
                        genreFilter

                        // Featured movie
                        if let featured = movies.first {
                            FeaturedMovieCard(movie: featured) {
                                // Navigate to detail
                            }
                            .padding(.horizontal)
                        }

                        // Movie grid
                        movieGrid

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Movies")
            .searchable(text: $searchText, prompt: "Search movies")
        }
    }

    private var yearSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                ForEach(years, id: \.self) { year in
                    Button {
                        withAnimation(FFAnimations.snappy) {
                            selectedYear = year
                        }
                    } label: {
                        Text("\(year)")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(selectedYear == year ? FFColors.backgroundDark : FFColors.textSecondary)
                            .padding(.horizontal, FFSpacing.lg)
                            .padding(.vertical, FFSpacing.sm)
                            .background {
                                if selectedYear == year {
                                    Capsule().fill(FFColors.goldGradientHorizontal)
                                } else {
                                    Capsule()
                                        .fill(FFColors.backgroundElevated)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var genreFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                // All genres
                FilterChip(title: "All", isSelected: selectedGenre == nil) {
                    withAnimation(FFAnimations.snappy) {
                        selectedGenre = nil
                    }
                }

                ForEach(genres, id: \.0) { genre in
                    FilterChip(title: genre.1, isSelected: selectedGenre == genre.0) {
                        withAnimation(FFAnimations.snappy) {
                            selectedGenre = genre.0
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var movieGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: FFSpacing.md),
            GridItem(.flexible(), spacing: FFSpacing.md),
            GridItem(.flexible(), spacing: FFSpacing.md)
        ], spacing: FFSpacing.lg) {
            ForEach(movies) { movie in
                MoviePosterCard(movie: movie, size: .small) {
                    // Navigate to detail
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Movie Detail View

struct MovieDetailView: View {
    let movie: FFMovie

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero backdrop
                    if let backdropURL = movie.backdropURL {
                        CachedAsyncImage(url: backdropURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            FFColors.backgroundElevated
                        }
                        .frame(height: 250)
                        .overlay {
                            LinearGradient(
                                colors: [.clear, FFColors.backgroundDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: FFSpacing.xl) {
                        // Title section
                        HStack(alignment: .bottom, spacing: FFSpacing.lg) {
                            // Poster
                            if let posterURL = movie.posterURL {
                                CachedAsyncImage(url: posterURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    FFColors.backgroundElevated
                                }
                                .frame(width: 100, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                                .shadow(color: .black.opacity(0.3), radius: 10)
                                .offset(y: -60)
                            }

                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                Text(movie.title)
                                    .font(FFTypography.headlineLarge)
                                    .foregroundColor(FFColors.textPrimary)

                                HStack(spacing: FFSpacing.md) {
                                    if let year = movie.year {
                                        Text("\(year)")
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.textSecondary)
                                    }

                                    if let runtime = movie.formattedRuntime {
                                        Text(runtime)
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.textSecondary)
                                    }

                                    if let cert = movie.certification {
                                        Text(cert)
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(FFColors.textSecondary, lineWidth: 1)
                                            }
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal)

                        // Overview
                        VStack(alignment: .leading, spacing: FFSpacing.sm) {
                            Text("Overview")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            Text(movie.overview)
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textSecondary)
                        }
                        .padding(.horizontal)

                        // Genres
                        if !movie.genres.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: FFSpacing.sm) {
                                    ForEach(movie.genres) { genre in
                                        Text(genre.name)
                                            .font(FFTypography.labelSmall)
                                            .foregroundColor(FFColors.goldPrimary)
                                            .padding(.horizontal, FFSpacing.md)
                                            .padding(.vertical, FFSpacing.sm)
                                            .background {
                                                Capsule()
                                                    .fill(FFColors.goldPrimary.opacity(0.15))
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Cast
                        if !movie.cast.isEmpty {
                            VStack(alignment: .leading, spacing: FFSpacing.md) {
                                Text("Cast")
                                    .font(FFTypography.headlineSmall)
                                    .foregroundColor(FFColors.textPrimary)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: FFSpacing.md) {
                                        ForEach(movie.topBilledCast) { cast in
                                            VStack(spacing: FFSpacing.sm) {
                                                Circle()
                                                    .fill(FFColors.backgroundElevated)
                                                    .frame(width: 60, height: 60)
                                                    .overlay {
                                                        Image(systemName: "person.fill")
                                                            .foregroundColor(FFColors.textTertiary)
                                                    }

                                                VStack(spacing: 2) {
                                                    Text(cast.name)
                                                        .font(FFTypography.labelSmall)
                                                        .foregroundColor(FFColors.textPrimary)
                                                        .lineLimit(1)

                                                    Text(cast.character)
                                                        .font(FFTypography.caption)
                                                        .foregroundColor(FFColors.textTertiary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(width: 80)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    MoviesView()
        .ffTheme()
}
