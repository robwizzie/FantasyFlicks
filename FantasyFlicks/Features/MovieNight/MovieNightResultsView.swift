//
//  MovieNightResultsView.swift
//  FantasyFlicks
//
//  Results dashboard showing match scores after everyone finishes swiping
//

import SwiftUI

struct MovieNightResultsView: View {
    @ObservedObject var viewModel: MovieNightViewModel
    @State private var sortOption: MovieNightSortOption = .matchScore
    @State private var sortAscending = false
    @State private var expandedResultId: Int?

    private var sortedResults: [MovieNightResult] {
        let results = viewModel.results
        let sorted: [MovieNightResult]
        switch sortOption {
        case .matchScore:
            sorted = results.sorted {
                if $0.matchScore != $1.matchScore {
                    return sortAscending ? $0.matchScore < $1.matchScore : $0.matchScore > $1.matchScore
                }
                return $0.movie.voteAverage > $1.movie.voteAverage
            }
        case .rating:
            sorted = results.sorted {
                sortAscending ? $0.movie.voteAverage < $1.movie.voteAverage : $0.movie.voteAverage > $1.movie.voteAverage
            }
        case .title:
            sorted = results.sorted {
                sortAscending ? $0.movie.title < $1.movie.title : $0.movie.title > $1.movie.title
            }
        case .year:
            sorted = results.sorted {
                let y0 = $0.movie.year ?? 0
                let y1 = $1.movie.year ?? 0
                return sortAscending ? y0 < y1 : y0 > y1
            }
        }
        return sorted
    }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: FFSpacing.xl) {
                    // Header
                    resultsHeader

                    // Top pick hero
                    if let topResult = viewModel.results.first {
                        topPickSection(result: topResult)
                    }

                    // Sort controls (host gets full controls, others get display)
                    sortControls

                    // Full ranked list
                    rankedListSection

                    // Action buttons
                    actionButtons

                    Spacer(minLength: 100)
                }
                .padding(.top, FFSpacing.lg)
            }

            // Celebration overlay
            if viewModel.showCelebration, let movie = viewModel.celebrationMovie {
                MatchCelebrationView(
                    movieTitle: movie.title,
                    posterURL: movie.posterURL,
                    onDismiss: { viewModel.showCelebration = false }
                )
                .transition(FFTransitions.scaleAndFade)
                .zIndex(100)
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var resultsHeader: some View {
        VStack(spacing: FFSpacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 44))
                .foregroundStyle(FFColors.goldGradient)

            if let topResult = viewModel.results.first, topResult.isUnanimous {
                Text("Perfect Match!")
                    .font(FFTypography.displaySmall)
                    .foregroundColor(FFColors.textPrimary)
            } else if let topResult = viewModel.results.first, topResult.matchScore > 0.5 {
                Text("Top Picks Found!")
                    .font(FFTypography.displaySmall)
                    .foregroundColor(FFColors.textPrimary)
            } else {
                Text("Here's What Came Closest")
                    .font(FFTypography.headlineLarge)
                    .foregroundColor(FFColors.textPrimary)
            }

            if let session = viewModel.session {
                Text(session.participantCount == 1
                     ? "You swiped on \(viewModel.deckMovies.count) movies"
                     : "\(session.participantCount) people swiped on \(viewModel.deckMovies.count) movies")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Top Pick

    private func topPickSection(result: MovieNightResult) -> some View {
        VStack(spacing: FFSpacing.md) {
            ZStack(alignment: .bottom) {
                if let posterURL = result.movie.posterURL {
                    CachedAsyncImage(url: posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        FFColors.backgroundElevated
                    }
                    .frame(height: 280)
                    .clipped()
                }

                LinearGradient(
                    colors: [.clear, FFColors.backgroundDark.opacity(0.9)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(spacing: FFSpacing.sm) {
                    if result.isUnanimous {
                        Badge(text: "Everyone Agrees!", style: .gold)
                    } else {
                        Badge(text: "\(result.matchPercentage)% Match", style: .gold)
                    }

                    Text(result.movie.title)
                        .font(FFTypography.headlineLarge)
                        .foregroundColor(FFColors.textPrimary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: FFSpacing.md) {
                        if let year = result.movie.year {
                            Text(String(year))
                                .foregroundColor(FFColors.textSecondary)
                        }
                        if result.movie.voteAverage > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(FFColors.goldPrimary)
                                Text(String(format: "%.1f", result.movie.voteAverage))
                                    .foregroundColor(FFColors.goldLight)
                            }
                        }
                    }
                    .font(FFTypography.labelMedium)

                    // Who swiped right on this movie
                    whoSwipedSection(result: result)

                    if !result.streamingProviders.isEmpty {
                        HStack(spacing: FFSpacing.sm) {
                            ForEach(result.streamingProviders.prefix(4)) { provider in
                                if let logoURL = provider.logoURL {
                                    CachedAsyncImage(url: logoURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        Circle().fill(FFColors.backgroundElevated2)
                                    }
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                }
                .padding(FFSpacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.xxl))
            .overlay {
                RoundedRectangle(cornerRadius: FFCornerRadius.xxl)
                    .stroke(
                        result.isUnanimous
                            ? FFColors.goldGradient
                            : LinearGradient(colors: [Color.white.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                        lineWidth: result.isUnanimous ? 2 : 1
                    )
            }
            .shadow(
                color: result.isUnanimous ? FFColors.goldPrimary.opacity(0.3) : .clear,
                radius: 20, x: 0, y: 0
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Who Swiped Section

    private func whoSwipedSection(result: MovieNightResult) -> some View {
        HStack(spacing: FFSpacing.xs) {
            if let session = viewModel.session {
                ForEach(session.participantIds, id: \.self) { userId in
                    let swipedRight = result.swipedRightBy.contains(userId)
                    let name = session.participantNames[userId] ?? "?"

                    HStack(spacing: 3) {
                        Image(systemName: swipedRight ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.system(size: 9))
                        Text(String(name.prefix(8)))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(swipedRight ? FFColors.goldPrimary : FFColors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (swipedRight ? FFColors.goldPrimary : FFColors.textTertiary).opacity(0.15)
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Sort Controls

    private var sortControls: some View {
        HStack(spacing: FFSpacing.sm) {
            Text("Sort by")
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textTertiary)

            Menu {
                ForEach(MovieNightSortOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if sortOption == option {
                                sortAscending.toggle()
                            } else {
                                sortOption = option
                                sortAscending = false
                            }
                        }
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOption.rawValue)
                        .font(FFTypography.labelMedium)
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(FFColors.goldPrimary)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, FFSpacing.xs)
                .background(FFColors.goldPrimary.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Ranked List

    private var rankedListSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            Text("All Results")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            ForEach(Array(sortedResults.enumerated()), id: \.element.id) { index, result in
                resultRow(result: result, rank: index + 1)
            }
        }
    }

    private func resultRow(result: MovieNightResult, rank: Int) -> some View {
        let isExpanded = expandedResultId == result.id

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                expandedResultId = isExpanded ? nil : result.id
            }
        } label: {
            VStack(spacing: 0) {
                // Main row
                HStack(spacing: FFSpacing.sm) {
                    // Rank
                    Text("\(rank)")
                        .font(FFTypography.statSmall)
                        .foregroundColor(rank <= 3 ? FFColors.goldPrimary : FFColors.textTertiary)
                        .frame(width: 24)

                    // Poster thumbnail
                    if let posterURL = result.movie.posterURL {
                        CachedAsyncImage(url: posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            FFColors.backgroundElevated
                        }
                        .frame(width: 44, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: FFSpacing.xs) {
                        Text(result.movie.title)
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.textPrimary)
                            .lineLimit(1)

                        // Match bar
                        HStack(spacing: FFSpacing.sm) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(FFColors.backgroundElevated2)
                                        .frame(height: 5)
                                    Capsule()
                                        .fill(matchBarColor(score: result.matchScore))
                                        .frame(width: geo.size.width * result.matchScore, height: 5)
                                }
                            }
                            .frame(height: 5)

                            Text("\(result.matchPercentage)%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(FFColors.goldPrimary)
                                .frame(width: 32, alignment: .trailing)
                        }

                        // Compact who-swiped indicators
                        HStack(spacing: 3) {
                            if let session = viewModel.session {
                                ForEach(session.participantIds, id: \.self) { userId in
                                    let swipedRight = result.swipedRightBy.contains(userId)
                                    Circle()
                                        .fill(swipedRight ? FFColors.goldPrimary : FFColors.backgroundElevated2)
                                        .frame(width: 14, height: 14)
                                        .overlay {
                                            Image(systemName: swipedRight ? "checkmark" : "xmark")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundColor(swipedRight ? FFColors.backgroundDark : FFColors.textTertiary)
                                        }
                                }
                            }

                            if !result.streamingProviders.isEmpty {
                                Spacer()
                                HStack(spacing: 3) {
                                    ForEach(result.streamingProviders.prefix(3)) { provider in
                                        if let logoURL = provider.logoURL {
                                            CachedAsyncImage(url: logoURL) { image in
                                                image.resizable().aspectRatio(contentMode: .fit)
                                            } placeholder: {
                                                Circle().fill(FFColors.backgroundElevated2)
                                            }
                                            .frame(width: 16, height: 16)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(FFColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                // Expanded detail - who picked what
                if isExpanded {
                    VStack(alignment: .leading, spacing: FFSpacing.sm) {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, FFSpacing.xs)

                        if let session = viewModel.session {
                            ForEach(session.participantIds, id: \.self) { userId in
                                let swipedRight = result.swipedRightBy.contains(userId)
                                let hasSeen = result.seenBy.contains(userId)
                                let name = session.participantNames[userId] ?? "Player"

                                HStack(spacing: FFSpacing.sm) {
                                    Circle()
                                        .fill(FFColors.goldPrimary.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            Text(String(name.prefix(1)).uppercased())
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(FFColors.goldPrimary)
                                        }

                                    Text(name)
                                        .font(FFTypography.labelMedium)
                                        .foregroundColor(FFColors.textPrimary)

                                    Spacer()

                                    if hasSeen {
                                        HStack(spacing: 3) {
                                            Image(systemName: "eye.fill")
                                                .font(.system(size: 10))
                                            Text("Seen")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(FFColors.textTertiary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(FFColors.backgroundElevated2)
                                        .clipShape(Capsule())
                                    }

                                    HStack(spacing: 3) {
                                        Image(systemName: swipedRight ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                            .font(.system(size: 12))
                                        Text(swipedRight ? "Watch" : "Skip")
                                            .font(FFTypography.labelSmall)
                                    }
                                    .foregroundColor(swipedRight ? FFColors.success : FFColors.ruby)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        (swipedRight ? FFColors.success : FFColors.ruby).opacity(0.12)
                                    )
                                    .clipShape(Capsule())
                                }
                            }
                        }

                        // Movie meta
                        HStack(spacing: FFSpacing.md) {
                            if let year = result.movie.year {
                                Text(String(year))
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                            }
                            if result.movie.voteAverage > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(FFColors.goldPrimary)
                                    Text(String(format: "%.1f", result.movie.voteAverage))
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.goldLight)
                                }
                            }
                            if let runtime = result.movie.formattedRuntime {
                                Text(runtime)
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                            }
                        }

                        if !result.movie.overview.isEmpty {
                            Text(result.movie.overview)
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textSecondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.top, FFSpacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(FFSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(FFColors.backgroundElevated.opacity(0.5))
            }
            .overlay {
                if result.isUnanimous {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(FFColors.goldPrimary.opacity(0.4), lineWidth: 1)
                }
            }
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private func matchBarColor(score: Double) -> LinearGradient {
        if score >= 1.0 {
            return FFColors.goldGradientHorizontal
        } else if score >= 0.5 {
            return LinearGradient(colors: [FFColors.goldPrimary, FFColors.goldLight], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [FFColors.textTertiary], startPoint: .leading, endPoint: .trailing)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: FFSpacing.md) {
            GoldButton(
                title: "Play Again",
                icon: "arrow.clockwise",
                style: .primary,
                size: .large,
                fullWidth: true
            ) {
                Task { await viewModel.playAgain() }
            }

            GoldButton(
                title: "Share Results",
                icon: "square.and.arrow.up",
                style: .secondary,
                size: .medium,
                fullWidth: true
            ) {
                // Share results
            }
        }
        .padding(.horizontal)
    }
}
