//
//  FriendsView.swift
//  FantasyFlicks
//
//  Friend list + user search. Presented as a sheet from Profile.
//

import SwiftUI

struct FriendsView: View {
    var isEmbeddedInTab: Bool = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsService = FriendsService.shared
    @State private var searchText = ""
    @State private var searchResults: [FFUser] = []
    @State private var isSearching = false

    private var showingSearch: Bool {
        searchText.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.lg) {
                        searchBar

                        if showingSearch {
                            searchResultsSection
                        } else {
                            friendListSection
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.top, FFSpacing.md)
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(isEmbeddedInTab ? .large : .inline)
            .toolbar {
                if !isEmbeddedInTab {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
            .task {
                await friendsService.refreshFriendList()
            }
            .onChange(of: searchText) { _, newValue in
                runSearch(for: newValue)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(FFColors.textTertiary)

            TextField("Search by username", text: $searchText)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(FFColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                InlineLoader(size: 16)
            }
        }
        .padding(FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .padding(.horizontal)
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Results")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textTertiary)

                Spacer()

                if !searchResults.isEmpty {
                    Text("\(searchResults.count) found")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
            }
            .padding(.horizontal)

            if searchResults.isEmpty && !isSearching {
                emptyState(icon: "magnifyingglass", title: "No users found", subtitle: "Try a different username")
            } else {
                VStack(spacing: FFSpacing.sm) {
                    ForEach(searchResults) { user in
                        NavigationLink {
                            UserProfileView(user: user)
                        } label: {
                            UserRow(
                                user: user,
                                style: friendsService.isFriend(user.id) ? .alreadyFriend : .addable,
                                onAdd: { addFriend(user) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Friend List

    private var friendListSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Your Friends")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if !friendsService.friends.isEmpty {
                    Text("\(friendsService.friends.count)")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.goldPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(FFColors.goldPrimary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            if friendsService.friends.isEmpty {
                emptyState(
                    icon: "person.2",
                    title: "No friends yet",
                    subtitle: "Search for people by username to add them"
                )
            } else {
                VStack(spacing: FFSpacing.sm) {
                    ForEach(friendsService.friends) { friend in
                        NavigationLink {
                            UserProfileView(user: friend)
                        } label: {
                            UserRow(user: friend, style: .navigate)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(FFColors.textTertiary)

            Text(title)
                .font(FFTypography.titleSmall)
                .foregroundColor(FFColors.textSecondary)

            Text(subtitle)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FFSpacing.xxl)
        .padding(.horizontal, FFSpacing.xl)
    }

    // MARK: - Search debounce

    private func runSearch(for raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            // Ensure this is still the current query
            guard searchText == raw else { return }
            do {
                let results = try await friendsService.searchUsers(query: trimmed)
                guard searchText == raw else { return }
                searchResults = results
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    private func addFriend(_ user: FFUser) {
        Task {
            try? await friendsService.addFriend(user)
        }
    }
}
