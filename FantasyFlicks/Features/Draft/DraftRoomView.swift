//
//  DraftRoomView.swift
//  FantasyFlicks
//
//  Live draft room experience with pick timer, movie selection, and draft board
//

import SwiftUI

struct DraftRoomView: View {
    let draftId: String
    let leagueName: String

    @StateObject private var viewModel = DraftViewModel()
    @State private var selectedTab: DraftRoomTab = .available
    @State private var searchText = ""
    @State private var showDraftBoard = false
    @State private var showConfirmPick = false
    @State private var showSortOptions = false
    @State private var selectedMovie: FFMovie?
    @Environment(\.dismiss) private var dismiss

    enum DraftRoomTab: String, CaseIterable {
        case available = "Available"
        case myTeam = "My Team"
        case teams = "Teams"
        case history = "History"
    }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            // Loading state
            if viewModel.isLoading && viewModel.currentDraft == nil {
                loadingView
            } else {
                VStack(spacing: 0) {
                    // Top bar with timer
                    draftHeader

                    // Current pick info
                    currentPickBanner

                    // Tab selector
                    tabSelector

                    // Content
                    TabView(selection: $selectedTab) {
                        availableMoviesView
                            .tag(DraftRoomTab.available)

                        myTeamView
                            .tag(DraftRoomTab.myTeam)

                        allTeamsView
                            .tag(DraftRoomTab.teams)

                        historyView
                            .tag(DraftRoomTab.history)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }

                // Floating draft board button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showDraftBoard = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.grid.2x2.fill")
                                Text("Draft Board")
                                    .font(FFTypography.labelMedium)
                            }
                            .foregroundColor(FFColors.backgroundDark)
                            .padding(.horizontal, FFSpacing.lg)
                            .padding(.vertical, FFSpacing.md)
                            .background(FFColors.goldGradientHorizontal)
                            .clipShape(Capsule())
                            .shadow(color: FFColors.goldPrimary.opacity(0.3), radius: 8, y: 4)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadDraft(draftId: draftId)
            await viewModel.loadAvailableMovies(forYear: Calendar.current.component(.year, from: Date()))
        }
        .sheet(isPresented: $showDraftBoard) {
            DraftBoardSheet(draft: viewModel.currentDraft)
        }
        .sheet(isPresented: $showConfirmPick) {
            if let movie = selectedMovie {
                ConfirmPickSheet(
                    movie: movie,
                    isSubmitting: viewModel.isSubmittingPick
                ) {
                    Task {
                        if await viewModel.submitPick(
                            movieId: String(movie.id),
                            movieTitle: movie.title,
                            posterPath: movie.posterPath
                        ) {
                            selectedMovie = nil
                            showConfirmPick = false
                            viewModel.refreshMoviesAfterPick()
                        }
                    }
                }
            }
        }
        .confirmationDialog("Sort By", isPresented: $showSortOptions) {
            ForEach(MovieSortOrder.allCases, id: \.self) { order in
                Button(order.rawValue) {
                    viewModel.sortOrder = order
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: FFSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(FFColors.goldPrimary)

            Text("Loading Draft Room...")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
        }
    }

    // MARK: - Draft Header

    private var draftHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(FFColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(FFColors.backgroundElevated)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(leagueName)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)

                if let draft = viewModel.currentDraft {
                    Text("Round \(draft.currentRound) of \(draft.totalRounds)")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                }
            }

            Spacer()

