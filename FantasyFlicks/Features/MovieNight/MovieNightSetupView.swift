//
//  MovieNightSetupView.swift
//  FantasyFlicks
//
//  Multi-step setup flow for creating a Movie Night session
//

import SwiftUI

struct MovieNightSetupView: View {
    @ObservedObject var viewModel: MovieNightViewModel
    @State private var currentStep = 0
    @State private var filters = MovieNightFilters.default
    @State private var genres: [Genre] = []
    @State private var isLoadingGenres = true

    private let totalSteps = 4

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                progressBar

                // Step content
                Group {
                    switch currentStep {
                    case 0: genreSelectionStep
                    case 1: streamingStep
                    case 2: preferencesStep
                    case 3: reviewStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)

                // Navigation buttons
                navigationButtons
            }
        }
        .navigationTitle("Movie Night Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadGenres()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: FFSpacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? FFColors.goldGradientHorizontal : LinearGradient(colors: [FFColors.backgroundElevated2], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 4)
                    .animation(FFAnimations.smooth, value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.md)
    }

    // MARK: - Step 1: Genre Selection

    private var genreSelectionStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FFSpacing.xl) {
                stepHeader(
                    title: "Pick Your Genres",
                    subtitle: "What kind of movies are you in the mood for?"
                )

                if isLoadingGenres {
                    ProgressView()
                        .tint(FFColors.goldPrimary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: FFSpacing.md) {
                        ForEach(genres) { genre in
                            genreChip(genre: genre)
                        }
                    }
                }

                if filters.genreIds.isEmpty {
                    Text("Skip to include all genres")
                        .font(FFTypography.bodySmall)
                        .foregroundColor(FFColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    private func genreChip(genre: Genre) -> some View {
        let isSelected = filters.genreIds.contains(genre.id)

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if isSelected {
                    filters.genreIds.removeAll { $0 == genre.id }
                } else {
                    filters.genreIds.append(genre.id)
                }
            }
        } label: {
            Text(genre.name)
                .font(FFTypography.labelMedium)
                .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, FFSpacing.sm)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        Capsule().fill(FFColors.goldGradientHorizontal)
                    } else {
                        Capsule().fill(FFColors.backgroundElevated)
                    }
                }
                .overlay {
                    if !isSelected {
                        Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Streaming Services

    private var streamingStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FFSpacing.xl) {
                stepHeader(
                    title: "Streaming Services",
                    subtitle: "Which services do you have access to?"
                )

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: FFSpacing.md) {
                    ForEach(StreamingProvider.allCases) { provider in
                        streamingProviderCard(provider: provider)
                    }
                }

                if filters.watchProviderIds.isEmpty {
                    Text("Skip to include all services")
                        .font(FFTypography.bodySmall)
                        .foregroundColor(FFColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    private func streamingProviderCard(provider: StreamingProvider) -> some View {
        let isSelected = filters.watchProviderIds.contains(provider.id)

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if isSelected {
                    filters.watchProviderIds.removeAll { $0 == provider.id }
                } else {
                    filters.watchProviderIds.append(provider.id)
                }
            }
        } label: {
            HStack(spacing: FFSpacing.md) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? FFColors.backgroundDark : Color(hex: provider.color))
                    .frame(width: 32)

                Text(provider.name)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(FFColors.backgroundDark)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(isSelected
                        ? AnyShapeStyle(FFColors.goldGradientHorizontal)
                        : AnyShapeStyle(FFColors.backgroundElevated))
            }
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Preferences

    private var preferencesStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FFSpacing.xxl) {
                stepHeader(
                    title: "Fine-Tune",
                    subtitle: "Set your quality bar and sources"
                )

                // Rating threshold
                GlassCard {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(FFColors.goldPrimary)
                            Text("Minimum Rating")
                                .font(FFTypography.titleSmall)
                                .foregroundColor(FFColors.textPrimary)
                            Spacer()
                            Text(String(format: "%.1f+", filters.minVoteAverage))
                                .font(FFTypography.statSmall)
                                .foregroundColor(FFColors.goldPrimary)
                        }

                        Slider(value: $filters.minVoteAverage, in: 4.0...8.5, step: 0.5)
                            .tint(FFColors.goldPrimary)

                        HStack {
                            Text("More movies")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                            Spacer()
                            Text("Higher quality")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal)

                // Source toggles
                GlassCard {
                    VStack(spacing: FFSpacing.lg) {
                        Toggle(isOn: $filters.includeTrending) {
                            HStack(spacing: FFSpacing.md) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(FFColors.ruby)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Include Trending")
                                        .font(FFTypography.labelLarge)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("Popular movies this week")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                        }
                        .tint(FFColors.goldPrimary)

                        Divider().background(Color.white.opacity(0.1))

                        Toggle(isOn: $filters.includeNowPlaying) {
                            HStack(spacing: FFSpacing.md) {
                                Image(systemName: "popcorn.fill")
                                    .foregroundColor(FFColors.goldPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Include Now Playing")
                                        .font(FFTypography.labelLarge)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("Currently in theaters")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                        }
                        .tint(FFColors.goldPrimary)

                        Divider().background(Color.white.opacity(0.1))

                        Toggle(isOn: $filters.excludeSeenMovies) {
                            HStack(spacing: FFSpacing.md) {
                                Image(systemName: "eye.slash.fill")
                                    .foregroundColor(FFColors.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Exclude Watched Movies")
                                        .font(FFTypography.labelLarge)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("\(SeenMoviesService.shared.count) movies tracked in your profile")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                        }
                        .tint(FFColors.goldPrimary)
                    }
                }
                .padding(.horizontal)

                // Deck size
                GlassCard {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        HStack {
                            Image(systemName: "square.stack.fill")
                                .foregroundColor(FFColors.goldPrimary)
                            Text("Deck Size")
                                .font(FFTypography.titleSmall)
                                .foregroundColor(FFColors.textPrimary)
                            Spacer()
                            Text("\(filters.deckSize) movies")
                                .font(FFTypography.statSmall)
                                .foregroundColor(FFColors.goldPrimary)
                        }

                        Slider(value: Binding(
                            get: { Double(filters.deckSize) },
                            set: { filters.deckSize = Int($0) }
                        ), in: 10...40, step: 5)
                            .tint(FFColors.goldPrimary)

                        HStack {
                            Text("Quick session")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                            Spacer()
                            Text("More options")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Step 5: Review

    private var reviewStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FFSpacing.xl) {
                stepHeader(
                    title: "Ready to Go!",
                    subtitle: "Here's your Movie Night setup"
                )

                GlassCard(goldTint: true) {
                    VStack(alignment: .leading, spacing: FFSpacing.lg) {
                        reviewRow(
                            icon: "theatermasks.fill",
                            title: "Genres",
                            value: filters.genreIds.isEmpty
                                ? "All genres"
                                : genres.filter { filters.genreIds.contains($0.id) }.map { $0.name }.joined(separator: ", ")
                        )

                        Divider().background(Color.white.opacity(0.1))

                        reviewRow(
                            icon: "play.tv.fill",
                            title: "Services",
                            value: filters.watchProviderIds.isEmpty
                                ? "All services"
                                : StreamingProvider.allCases
                                    .filter { filters.watchProviderIds.contains($0.id) }
                                    .map { $0.name }
                                    .joined(separator: ", ")
                        )

                        Divider().background(Color.white.opacity(0.1))

                        reviewRow(
                            icon: "eye.slash.fill",
                            title: "Seen Movies",
                            value: filters.excludeSeenMovies
                                ? "Excluding \(SeenMoviesService.shared.count) watched movies"
                                : "Including all movies"
                        )

                        Divider().background(Color.white.opacity(0.1))

                        reviewRow(
                            icon: "star.fill",
                            title: "Min Rating",
                            value: String(format: "%.1f+", filters.minVoteAverage)
                        )

                        Divider().background(Color.white.opacity(0.1))

                        reviewRow(
                            icon: "square.stack.fill",
                            title: "Deck Size",
                            value: "\(filters.deckSize) movies"
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func reviewRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: FFSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(FFColors.goldPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textTertiary)
                Text(value)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: FFSpacing.md) {
            if currentStep > 0 {
                GoldButton(title: "Back", style: .secondary, size: .medium) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                }
            }

            if currentStep < totalSteps - 1 {
                GoldButton(title: "Next", style: .primary, size: .medium, fullWidth: true) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                }
            } else {
                GoldButton(
                    title: viewModel.isLoading ? "Creating..." : "Create Movie Night",
                    icon: "party.popper.fill",
                    style: .ruby,
                    size: .large,
                    isLoading: viewModel.isLoading,
                    fullWidth: true
                ) {
                    Task { await viewModel.createSession(filters: filters) }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            Text(title)
                .font(FFTypography.displaySmall)
                .foregroundColor(FFColors.textPrimary)
            Text(subtitle)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
        }
    }

    private func loadGenres() async {
        do {
            genres = try await TMDBService.shared.getGenres()
        } catch {
            genres = [
                Genre(id: 28, name: "Action"),
                Genre(id: 12, name: "Adventure"),
                Genre(id: 16, name: "Animation"),
                Genre(id: 35, name: "Comedy"),
                Genre(id: 80, name: "Crime"),
                Genre(id: 18, name: "Drama"),
                Genre(id: 14, name: "Fantasy"),
                Genre(id: 27, name: "Horror"),
                Genre(id: 9648, name: "Mystery"),
                Genre(id: 10749, name: "Romance"),
                Genre(id: 878, name: "Sci-Fi"),
                Genre(id: 53, name: "Thriller")
            ]
        }
        isLoadingGenres = false
    }
}
