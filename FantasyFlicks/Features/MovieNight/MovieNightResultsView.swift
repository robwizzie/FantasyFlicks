//
//  MovieNightResultsView.swift
//  FantasyFlicks
//
//  Celebratory results with inline-expandable rows and per-user breakdown
//

import SwiftUI

struct MovieNightResultsView: View {
    @ObservedObject var viewModel: MovieNightViewModel
    @State private var sortOption: MovieNightSortOption = .matchScore
    @State private var sortAscending = false
    @State private var expandedResultId: Int?
    @State private var revealWinner = false

    private var sortedResults: [MovieNightResult] {
        let results = viewModel.results
        switch sortOption {
        case .matchScore:
            return results.sorted {
                if $0.matchScore != $1.matchScore {
                    return sortAscending ? $0.matchScore < $1.matchScore : $0.matchScore > $1.matchScore
                }
                return $0.movie.voteAverage > $1.movie.voteAverage
            }
        case .rating:
            return results.sorted {
                sortAscending ? $0.movie.voteAverage < $1.movie.voteAverage : $0.movie.voteAverage > $1.movie.voteAverage
            }
        case .title:
            return results.sorted {
                sortAscending ? $0.movie.title < $1.movie.title : $0.movie.title > $1.movie.title
            }
        case .year:
            return results.sorted {
                let y0 = $0.movie.year ?? 0
                let y1 = $1.movie.year ?? 0
                return sortAscending ? y0 < y1 : y0 > y1
            }
        }
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: FFSpacing.xxl, pinnedViews: []) {
                    celebratoryHeader

                    if let top = viewModel.results.first {
                        winnerCard(result: top)
                    }

                    if let session = viewModel.session, session.participantCount > 1 {
                        perUserSection
                    }

                    rankedListSection

                    actionButtons

                    Spacer(minLength: 100)
                }
                .padding(.top, FFSpacing.md)
            }

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
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25)) {
                revealWinner = true
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()
            VStack {
                EllipticalGradient(
                    colors: [
                        FFColors.goldPrimary.opacity(0.22),
                        FFColors.ruby.opacity(0.08),
                        Color.clear
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.6
                )
                .frame(height: 520)
                .blur(radius: 60)
                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var celebratoryHeader: some View {
        VStack(spacing: FFSpacing.md) {
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.18))
                    .frame(width: 96, height: 96)
                    .blur(radius: 18)

                Image(systemName: headerIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(FFColors.goldGradient)
                    .scaleEffect(revealWinner ? 1.0 : 0.5)
                    .opacity(revealWinner ? 1.0 : 0.0)
            }

            Text(headerTitle)
                .font(FFTypography.displaySmall)
                .foregroundColor(FFColors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(revealWinner ? 1.0 : 0.0)

            if let session = viewModel.session {
                Text(headerSubtitle(session: session))
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(revealWinner ? 1.0 : 0.0)
            }
        }
        .padding(.horizontal, FFSpacing.xl)
    }

    private var headerIcon: String {
        guard let top = viewModel.results.first else { return "popcorn.fill" }
        if top.isUnanimous { return "sparkles" }
        if top.matchScore > 0.5 { return "trophy.fill" }
        return "film.fill"
    }

    private var headerTitle: String {
        guard let top = viewModel.results.first else { return "No Results" }
        if top.isUnanimous { return "Perfect Match!" }
        if top.matchScore > 0.5 { return "You've Got a Winner!" }
        return "Here's What Came Closest"
    }

    private func headerSubtitle(session: MovieNightSession) -> String {
        let deckCount = viewModel.deckMovies.count
        if session.participantCount == 1 {
            return "You swiped on \(deckCount) movie\(deckCount == 1 ? "" : "s")"
        }
        return "\(session.participantCount) people • \(deckCount) movies"
    }

    // MARK: - Winner Card

    private func winnerCard(result: MovieNightResult) -> some View {
        VStack(spacing: FFSpacing.lg) {
            // Winner badge
            HStack(spacing: FFSpacing.xs) {
                Image(systemName: result.isUnanimous ? "sparkles" : "crown.fill")
                    .font(.system(size: 11))
                Text(result.isUnanimous ? "UNANIMOUS" : "TOP PICK")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.5)
            }
            .foregroundColor(FFColors.backgroundDark)
            .padding(.horizontal, FFSpacing.md)
            .padding(.vertical, 6)
            .background(Capsule().fill(FFColors.goldGradient))

            // Poster
            if let posterURL = result.movie.posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: FFCornerRadius.xl)
                        .fill(FFColors.backgroundElevated)
                        .aspectRatio(2/3, contentMode: .fit)
                }
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.xl))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.xl)
                        .stroke(
                            result.isUnanimous ? FFColors.goldGradient : LinearGradient(colors: [Color.white.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                            lineWidth: result.isUnanimous ? 3 : 1
                        )
                }
                .shadow(color: FFColors.goldPrimary.opacity(result.isUnanimous ? 0.55 : 0.25),
                        radius: 30, x: 0, y: 12)
                .scaleEffect(revealWinner ? 1.0 : 0.75)
                .opacity(revealWinner ? 1.0 : 0.0)
            }

            // Title
            Text(result.movie.title)
                .font(FFTypography.headlineLarge)
                .foregroundColor(FFColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FFSpacing.lg)

            // Metadata
            HStack(spacing: FFSpacing.md) {
                if let year = result.movie.year {
                    Text(String(year))
                        .foregroundColor(FFColors.textSecondary)
                }

                if result.movie.voteAverage > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundColor(FFColors.goldPrimary)
                            .font(.system(size: 11))
                        Text(String(format: "%.1f", result.movie.voteAverage))
                            .foregroundColor(FFColors.goldLight)
                    }
                }

                if let runtime = result.movie.formattedRuntime {
                    Text(runtime)
                        .foregroundColor(FFColors.textTertiary)
                }
            }
            .font(FFTypography.labelMedium)

            // Match percentage
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(result.matchPercentage)%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(FFColors.goldGradient)
                Text("match")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textSecondary)
            }

            // Streaming providers (capped with "+N more")
            if !result.streamingProviders.isEmpty {
                streamingRow(providers: result.streamingProviders, size: 28, max: 5)
            }
        }
        .padding(.horizontal, FFSpacing.lg)
    }

    // MARK: - Per User Section

    private var perUserSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack(spacing: FFSpacing.sm) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(FFColors.goldPrimary)
                Text("Who Voted for What")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
            }
            .padding(.horizontal)

            if let session = viewModel.session {
                VStack(spacing: FFSpacing.md) {
                    ForEach(session.participantIds, id: \.self) { userId in
                        perUserRow(userId: userId, session: session)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func perUserRow(userId: String, session: MovieNightSession) -> some View {
        let userName = session.participantNames[userId] ?? "Player"
        let userSwipes = viewModel.allSwipes.filter { $0.userId == userId }
        let yesCount = userSwipes.filter { $0.wantToWatch }.count
        let noCount = userSwipes.filter { !$0.wantToWatch }.count
        let topPicks = Array(viewModel.results
            .filter { $0.swipedRightBy.contains(userId) }
            .sorted { $0.matchScore > $1.matchScore }
            .prefix(4))

        return VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack(spacing: FFSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(FFColors.goldPrimary.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Text(String(userName.prefix(1)).uppercased())
                        .font(FFTypography.labelLarge)
                        .foregroundColor(FFColors.goldPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(userName)
                            .font(FFTypography.labelLarge)
                            .foregroundColor(FFColors.textPrimary)
                        if userId == session.hostId {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(FFColors.goldPrimary)
                        }
                    }
                    HStack(spacing: FFSpacing.xs) {
                        Label("\(yesCount)", systemImage: "hand.thumbsup.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(FFColors.success)
                        Text("·").foregroundColor(FFColors.textTertiary)
                        Label("\(noCount)", systemImage: "hand.thumbsdown.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(FFColors.ruby)
                    }
                }

                Spacer()
            }

            if !topPicks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.sm) {
                        ForEach(topPicks, id: \.id) { result in
                            miniPoster(result: result)
                        }
                    }
                }
            } else {
                Text("Didn't pick any movies")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .italic()
            }
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    private func miniPoster(result: MovieNightResult) -> some View {
        VStack(spacing: 4) {
            if let posterURL = result.movie.posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    FFColors.backgroundElevated
                }
                .frame(width: 56, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text(result.movie.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(FFColors.textSecondary)
                .lineLimit(1)
                .frame(width: 56)
        }
    }

    // MARK: - Ranked List

    private var rankedListSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                HStack(spacing: FFSpacing.sm) {
                    Image(systemName: "list.star")
                        .foregroundColor(FFColors.goldPrimary)
                    Text("All Picks")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.textPrimary)
                }

                Spacer()

                sortMenu
            }
            .padding(.horizontal)

            VStack(spacing: FFSpacing.sm) {
                ForEach(Array(sortedResults.enumerated()), id: \.element.id) { index, result in
                    expandableRow(result: result, rank: index + 1)
                }
            }
            .padding(.horizontal)
        }
    }

    private var sortMenu: some View {
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
                    .font(FFTypography.labelSmall)
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(FFColors.goldPrimary)
            .padding(.horizontal, FFSpacing.sm)
            .padding(.vertical, 4)
            .background(FFColors.goldPrimary.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    // MARK: - Expandable Row (inline)

    private func expandableRow(result: MovieNightResult, rank: Int) -> some View {
        let isExpanded = expandedResultId == result.id

        return VStack(spacing: 0) {
            // Collapsed summary — tappable to expand
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    expandedResultId = isExpanded ? nil : result.id
                }
            } label: {
                HStack(spacing: FFSpacing.sm) {
                    // Rank
                    Text("\(rank)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(rank <= 3 ? FFColors.goldPrimary : FFColors.textTertiary)
                        .frame(width: 24)

                    // Poster
                    if let posterURL = result.movie.posterURL {
                        CachedAsyncImage(url: posterURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { FFColors.backgroundElevated }
                        .frame(width: 44, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.movie.title)
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: FFSpacing.sm) {
                            HStack(spacing: 3) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                Text("\(result.matchPercentage)%")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(matchColor(score: result.matchScore))

                            if let year = result.movie.year {
                                Text(String(year))
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                            }

                            if result.movie.voteAverage > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Text(String(format: "%.1f", result.movie.voteAverage))
                                        .font(FFTypography.caption)
                                }
                                .foregroundColor(FFColors.goldLight)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FFColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(FFSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: FFSpacing.md) {
                    Divider().background(Color.white.opacity(0.1))

                    // Per-user votes
                    if let session = viewModel.session {
                        VStack(alignment: .leading, spacing: FFSpacing.xs) {
                            Text("Votes")
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.textTertiary)

                            VStack(spacing: 6) {
                                ForEach(session.participantIds, id: \.self) { userId in
                                    voteRow(userId: userId, session: session, result: result)
                                }
                            }
                        }
                    }

                    // Overview
                    if !result.movie.overview.isEmpty {
                        VStack(alignment: .leading, spacing: FFSpacing.xs) {
                            Text("Overview")
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.textTertiary)
                            Text(result.movie.overview)
                                .font(FFTypography.bodySmall)
                                .foregroundColor(FFColors.textSecondary)
                                .lineLimit(5)
                        }
                    }

                    // Streaming providers (with overflow cap)
                    if !result.streamingProviders.isEmpty {
                        VStack(alignment: .leading, spacing: FFSpacing.xs) {
                            Text("Available On")
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.textTertiary)
                            streamingRow(providers: result.streamingProviders, size: 32, max: 6)
                        }
                    }
                }
                .padding(.horizontal, FFSpacing.md)
                .padding(.bottom, FFSpacing.md)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(
                            result.isUnanimous ? FFColors.goldPrimary.opacity(0.5) : Color.white.opacity(0.06),
                            lineWidth: result.isUnanimous ? 1 : 0.5
                        )
                }
        }
    }

    private func voteRow(userId: String, session: MovieNightSession, result: MovieNightResult) -> some View {
        let didWatch = result.swipedRightBy.contains(userId)
        let hasSeen = result.seenBy.contains(userId)
        let name = session.participantNames[userId] ?? "Player"

        return HStack(spacing: FFSpacing.sm) {
            Circle()
                .fill(FFColors.goldPrimary.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FFColors.goldPrimary)
                }

            Text(name)
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textPrimary)

            if hasSeen {
                Text("seen")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(FFColors.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(FFColors.backgroundElevated2)
                    .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: didWatch ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .font(.system(size: 10))
                Text(didWatch ? "Yes" : "Pass")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(didWatch ? FFColors.success : FFColors.ruby)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((didWatch ? FFColors.success : FFColors.ruby).opacity(0.12))
            .clipShape(Capsule())
        }
    }

    // MARK: - Streaming Row (with overflow indicator)

    private func streamingRow(providers: [WatchProvider], size: CGFloat, max maxShown: Int) -> some View {
        let visible = Array(providers.prefix(maxShown))
        let hidden = providers.count - visible.count

        return HStack(spacing: FFSpacing.xs) {
            ForEach(visible) { provider in
                if let logoURL = provider.logoURL {
                    CachedAsyncImage(url: logoURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: size * 0.18)
                            .fill(FFColors.backgroundElevated2)
                    }
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
                }
            }

            if hidden > 0 {
                Text("+\(hidden)")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(FFColors.textSecondary)
                    .frame(width: size, height: size)
                    .background(FFColors.backgroundElevated2)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
            }
        }
    }

    private func matchColor(score: Double) -> Color {
        if score >= 1.0 { return FFColors.goldPrimary }
        if score >= 0.5 { return FFColors.goldLight }
        return FFColors.textTertiary
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: FFSpacing.sm) {
            GoldButton(
                title: "Play Again",
                icon: "arrow.clockwise",
                style: .primary,
                size: .large,
                fullWidth: true
            ) {
                Task { await viewModel.playAgain() }
            }
            .padding(.horizontal)
        }
    }
}
