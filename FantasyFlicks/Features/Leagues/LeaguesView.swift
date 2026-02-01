//
//  LeaguesView.swift
//  FantasyFlicks
//
//  Leagues tab - list of user's leagues
//

import SwiftUI

struct LeaguesView: View {
    @StateObject private var viewModel = LeaguesViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: LeagueFilter = .all
    @State private var showCreateLeague = false
    @State private var showJoinLeague = false

    enum LeagueFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case drafting = "Drafting"
        case completed = "Completed"
    }

    var filteredLeagues: [FFLeague] {
        var filtered = viewModel.leagues

        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.draftStatus == .completed && !$0.isSeasonComplete }
        case .drafting:
            filtered = filtered.filter { $0.draftStatus == .inProgress || $0.draftStatus == .scheduled }
        case .completed:
            filtered = filtered.filter { $0.isSeasonComplete }
        }

        return filtered
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FFSpacing.xl) {
                        // Filter chips
                        filterChips

                        // League list
                        if filteredLeagues.isEmpty {
                            emptyState
                        } else {
                            leaguesList
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Leagues")
            .searchable(text: $searchText, prompt: "Search leagues")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCreateLeague = true
                        } label: {
                            Label("Create League", systemImage: "plus.circle")
                        }

                        Button {
                            showJoinLeague = true
                        } label: {
                            Label("Join League", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
            .sheet(isPresented: $showCreateLeague) {
                CreateLeagueFlow(viewModel: viewModel)
            }
            .sheet(isPresented: $showJoinLeague) {
                JoinLeagueSheet(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.refreshLeagues()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.clearMessages() }
            } message: {
                Text(viewModel.error ?? "")
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") { viewModel.clearMessages() }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                ForEach(LeagueFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(FFAnimations.snappy) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var leaguesList: some View {
        LazyVStack(spacing: FFSpacing.md) {
            ForEach(filteredLeagues) { league in
                NavigationLink {
                    LeagueDetailView(league: league)
                } label: {
                    LeagueCard(league: league)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: FFSpacing.xl) {
            Spacer()

            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundStyle(FFColors.goldGradient)

            VStack(spacing: FFSpacing.sm) {
                Text("No Leagues Found")
                    .font(FFTypography.headlineMedium)
                    .foregroundColor(FFColors.textPrimary)

                Text("Create or join a league to start competing!")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: FFSpacing.md) {
                GoldButton(title: "Create", icon: "plus", style: .primary) {
                    showCreateLeague = true
                }

                GoldButton(title: "Join", icon: "person.badge.plus", style: .secondary) {
                    showJoinLeague = true
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FFTypography.labelMedium)
                .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textSecondary)
                .padding(.horizontal, FFSpacing.lg)
                .padding(.vertical, FFSpacing.sm)
                .background {
                    if isSelected {
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

// MARK: - Create League Sheet

struct CreateLeagueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LeaguesViewModel

    @State private var leagueName = ""
    @State private var leagueDescription = ""
    @State private var maxMembers = 8
    @State private var moviesPerPlayer = 5
    @State private var draftType: DraftType = .serpentine
    @State private var scoringMode: ScoringMode = .boxOfficeWorldwide

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FFSpacing.xl) {
                        // League Name
                        VStack(alignment: .leading, spacing: FFSpacing.sm) {
                            Text("League Name")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textSecondary)

                            TextField("Enter league name", text: $leagueName)
                                .textFieldStyle(.plain)
                                .font(FFTypography.bodyLarge)
                                .foregroundColor(FFColors.textPrimary)
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                        .fill(FFColors.backgroundElevated)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                                .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                                        }
                                }
                        }

                        // Description (Optional)
                        VStack(alignment: .leading, spacing: FFSpacing.sm) {
                            Text("Description (Optional)")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textSecondary)

                            TextField("Describe your league", text: $leagueDescription, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textPrimary)
                                .lineLimit(3...5)
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                        .fill(FFColors.backgroundElevated)
                                }
                        }

                        // Settings
                        GlassCard {
                            VStack(spacing: FFSpacing.lg) {
                                Text("League Settings")
                                    .font(FFTypography.headlineSmall)
                                    .foregroundColor(FFColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Stepper("Max Members: \(maxMembers)", value: $maxMembers, in: 2...12)
                                    .foregroundColor(FFColors.textPrimary)

                                Stepper("Movies Per Player: \(moviesPerPlayer)", value: $moviesPerPlayer, in: 1...10)
                                    .foregroundColor(FFColors.textPrimary)

                                Picker("Draft Type", selection: $draftType) {
                                    ForEach(DraftType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .foregroundColor(FFColors.textPrimary)

                                Picker("Scoring", selection: $scoringMode) {
                                    ForEach(ScoringMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .foregroundColor(FFColors.textPrimary)
                            }
                        }

                        GoldButton(title: "Create League", icon: "plus.circle", fullWidth: true) {
                            Task {
                                let settings = LeagueSettings(
                                    draftType: draftType,
                                    scoringMode: scoringMode,
                                    moviesPerPlayer: moviesPerPlayer
                                )
                                if await viewModel.createLeague(
                                    name: leagueName,
                                    description: leagueDescription.isEmpty ? nil : leagueDescription,
                                    maxMembers: maxMembers,
                                    settings: settings
                                ) != nil {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(leagueName.isEmpty || viewModel.isCreating)

                        if viewModel.isCreating {
                            ProgressView()
                                .tint(FFColors.goldPrimary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Create League")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Join League Sheet

struct JoinLeagueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LeaguesViewModel
    @State private var inviteCode = ""

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: FFSpacing.xl) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(FFColors.goldGradient)

                    Text("Join League")
                        .font(FFTypography.displaySmall)
                        .foregroundColor(FFColors.textPrimary)

                    VStack(alignment: .leading, spacing: FFSpacing.sm) {
                        Text("Invite Code")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.textSecondary)

                        TextField("Enter 6-digit code", text: $inviteCode)
                            .textFieldStyle(.plain)
                            .font(FFTypography.titleLarge)
                            .foregroundColor(FFColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                    .fill(FFColors.backgroundElevated)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                            .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                                    }
                            }
                            .onChange(of: inviteCode) { _, newValue in
                                // Limit to 6 characters
                                if newValue.count > 6 {
                                    inviteCode = String(newValue.prefix(6))
                                }
                            }
                    }
                    .padding(.horizontal, FFSpacing.xl)

                    GoldButton(title: "Join League", fullWidth: true) {
                        Task {
                            if await viewModel.joinLeague(inviteCode: inviteCode) {
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, FFSpacing.xl)
                    .disabled(inviteCode.count < 6 || viewModel.isJoining)

                    if viewModel.isJoining {
                        ProgressView()
                            .tint(FFColors.goldPrimary)
                    }

                    Spacer()
                }
                .padding(.top, FFSpacing.xxxl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - League Detail View

struct LeagueDetailView: View {
    let league: FFLeague

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: FFSpacing.xl) {
                    // Header
                    VStack(spacing: FFSpacing.md) {
                        Text(league.name)
                            .font(FFTypography.displaySmall)
                            .foregroundColor(FFColors.textPrimary)

                        if let description = league.description {
                            Text(description)
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()

                    // Standings
                    StandingsCard(
                        standings: FFTeamStanding.sampleStandings,
                        currentUserId: "user_001"
                    )
                    .padding(.horizontal)

                    // Settings info
                    GlassCard {
                        VStack(alignment: .leading, spacing: FFSpacing.md) {
                            Text("League Settings")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            SettingRow(label: "Scoring", value: league.settings.scoringMode.displayName)
                            SettingRow(label: "Draft Type", value: league.settings.draftType.displayName)
                            SettingRow(label: "Movies per Team", value: "\(league.settings.moviesPerPlayer)")
                            SettingRow(label: "Season", value: "\(league.seasonYear)")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("League Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
            Spacer()
            Text(value)
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    LeaguesView()
        .ffTheme()
}