            // Timer
            TimerView(remainingTime: viewModel.remainingTime)
        }
        .padding()
        .background(FFColors.backgroundElevated)
    }

    // MARK: - Current Pick Banner

    private var currentPickBanner: some View {
        Group {
            if let draft = viewModel.currentDraft {
                let isMyTurn = draft.currentPickerId == AuthenticationService.shared.currentUser?.id

                HStack(spacing: FFSpacing.md) {
                    if isMyTurn {
                        Circle()
                            .fill(FFColors.goldPrimary)
                            .frame(width: 10, height: 10)
                            .modifier(PulsingModifier())

                        Text("Your Pick!")
                            .font(FFTypography.headlineSmall)
                            .foregroundColor(FFColors.goldPrimary)
                    } else {
                        Text("Pick \(draft.currentOverallPick) of \(draft.totalPicks)")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.textSecondary)

                        Text("Waiting for pick...")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textTertiary)
                    }

                    Spacer()

                    // Progress
                    Text("\(Int(draft.progressPercentage * 100))%")
                        .font(FFTypography.statSmall)
                        .foregroundColor(FFColors.goldPrimary)
                }
                .padding()
                .background(isMyTurn ? FFColors.goldPrimary.opacity(0.15) : FFColors.backgroundDark)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                ForEach(DraftRoomTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(FFTypography.labelMedium)
                            .foregroundColor(selectedTab == tab ? FFColors.backgroundDark : FFColors.textSecondary)
                            .padding(.horizontal, FFSpacing.lg)
                            .padding(.vertical, FFSpacing.sm)
                            .background {
                                if selectedTab == tab {
                                    Capsule().fill(FFColors.goldGradientHorizontal)
                                } else {
                                    Capsule().fill(FFColors.backgroundElevated)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, FFSpacing.sm)
        }
    }

    // MARK: - Available Movies View

    private var availableMoviesView: some View {
        VStack(spacing: 0) {
            // Search and sort bar
            HStack(spacing: FFSpacing.sm) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(FFColors.textTertiary)

                    TextField("Search movies...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(FFColors.textPrimary)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
                }
                .padding()
                .background(FFColors.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))

                // Sort button
                Button {
                    showSortOptions = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.sortOrder.icon)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 14))
                    .foregroundColor(FFColors.goldPrimary)
                    .padding()
                    .background(FFColors.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                }
            }
            .padding()

            // Movie count
            HStack {
                Text("\(filteredMovies.count) movies available")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)

                Spacer()

                Text(viewModel.sortOrder.rawValue)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.goldPrimary)
            }
            .padding(.horizontal)
            .padding(.bottom, FFSpacing.sm)

            // Movies list with infinite scroll
            ScrollView {
                LazyVStack(spacing: FFSpacing.md) {
                    ForEach(filteredMovies) { movie in
                        AvailableMovieCard(
                            movie: movie,
                            isPickable: isMyTurn,
                            onSelect: {
                                selectedMovie = movie
                                showConfirmPick = true
                            }
                        )
                        .onAppear {
                            // Load more when reaching near end
                            if movie.id == filteredMovies.last?.id {
                                Task {
                                    await viewModel.loadMoreMovies()
                                }
                            }
                        }
                    }

                    // Loading more indicator
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(FFColors.goldPrimary)
                            Spacer()
                        }
                        .padding()
                    }

                    // Load more button if has more
                    if viewModel.hasMoreMovies && !viewModel.isLoadingMore {
                        Button {
                            Task {
                                await viewModel.loadMoreMovies()
                            }
                        } label: {
                            Text("Load More Movies")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.goldPrimary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(FFColors.backgroundElevated)
                                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // Space for floating button
            }
        }
    }

    private var filteredMovies: [FFMovie] {
        if searchText.isEmpty {
            return viewModel.availableMovies
        }
        return viewModel.availableMovies.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var isMyTurn: Bool {
        viewModel.currentDraft?.currentPickerId == AuthenticationService.shared.currentUser?.id
    }

    // MARK: - My Team View

    private var myTeamView: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                // Team header
                VStack(spacing: FFSpacing.sm) {
                    Text("Your Roster")
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    if let draft = viewModel.currentDraft {
                        let myPicks = draft.picks.filter {
                            $0.userId == AuthenticationService.shared.currentUser?.id
                        }

                        Text("\(myPicks.count) of \(draft.totalRounds) movies drafted")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                }
                .padding(.top)

                // Roster
                if let draft = viewModel.currentDraft {
                    let myPicks = draft.picks.filter {
                        $0.userId == AuthenticationService.shared.currentUser?.id
                    }.sorted { $0.overallPickNumber < $1.overallPickNumber }

                    if myPicks.isEmpty {
                        emptyRosterView
                    } else {
                        LazyVStack(spacing: FFSpacing.md) {
                            ForEach(myPicks) { pick in
                                RosterPickCard(pick: pick)
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
    }

    private var emptyRosterView: some View {
        VStack(spacing: FFSpacing.lg) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(FFColors.goldGradient)

            Text("No movies yet")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)

            Text("When it's your turn, select a movie to add to your roster")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(FFSpacing.xxxl)
    }

    // MARK: - All Teams View

    private var allTeamsView: some View {
        ScrollView {
            if let draft = viewModel.currentDraft {
                LazyVStack(spacing: FFSpacing.lg) {
                    ForEach(draft.draftOrder, id: \.self) { userId in
                        let isCurrentPicker = draft.currentPickerId == userId
                        let isMe = userId == AuthenticationService.shared.currentUser?.id
                        let teamPicks = draft.picks.filter { $0.userId == userId }

                        TeamRosterCard(
                            userId: userId,
                            picks: teamPicks,
                            totalSlots: draft.totalRounds,
                            isCurrentPicker: isCurrentPicker,
                            isMe: isMe
                        )
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - History View

    private var historyView: some View {
        ScrollView {
            if let draft = viewModel.currentDraft {
                LazyVStack(spacing: FFSpacing.sm) {
                    ForEach(draft.picks.reversed()) { pick in
                        HistoryPickCard(pick: pick)
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - Timer View

struct TimerView: View {
    let remainingTime: Int

    private var minutes: Int { remainingTime / 60 }
    private var seconds: Int { remainingTime % 60 }

    private var timerColor: Color {
        if remainingTime <= 30 {
            return FFColors.ruby
        } else if remainingTime <= 60 {
            return FFColors.warning
        }
        return FFColors.goldPrimary
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14))

            Text(String(format: "%d:%02d", minutes, seconds))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
        }
        .foregroundColor(timerColor)
        .padding(.horizontal, FFSpacing.md)
        .padding(.vertical, FFSpacing.sm)
        .background(timerColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Available Movie Card

struct AvailableMovieCard: View {
    let movie: FFMovie
    let isPickable: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            // Poster
            AsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: FFCornerRadius.small)
                    .fill(FFColors.backgroundElevated)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundColor(FFColors.textTertiary)
                    }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.small))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(2)

                if let releaseDate = movie.releaseDate {
                    Text(releaseDate)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                }

                if let overview = movie.overview {
                    Text(overview)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Pick button
            if isPickable {
                Button(action: onSelect) {
                    Text("Pick")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.backgroundDark)
                        .padding(.horizontal, FFSpacing.lg)
                        .padding(.vertical, FFSpacing.sm)
                        .background(FFColors.goldGradientHorizontal)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
    }
}

// MARK: - Roster Pick Card

struct RosterPickCard: View {
    let pick: FFDraftPick

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            // Pick number
            Text("#\(pick.overallPickNumber)")
                .font(FFTypography.statSmall)
                .foregroundStyle(FFColors.goldGradient)
                .frame(width: 44)

            // Poster
            AsyncImage(url: pick.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: FFCornerRadius.small)
                    .fill(FFColors.backgroundDark)
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.small))

            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text(pick.movieTitle)
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)

                Text(pick.pickLabel)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }

            Spacer()
        }
        .padding(FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
    }
}

// MARK: - Team Roster Card

struct TeamRosterCard: View {
    let userId: String
    let picks: [FFDraftPick]
    let totalSlots: Int
    let isCurrentPicker: Bool
    let isMe: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: FFSpacing.sm) {
                        Text(isMe ? "Your Team" : "Team \(userId.prefix(6))...")
                            .font(FFTypography.headlineSmall)
                            .foregroundColor(FFColors.textPrimary)

                        if isMe {
                            Text("YOU")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FFColors.backgroundDark)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FFColors.goldPrimary)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(picks.count)/\(totalSlots) movies")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                }

                Spacer()

                if isCurrentPicker {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(FFColors.goldPrimary)
                            .frame(width: 8, height: 8)
                        Text("Picking")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.goldPrimary)
                    }
                    .padding(.horizontal, FFSpacing.sm)
                    .padding(.vertical, 4)
                    .background(FFColors.goldPrimary.opacity(0.2))
                    .clipShape(Capsule())
                }
            }

            // Movies
            if picks.isEmpty {
                Text("No picks yet")
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textTertiary)
                    .padding(.vertical, FFSpacing.sm)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.sm) {
                        ForEach(picks.sorted { $0.overallPickNumber < $1.overallPickNumber }) { pick in
                            VStack(spacing: 4) {
                                AsyncImage(url: pick.posterURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: FFCornerRadius.small)
                                        .fill(FFColors.backgroundDark)
                                }
                                .frame(width: 50, height: 75)
                                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.small))

                                Text("#\(pick.overallPickNumber)")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
        .overlay {
            if isCurrentPicker {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .stroke(FFColors.goldPrimary.opacity(0.5), lineWidth: 2)
            }
        }
    }
}

