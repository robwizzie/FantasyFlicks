//
//  ProfileView.swift
//  FantasyFlicks
//
//  Profile tab - user profile and settings
//

import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var seenMoviesService = SeenMoviesService.shared
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showWatchedMovies = false
    @State private var showDiary = false
    @State private var showWatchlist = false
    @State private var showRatings = false

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if let user = viewModel.user {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: FFSpacing.xl) {
                            // Profile header
                            profileHeader(user: user)

                            // Stats
                            statsSection(user: user)

                            // Watched Movies
                            watchedMoviesSection

                            // Achievements
                            achievementsSection

                            // Recent activity
                            recentActivitySection

                            // Settings links
                            settingsSection

                            Spacer(minLength: 100)
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshProfile()
                    }
                } else {
                    // Loading state
                    VStack(spacing: FFSpacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(FFColors.goldPrimary)
                        Text("Loading profile...")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showEditProfile) {
                if let user = viewModel.user {
                    EditProfileSheet(viewModel: viewModel, user: user)
                }
            }
            .sheet(isPresented: $showWatchedMovies) {
                WatchedMoviesSheet()
            }
            .sheet(isPresented: $showDiary) {
                DiaryView()
            }
            .sheet(isPresented: $showWatchlist) {
                WatchlistView()
            }
            .sheet(isPresented: $showRatings) {
                RatingsView()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.clearMessages() }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private func profileHeader(user: FFUser) -> some View {
        GlassCard(goldTint: true) {
            HStack(spacing: FFSpacing.lg) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(FFColors.goldGradient)
                        .frame(width: 80, height: 80)

                    if let avatarIcon = user.avatarIcon {
                        Image(systemName: avatarIcon)
                            .font(.system(size: 36))
                            .foregroundColor(FFColors.backgroundDark)
                    } else {
                        Text(user.displayName.prefix(1).uppercased())
                            .font(FFTypography.displayMedium)
                            .foregroundColor(FFColors.backgroundDark)
                    }
                }

                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text(user.displayName)
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text("@\(user.username)")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)

                    if let genre = user.favoriteGenre {
                        HStack(spacing: FFSpacing.xs) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(FFColors.ruby)

                            Text(genre)
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }

                    HStack(spacing: FFSpacing.sm) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(FFColors.goldPrimary)

                        Text("\(user.rankingPoints) points")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }

                Spacer()

                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FFColors.goldPrimary)
                        .frame(width: 36, height: 36)
                        .background(FFColors.goldPrimary.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
    }

    private func statsSection(user: FFUser) -> some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Stats")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            HStack(spacing: FFSpacing.md) {
                StatCard(value: "\(user.totalLeagues)", label: "Leagues", icon: "trophy.fill")
                StatCard(value: "\(user.leaguesWon)", label: "Wins", icon: "crown.fill")
                StatCard(value: user.winRatePercentage, label: "Win Rate", icon: "chart.line.uptrend.xyaxis")
                StatCard(value: "\(user.totalMoviesDrafted)", label: "Drafted", icon: "film.fill")
            }
            .padding(.horizontal)
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Achievements")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                Button {
                    // View all achievements
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(FFTypography.labelSmall)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FFSpacing.md) {
                    ForEach(viewModel.achievements) { achievement in
                        AchievementBadge(
                            icon: achievement.icon,
                            name: achievement.name,
                            isUnlocked: achievement.isUnlocked
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Recent Activity")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            if viewModel.recentActivity.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: FFSpacing.sm) {
                        Image(systemName: "clock")
                            .font(.system(size: 32))
                            .foregroundColor(FFColors.textTertiary)
                        Text("No recent activity")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textSecondary)
                    }
                    .padding(.vertical, FFSpacing.xl)
                    Spacer()
                }
            } else {
                VStack(spacing: FFSpacing.sm) {
                    ForEach(viewModel.recentActivity) { activity in
                        ActivityRow(
                            icon: activity.icon,
                            text: activity.text,
                            time: activity.timeAgo
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var watchedMoviesSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("My Movies")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FFSpacing.md) {
                profileHubCard(icon: "book.closed.fill", title: "Diary", count: seenMoviesService.diary.count, color: FFColors.goldPrimary) {
                    showDiary = true
                }
                profileHubCard(icon: "eye.fill", title: "Watched", count: seenMoviesService.count, color: FFColors.success) {
                    showWatchedMovies = true
                }
                profileHubCard(icon: "bookmark.fill", title: "Watchlist", count: seenMoviesService.watchlist.count, color: FFColors.ruby) {
                    showWatchlist = true
                }
                profileHubCard(icon: "star.fill", title: "Ratings", count: seenMoviesService.ratings.count, color: FFColors.goldLight) {
                    showRatings = true
                }
            }
            .padding(.horizontal)
        }
    }

    private func profileHubCard(icon: String, title: String, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: FFSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text("\(count)")
                    .font(FFTypography.titleMedium)
                    .foregroundColor(FFColors.textPrimary)

                Text(title)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FFSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var settingsSection: some View {
        VStack(spacing: FFSpacing.sm) {
            SettingsRow(icon: "bell.fill", title: "Notifications")
            SettingsRow(icon: "person.2.fill", title: "Friends")
            SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support")
            SettingsRow(icon: "info.circle.fill", title: "About")
        }
        .padding(.horizontal)
    }
}

// MARK: - Watched Movies Sheet

struct WatchedMoviesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenMoviesService = SeenMoviesService.shared
    @State private var showLetterboxdImporter = false
    @State private var searchText = ""
    @State private var searchResults: [FFMovie] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.xl) {
                        // Stats
                        GlassCard(goldTint: true) {
                            HStack(spacing: FFSpacing.md) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(FFColors.goldPrimary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(seenMoviesService.count)")
                                        .font(FFTypography.statMedium)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("movies marked as watched")
                                        .font(FFTypography.bodySmall)
                                        .foregroundColor(FFColors.textSecondary)
                                }

                                Spacer()
                            }
                        }
                        .padding(.horizontal)

                        // Letterboxd import
                        GlassCard {
                            VStack(spacing: FFSpacing.lg) {
                                HStack(spacing: FFSpacing.md) {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(FFColors.goldPrimary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Import from Letterboxd")
                                            .font(FFTypography.titleSmall)
                                            .foregroundColor(FFColors.textPrimary)
                                        Text("Upload your watched.csv or diary.csv")
                                            .font(FFTypography.caption)
                                            .foregroundColor(FFColors.textTertiary)
                                    }
                                    Spacer()
                                }

                                GoldButton(
                                    title: seenMoviesService.isImporting ? "Importing..." : "Choose CSV File",
                                    icon: "doc.fill",
                                    style: .secondary,
                                    size: .medium,
                                    isLoading: seenMoviesService.isImporting,
                                    fullWidth: true
                                ) {
                                    showLetterboxdImporter = true
                                }
                                .disabled(seenMoviesService.isImporting)

                                if let count = seenMoviesService.lastImportCount {
                                    HStack(spacing: FFSpacing.sm) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(FFColors.success)
                                        Text("Imported \(count) movies")
                                            .font(FFTypography.labelMedium)
                                            .foregroundColor(FFColors.success)
                                    }
                                }

                                VStack(alignment: .leading, spacing: FFSpacing.xs) {
                                    Text("How to export from Letterboxd:")
                                        .font(FFTypography.labelSmall)
                                        .foregroundColor(FFColors.textSecondary)
                                    Text("1. Go to letterboxd.com/settings/data")
                                    Text("2. Click \"Export Your Data\"")
                                    Text("3. Upload the watched.csv file")
                                }
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal)

                        // Search to add movies
                        VStack(alignment: .leading, spacing: FFSpacing.md) {
                            Text("Search & Add Movies")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)
                                .padding(.horizontal)

                            HStack(spacing: FFSpacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(FFColors.textTertiary)

                                TextField("Search for a movie...", text: $searchText)
                                    .font(FFTypography.bodyMedium)
                                    .foregroundColor(FFColors.textPrimary)
                                    .textInputAutocapitalization(.words)
                                    .onSubmit { Task { await search() } }

                                if isSearching {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(FFColors.goldPrimary)
                                }
                            }
                            .padding(FFSpacing.md)
                            .background(FFColors.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                            .padding(.horizontal)

                            if !searchResults.isEmpty {
                                VStack(spacing: FFSpacing.xs) {
                                    ForEach(searchResults) { movie in
                                        searchResultRow(movie: movie)
                                    }
                                }
                            }
                        }

                        // Clear all
                        if seenMoviesService.count > 0 {
                            Button {
                                seenMoviesService.seenTmdbIds.removeAll()
                                UserDefaults.standard.removeObject(forKey: "ff_seen_movie_tmdb_ids")
                            } label: {
                                Text("Clear All Watched Movies")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.ruby)
                            }
                            .padding(.top, FFSpacing.lg)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, FFSpacing.md)
                }
            }
            .navigationTitle("Watched Movies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .fileImporter(
                isPresented: $showLetterboxdImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { _ = await seenMoviesService.importLetterboxd(from: url) }
                case .failure:
                    break
                }
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.count >= 2 {
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard searchText == newValue else { return }
                        await search()
                    }
                } else {
                    searchResults = []
                }
            }
        }
    }

    private func searchResultRow(movie: FFMovie) -> some View {
        let isSeen = seenMoviesService.isSeen(tmdbId: movie.tmdbId)

        return HStack(spacing: FFSpacing.md) {
            if let posterURL = movie.posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    FFColors.backgroundElevated
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: FFSpacing.sm) {
                    if let year = movie.year {
                        Text(String(year))
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                    if movie.voteAverage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(FFColors.goldPrimary)
                            Text(String(format: "%.1f", movie.voteAverage))
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    seenMoviesService.toggleSeen(tmdbId: movie.tmdbId)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSeen ? "eye.fill" : "eye")
                            .font(.system(size: 12))
                        Text(isSeen ? "Watched" : "Mark Seen")
                            .font(FFTypography.labelSmall)
                    }
                    .foregroundColor(isSeen ? FFColors.goldPrimary : FFColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isSeen ? FFColors.goldPrimary.opacity(0.15) : FFColors.backgroundElevated)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(isSeen ? FFColors.goldPrimary.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                    }
                }

                if isSeen {
                    StarRatingView(tmdbId: movie.tmdbId, compact: true)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.xs)
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        do {
            let response = try await TMDBService.shared.searchMovies(query: searchText)
            searchResults = response.results.prefix(10).map { TMDBService.shared.convertToFFMovie($0) }
        } catch {
            searchResults = []
        }
        isSearching = false
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    let user: FFUser

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var selectedAvatarIcon: String?
    @State private var selectedGenre: String?
    @State private var bio: String = ""

    private let avatarOptions = [
        "film.fill", "star.fill", "popcorn.fill", "ticket.fill",
        "tv.fill", "camera.fill", "sparkles", "popcorn.fill"
    ]

    private let genreOptions = [
        "Action", "Comedy", "Drama", "Horror", "Sci-Fi",
        "Romance", "Thriller", "Animation", "Documentary", "Fantasy"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: FFSpacing.xl) {
                        // Avatar Section
                        VStack(spacing: FFSpacing.md) {
                            // Selected avatar preview
                            ZStack {
                                Circle()
                                    .fill(FFColors.goldPrimary.opacity(0.2))
                                    .frame(width: 110, height: 110)
                                    .blur(radius: 20)

                                Circle()
                                    .fill(FFColors.backgroundElevated)
                                    .frame(width: 90, height: 90)
                                    .overlay(
                                        Circle()
                                            .stroke(FFColors.goldPrimary.opacity(0.5), lineWidth: 2)
                                    )

                                if let icon = selectedAvatarIcon {
                                    Image(systemName: icon)
                                        .font(.system(size: 40))
                                        .foregroundStyle(FFColors.goldGradient)
                                } else {
                                    Text(displayName.prefix(1).uppercased())
                                        .font(FFTypography.displayMedium)
                                        .foregroundStyle(FFColors.goldGradient)
                                }
                            }
                            .padding(.top, FFSpacing.lg)

                            // Avatar grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: FFSpacing.md) {
                                ForEach(avatarOptions, id: \.self) { icon in
                                    Button {
                                        selectedAvatarIcon = icon
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(selectedAvatarIcon == icon ? FFColors.goldPrimary.opacity(0.2) : FFColors.backgroundElevated)
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedAvatarIcon == icon ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.3), lineWidth: 1)
                                                )

                                            Image(systemName: icon)
                                                .font(.system(size: 22))
                                                .foregroundColor(selectedAvatarIcon == icon ? FFColors.goldPrimary : FFColors.textSecondary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Form fields
                        VStack(spacing: FFSpacing.lg) {
                            // Display Name
                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                Text("Display Name")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textSecondary)

                                TextField("Your display name", text: $displayName)
                                    .textFieldStyle(.plain)
                                    .font(FFTypography.bodyLarge)
                                    .foregroundColor(FFColors.textPrimary)
                                    .padding()
                                    .background {
                                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                            .fill(FFColors.backgroundElevated)
                                    }
                            }

                            // Username
                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                Text("Username")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textSecondary)

                                HStack {
                                    Text("@")
                                        .font(FFTypography.bodyLarge)
                                        .foregroundColor(FFColors.goldPrimary)

                                    TextField("Your username", text: $username)
                                        .textFieldStyle(.plain)
                                        .font(FFTypography.bodyLarge)
                                        .foregroundColor(FFColors.textPrimary)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                        .fill(FFColors.backgroundElevated)
                                }
                            }

                            // Favorite Genre
                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                Text("Favorite Genre")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: FFSpacing.sm) {
                                        ForEach(genreOptions, id: \.self) { genre in
                                            Button {
                                                if selectedGenre == genre {
                                                    selectedGenre = nil
                                                } else {
                                                    selectedGenre = genre
                                                }
                                            } label: {
                                                Text(genre)
                                                    .font(FFTypography.labelMedium)
                                                    .foregroundColor(selectedGenre == genre ? FFColors.backgroundDark : FFColors.textPrimary)
                                                    .padding(.horizontal, FFSpacing.md)
                                                    .padding(.vertical, FFSpacing.sm)
                                                    .background(selectedGenre == genre ? FFColors.goldPrimary : FFColors.backgroundElevated)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }

                            // Bio
                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                HStack {
                                    Text("Bio")
                                        .font(FFTypography.labelMedium)
                                        .foregroundColor(FFColors.textSecondary)

                                    Spacer()

                                    Text("\(bio.count)/150")
                                        .font(FFTypography.caption)
                                        .foregroundColor(bio.count > 150 ? FFColors.error : FFColors.textTertiary)
                                }

                                TextEditor(text: $bio)
                                    .font(FFTypography.bodyMedium)
                                    .foregroundColor(FFColors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 80)
                                    .padding(FFSpacing.sm)
                                    .background {
                                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                            .fill(FFColors.backgroundElevated)
                                    }
                                    .onChange(of: bio) { _, newValue in
                                        if newValue.count > 150 {
                                            bio = String(newValue.prefix(150))
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)

                        // Save button
                        GoldButton(title: "Save Changes", fullWidth: true) {
                            Task {
                                if await viewModel.updateProfile(
                                    displayName: displayName,
                                    username: username,
                                    avatarIcon: selectedAvatarIcon,
                                    favoriteGenre: selectedGenre,
                                    bio: bio
                                ) {
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal)
                        .disabled(viewModel.isSaving || displayName.isEmpty || username.isEmpty)
                        .opacity((viewModel.isSaving || displayName.isEmpty || username.isEmpty) ? 0.5 : 1)

                        if viewModel.isSaving {
                            ProgressView()
                                .tint(FFColors.goldPrimary)
                        }

                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
            }
            .onAppear {
                displayName = user.displayName
                username = user.username
                selectedAvatarIcon = user.avatarIcon
                selectedGenre = user.favoriteGenre
                bio = user.bio ?? ""
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(FFColors.goldGradient)

            Text(value)
                .font(FFTypography.titleMedium)
                .foregroundColor(FFColors.textPrimary)

            Text(label)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FFSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let icon: String
    let name: String
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? FFColors.goldGradient : LinearGradient(colors: [FFColors.backgroundElevated, FFColors.backgroundElevated], startPoint: .top, endPoint: .bottom))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUnlocked ? FFColors.backgroundDark : FFColors.textTertiary)
            }
            .opacity(isUnlocked ? 1 : 0.5)

            Text(name)
                .font(FFTypography.caption)
                .foregroundColor(isUnlocked ? FFColors.textPrimary : FFColors.textTertiary)
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let icon: String
    let text: String
    let time: String

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(FFColors.goldPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textPrimary)

                Text(time)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }

            Spacer()
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.4))
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        Button {
            // Navigate
        } label: {
            HStack(spacing: FFSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(FFColors.goldPrimary)
                    .frame(width: 24)

                Text(title)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FFColors.textTertiary)
            }
            .padding(FFSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(FFColors.backgroundElevated.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                List {
                    Section("Account") {
                        SettingsListRow(icon: "person.fill", title: "Edit Profile")
                        if let email = viewModel.user?.email, !email.isEmpty {
                            HStack {
                                SettingsListRow(icon: "envelope.fill", title: "Email")
                                Spacer()
                                Text(email)
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textSecondary)
                            }
                        }
                    }

                    Section("Preferences") {
                        SettingsListRow(icon: "bell.fill", title: "Notifications")
                        SettingsListRow(icon: "paintbrush.fill", title: "Appearance")
                    }

                    Section("Support") {
                        SettingsListRow(icon: "questionmark.circle.fill", title: "Help Center")
                        SettingsListRow(icon: "envelope.fill", title: "Contact Us")
                        SettingsListRow(icon: "star.fill", title: "Rate the App")
                    }

                    Section {
                        Button {
                            viewModel.signOut()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(FFColors.ruby)
                        }
                    }

                    Section {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                            }
                            .foregroundColor(FFColors.ruby)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.deleteAccount() {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
}

struct SettingsListRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(FFColors.goldPrimary)
            Text(title)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .ffTheme()
}
