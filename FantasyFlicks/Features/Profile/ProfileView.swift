//
//  ProfileView.swift
//  FantasyFlicks
//
//  Profile tab - user profile and settings
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var seenMoviesService = SeenMoviesService.shared
    @StateObject private var friendsService = FriendsService.shared
    @StateObject private var letterboxd = LetterboxdService.shared
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showWatchedMovies = false
    @State private var showDiary = false
    @State private var showWatchlist = false
    @State private var showRatings = false
    @State private var showLetterboxdConnect = false
    @State private var selectedAchievement: AchievementProgress?
    @State private var showFavoritesEditor = false
    @State private var favoriteDetail: FFMovie?

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if let user = viewModel.user {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: FFSpacing.xl) {
                            profileHeader(user: user)
                            FavoritesRow(
                                tmdbIds: user.favoriteMovieIds,
                                isEditable: true,
                                onTapMovie: { favoriteDetail = $0 },
                                onEdit: { showFavoritesEditor = true }
                            )
                            watchedMoviesSection
                            friendsSection(user: user)
                            letterboxdImportSection
                            achievementsSection
                            recentActivitySection
                            Spacer(minLength: 100)
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshProfile()
                        await friendsService.refreshFriendList()
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
            .task {
                await friendsService.refreshFriendList()
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
            .sheet(isPresented: $showFavoritesEditor) {
                FavoritesEditorSheet(
                    viewModel: viewModel,
                    initialIds: viewModel.user?.favoriteMovieIds ?? []
                )
            }
            .sheet(item: $favoriteDetail) { movie in
                NavigationStack {
                    MovieDetailView(movie: movie)
                }
            }
            .sheet(isPresented: $showLetterboxdConnect) {
                LetterboxdConnectSheet()
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
                AvatarView(user: user, size: 80)

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
            Text("Achievements")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FFSpacing.md) {
                    ForEach(AchievementService.shared.allProgress()) { progress in
                        Button {
                            selectedAchievement = progress
                        } label: {
                            AchievementBadge(
                                icon: progress.definition.icon,
                                name: progress.definition.name,
                                isUnlocked: progress.isUnlocked
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(item: $selectedAchievement) { progress in
            AchievementDetailSheet(progress: progress)
        }
    }

    // MARK: - Friends Section

    private func friendsSection(user: FFUser) -> some View {
        let count = max(user.friendIds.count, friendsService.friends.count)

        return Button {
            NavigationCoordinator.shared.navigateTo(.friends)
        } label: {
            HStack(spacing: FFSpacing.md) {
                ZStack {
                    Circle()
                        .fill(FFColors.goldPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(FFColors.goldPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Friends")
                        .font(FFTypography.titleSmall)
                        .foregroundColor(FFColors.textPrimary)
                    Text(count == 0 ? "Find and add other users" : "\(count) \(count == 1 ? "friend" : "friends")")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FFColors.textTertiary)
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Letterboxd Section

    private var letterboxdImportSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Connected Accounts")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            Button {
                showLetterboxdConnect = true
            } label: {
                GlassCard(goldTint: letterboxd.isConnected) {
                    HStack(spacing: FFSpacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                .fill((letterboxd.isConnected ? FFColors.success : FFColors.goldPrimary).opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: letterboxd.isConnected ? "checkmark.circle.fill" : "link")
                                .font(.system(size: 20))
                                .foregroundColor(letterboxd.isConnected ? FFColors.success : FFColors.goldPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Letterboxd")
                                .font(FFTypography.titleSmall)
                                .foregroundColor(FFColors.textPrimary)

                            Text(letterboxdSubtitle)
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if letterboxd.isSyncing {
                            InlineLoader(size: 16)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(FFColors.goldPrimary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    private var letterboxdSubtitle: String {
        guard let username = letterboxd.username else {
            return "Sync your watches, ratings and reviews"
        }
        guard let date = letterboxd.lastSyncedAt else { return "@\(username) · not synced yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "@\(username) · synced \(formatter.localizedString(for: date, relativeTo: Date()))"
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
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var avatarBase64: String?

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
                            // Selected avatar preview — uses uploaded photo if present
                            ZStack {
                                Circle()
                                    .fill(FFColors.goldPrimary.opacity(0.2))
                                    .frame(width: 110, height: 110)
                                    .blur(radius: 20)

                                AvatarView(
                                    size: 90,
                                    displayName: displayName.isEmpty ? user.displayName : displayName,
                                    avatarBase64: avatarBase64,
                                    avatarIcon: avatarBase64 == nil ? selectedAvatarIcon : nil
                                )
                                .overlay(
                                    Circle()
                                        .stroke(FFColors.goldPrimary.opacity(0.5), lineWidth: 2)
                                )
                            }
                            .padding(.top, FFSpacing.lg)

                            // Upload photo button
                            PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                    Text(avatarBase64 == nil ? "Upload Photo" : "Change Photo")
                                        .font(FFTypography.labelSmall)
                                }
                                .foregroundColor(FFColors.goldPrimary)
                                .padding(.horizontal, FFSpacing.md)
                                .padding(.vertical, 8)
                                .background(FFColors.goldPrimary.opacity(0.15))
                                .clipShape(Capsule())
                            }

                            if avatarBase64 != nil {
                                Button("Remove photo") {
                                    avatarBase64 = nil
                                }
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                            }

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
                                    bio: bio,
                                    avatarBase64: avatarBase64
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
                avatarBase64 = user.avatarBase64
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let encoded = encodeAvatar(from: data) {
                        avatarBase64 = encoded
                    }
                }
            }
        }
    }

    /// Scale the picked image to 256x256 and JPEG-encode it so the resulting
    /// blob stays small (~10-15KB).
    private func encodeAvatar(from data: Data) -> String? {
        guard let original = UIImage(data: data) else { return nil }
        let target = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            // Center-crop to square then draw filling the target rect.
            let shortest = min(original.size.width, original.size.height)
            let cropRect = CGRect(
                x: (original.size.width - shortest) / 2,
                y: (original.size.height - shortest) / 2,
                width: shortest,
                height: shortest
            )
            if let cgImage = original.cgImage?.cropping(to: cropRect) {
                UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation)
                    .draw(in: CGRect(origin: .zero, size: target))
            } else {
                original.draw(in: CGRect(origin: .zero, size: target))
            }
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.72) else { return nil }
        return jpeg.base64EncodedString()
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


// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showDeleteConfirmation = false
    @State private var showEditProfile = false
    @State private var showNotifications = false
    @State private var showPrivacy = false
    @State private var showDeveloperTools = false

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                List {
                    Section("Account") {
                        SettingsListRow(icon: "person.fill", title: "Edit Profile") {
                            showEditProfile = true
                        }

                        if let email = viewModel.user?.email, !email.isEmpty {
                            HStack {
                                HStack(spacing: FFSpacing.md) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(FFColors.goldPrimary)
                                    Text("Email")
                                        .foregroundColor(FFColors.textPrimary)
                                }
                                Spacer()
                                Text(email)
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listRowBackground(FFColors.backgroundElevated.opacity(0.5))

                    Section("Preferences") {
                        SettingsListRow(icon: "bell.fill", title: "Notifications") {
                            showNotifications = true
                        }
                        SettingsListRow(icon: "lock.fill", title: "Privacy") {
                            showPrivacy = true
                        }
                    }
                    .listRowBackground(FFColors.backgroundElevated.opacity(0.5))

                    Section {
                        Button {
                            viewModel.signOut()
                            dismiss()
                        } label: {
                            HStack(spacing: FFSpacing.md) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                Spacer()
                            }
                            .foregroundColor(FFColors.ruby)
                        }
                    }
                    .listRowBackground(FFColors.backgroundElevated.opacity(0.5))

                    Section {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: FFSpacing.md) {
                                Image(systemName: "trash")
                                Text("Delete Account")
                                Spacer()
                            }
                            .foregroundColor(FFColors.ruby)
                        }
                    }
                    .listRowBackground(FFColors.backgroundElevated.opacity(0.5))

                    // Developer tools — only visible to whitelisted accounts
                    // OR after the hidden long-press on the version footer.
                    if DeveloperToolsGate.isAvailable {
                        Section("Developer") {
                            SettingsListRow(icon: "hammer.fill", title: "Developer Tools") {
                                showDeveloperTools = true
                            }
                        }
                        .listRowBackground(FFColors.backgroundElevated.opacity(0.5))
                    }

                    Section {
                        Text("FantasyFlicks · v1.0")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FFSpacing.md)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 1.5) {
                                // Secret handshake to surface developer tools
                                // for any account, useful when the email gate
                                // doesn't match the signed-in identity.
                                DeveloperToolsGate.manuallyUnlocked = true
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                showDeveloperTools = true
                            }
                    }
                    .listRowBackground(Color.clear)
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
            .sheet(isPresented: $showEditProfile) {
                if let user = viewModel.user {
                    EditProfileSheet(viewModel: viewModel, user: user)
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationSettingsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacySettingsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showDeveloperTools) {
                DeveloperToolsSheet()
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FFSpacing.md) {
                Image(systemName: icon)
                    .foregroundColor(FFColors.goldPrimary)
                    .frame(width: 22)
                Text(title)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(FFColors.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .ffTheme()
}