// MARK: - History Pick Card

struct HistoryPickCard: View {
    let pick: FFDraftPick

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            // Pick number
            Text("#\(pick.overallPickNumber)")
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.goldPrimary)
                .frame(width: 36)

            // Poster
            AsyncImage(url: pick.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(FFColors.backgroundDark)
            }
            .frame(width: 32, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(pick.movieTitle)
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                Text("by Team \(pick.userId.prefix(6))...")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }

            Spacer()

            // Time taken
            if let seconds = pick.secondsTaken {
                Text("\(seconds)s")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }

            if pick.wasAutoPick {
                Text("AUTO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(FFColors.ruby)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FFColors.ruby.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, FFSpacing.sm)
        .padding(.horizontal, FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.small))
    }
}

// MARK: - Draft Board Sheet

struct DraftBoardSheet: View {
    let draft: FFDraft?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if let draft = draft {
                    ScrollView([.horizontal, .vertical]) {
                        DraftBoardGrid(draft: draft)
                            .padding()
                    }
                } else {
                    ProgressView()
                        .tint(FFColors.goldPrimary)
                }
            }
            .navigationTitle("Draft Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }
}

// MARK: - Draft Board Grid

struct DraftBoardGrid: View {
    let draft: FFDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row with team names
            HStack(spacing: 2) {
                Text("Round")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .frame(width: 50)

                ForEach(Array(draft.draftOrder.enumerated()), id: \.offset) { index, userId in
                    Text("T\(index + 1)")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.textPrimary)
                        .frame(width: 80)
                }
            }

            // Rows for each round
            ForEach(1...draft.totalRounds, id: \.self) { round in
                HStack(spacing: 2) {
                    Text("\(round)")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.goldPrimary)
                        .frame(width: 50)

                    ForEach(Array(draft.draftOrder.enumerated()), id: \.offset) { position, userId in
                        let actualPosition = draft.draftType == .serpentine && round % 2 == 0
                            ? draft.draftOrder.count - position - 1
                            : position
                        let actualUserId = draft.draftOrder[actualPosition]

                        // Find the pick for this cell
                        let pick = draft.picks.first { pick in
                            pick.roundNumber == round && pick.userId == actualUserId
                        }

                        DraftBoardCell(pick: pick, round: round, position: position + 1)
                    }
                }
            }
        }
    }
}

struct DraftBoardCell: View {
    let pick: FFDraftPick?
    let round: Int
    let position: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(pick != nil ? FFColors.backgroundElevated : FFColors.backgroundDark)

            if let pick = pick {
                VStack(spacing: 2) {
                    AsyncImage(url: pick.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 40, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                    Text(pick.movieTitle)
                        .font(.system(size: 8))
                        .foregroundColor(FFColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(4)
            } else {
                Text("-")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }
        }
        .frame(width: 80, height: 90)
    }
}

// MARK: - Confirm Pick Sheet

struct ConfirmPickSheet: View {
    let movie: FFMovie
    let isSubmitting: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: FFSpacing.xl) {
                    // Movie poster
                    AsyncImage(url: movie.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .fill(FFColors.backgroundElevated)
                            .overlay {
                                ProgressView()
                                    .tint(FFColors.goldPrimary)
                            }
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                    // Movie info
                    VStack(spacing: FFSpacing.sm) {
                        Text(movie.title)
                            .font(FFTypography.displaySmall)
                            .foregroundColor(FFColors.textPrimary)
                            .multilineTextAlignment(.center)

                        if let releaseDate = movie.releaseDate {
                            Text(releaseDate)
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textSecondary)
                        }
                    }

                    Spacer()

                    // Confirm button
                    VStack(spacing: FFSpacing.md) {
                        GoldButton(
                            title: "Confirm Pick",
                            icon: "checkmark.circle.fill",
                            fullWidth: true,
                            isLoading: isSubmitting,
                            action: onConfirm
                        )
                        .disabled(isSubmitting)

                        Button("Cancel") {
                            dismiss()
                        }
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)
                    }
                    .padding(.bottom, FFSpacing.xl)
                }
                .padding()
            }
            .navigationTitle("Confirm Your Pick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(FFColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Pulsing Modifier

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Preview

#Preview {
    DraftRoomView(draftId: "draft_001", leagueName: "Box Office Champions")
}
