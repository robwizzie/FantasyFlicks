//
//  LeaguesView.swift
//  FantasyFlicks
//
//  Leagues tab - list of user's leagues
//

import SwiftUI

struct LeaguesView: View {
    @StateObject private var viewModel = LeaguesViewModel()
    @ObservedObject private var navigationCoordinator = NavigationCoordinator.shared
    @State private var searchText = ""
    @State private var selectedFilter: LeagueFilter = .all

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
                            navigationCoordinator.showCreateLeague = true
                        } label: {
                            Label("Create League", systemImage: "plus.circle")
                        }

                        Button {
                            navigationCoordinator.showJoinLeague = true
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
            .sheet(isPresented: $navigationCoordinator.showCreateLeague) {
                CreateLeagueFlow(viewModel: viewModel)
            }
            .sheet(isPresented: $navigationCoordinator.showJoinLeague) {
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
                    navigationCoordinator.showCreateLeague = true
                }

                GoldButton(title: "Join", icon: "person.badge.plus", style: .secondary) {
                    navigationCoordinator.showJoinLeague = true
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
                                    moviesPerPlayer: moviesPerPlayer,
                                    scoringMode: scoringMode
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
    @StateObject private var draftViewModel = DraftViewModel()
    @State private var showDraftRoom = false
    @State private var showInviteCode = false
    @State private var isStartingDraft = false

    private var isCommissioner: Bool {
        league.commissionerId == AuthenticationService.shared.currentUser?.id
    }

    private var canStartDraft: Bool {
        isCommissioner && league.draftStatus == .pending && league.memberCount >= 2
    }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: FFSpacing.xl) {
                    // Header with mode icon
                    VStack(spacing: FFSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(FFColors.goldPrimary.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: league.settings.leagueMode.icon)
                                .font(.system(size: 36))
                                .foregroundStyle(FFColors.goldGradient)
                        }

                        Text(league.name)
                            .font(FFTypography.displaySmall)
                            .foregroundColor(FFColors.textPrimary)

                        HStack(spacing: FFSpacing.md) {
                            Text(league.settings.leagueMode.displayName)
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.goldPrimary)

                            Text("•")
                                .foregroundColor(FFColors.textTertiary)

                            Text("\(String(league.seasonYear)) Season")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textSecondary)
                        }

                        if let description = league.description {
                            Text(description)
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()

                    // Draft Status Card
                    draftStatusCard
                        .padding(.horizontal)

                    // Quick Actions
                    quickActionsSection
                        .padding(.horizontal)

                    // Members
                    membersSection
                        .padding(.horizontal)

                    // Settings info
                    GlassCard {
                        VStack(alignment: .leading, spacing: FFSpacing.md) {
                            Text("League Settings")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            SettingRow(label: "Mode", value: league.settings.leagueMode.displayName)
                            SettingRow(label: "Scoring", value: league.settings.scoringMode.displayName)
                            SettingRow(label: "Draft Type", value: league.settings.draftType.displayName)
                            SettingRow(label: "Movies per Team", value: "\(league.settings.moviesPerPlayer)")
                            SettingRow(label: "Pick Timer", value: formatTime(league.settings.pickTimerSeconds))

                            if league.settings.tradingSettings.enabled {
                                SettingRow(label: "Trading", value: league.settings.tradingSettings.approvalMode.displayName)
                            } else {
                                SettingRow(label: "Trading", value: "Disabled")
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Invite Code Section (Commissioner only)
                    if isCommissioner {
                        inviteCodeSection
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("League Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDraftRoom) {
            if let draftId = league.draftId {
                DraftRoomView(draftId: draftId, leagueName: league.name)
            }
        }
        .alert("Error", isPresented: .constant(draftViewModel.error != nil)) {
            Button("OK") { draftViewModel.error = nil }
        } message: {
            Text(draftViewModel.error ?? "")
        }
    }

    // MARK: - Draft Status Card

    private var draftStatusCard: some View {
        GlassCard(goldTint: league.draftStatus == .inProgress) {
            VStack(spacing: FFSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Draft Status")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.textSecondary)

                        HStack(spacing: FFSpacing.sm) {
                            if league.draftStatus == .inProgress {
                                Circle()
                                    .fill(FFColors.ruby)
                                    .frame(width: 8, height: 8)
                            }

                            Text(league.draftStatus.displayName)
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(draftStatusColor)
                        }
                    }

                    Spacer()

                    if let scheduledDate = league.draftScheduledAt, league.draftStatus == .scheduled {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(scheduledDate, format: .dateTime.month().day())
                                .font(FFTypography.titleMedium)
                                .foregroundColor(FFColors.goldPrimary)

                            Text(scheduledDate, format: .dateTime.hour().minute())
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textSecondary)
                        }
                    }
                }

                // Action buttons based on draft status
                if league.draftStatus == .inProgress {
                    GoldButton(title: "Enter Draft Room", icon: "play.fill", style: .ruby, fullWidth: true) {
                        showDraftRoom = true
                    }
                } else if canStartDraft {
                    GoldButton(title: "Start Draft Now", icon: "flag.checkered", isLoading: isStartingDraft, fullWidth: true) {
                        startDraft()
                    }
                } else if league.draftStatus == .pending && !isCommissioner {
                    Text("Waiting for commissioner to start the draft")
                        .font(FFTypography.bodySmall)
                        .foregroundColor(FFColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(FFColors.backgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                } else if league.draftStatus == .completed {
                    HStack(spacing: FFSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(FFColors.success)
                        Text("Draft Complete - Season in Progress")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.success)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FFColors.success.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                }
            }
        }
    }

    private var draftStatusColor: Color {
        switch league.draftStatus {
        case .pending: return FFColors.textSecondary
        case .scheduled: return FFColors.goldPrimary
        case .inProgress: return FFColors.ruby
        case .paused: return FFColors.warning
        case .completed: return FFColors.success
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: FFSpacing.md) {
            QuickActionButton(icon: "person.2.fill", title: "Roster") {
                // Navigate to roster
            }

            QuickActionButton(icon: "arrow.left.arrow.right", title: "Trades") {
                // Navigate to trades
            }

            QuickActionButton(icon: "chart.line.uptrend.xyaxis", title: "Stats") {
                // Navigate to stats
            }

            QuickActionButton(icon: "gearshape.fill", title: "Settings") {
                // Navigate to settings
            }
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack {
                    Text("Members")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.textPrimary)

                    Spacer()

                    Text("\(league.memberCount)/\(league.maxMembers)")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)
                }

                // Member list placeholder
                ForEach(0..<min(league.memberCount, 5), id: \.self) { index in
                    HStack(spacing: FFSpacing.md) {
                        Circle()
                            .fill(FFColors.goldPrimary.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text("\(index + 1)")
                                    .font(FFTypography.labelSmall)
                                    .foregroundColor(FFColors.goldPrimary)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(index == 0 ? "Commissioner" : "Member \(index + 1)")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textPrimary)

                            if index == 0 {
                                Text("League Owner")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.goldPrimary)
                            }
                        }

                        Spacer()
                    }
                }

                if league.memberCount < league.maxMembers {
                    Text("\(league.maxMembers - league.memberCount) spots remaining")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, FFSpacing.sm)
                }
            }
        }
    }

    // MARK: - Invite Code Section

    private var inviteCodeSection: some View {
        GlassCard {
            VStack(spacing: FFSpacing.md) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(FFColors.goldPrimary)

                    Text("Invite Members")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.textPrimary)

                    Spacer()
                }

                HStack {
                    Text(league.inviteCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(FFColors.textPrimary)
                        .tracking(4)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = league.inviteCode
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 20))
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
                .padding()
                .background(FFColors.backgroundDark)
                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))

                Text("Share this code with friends to invite them")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }
        }
    }

    // MARK: - Helper Methods

    private func startDraft() {
        isStartingDraft = true
        Task {
            if await draftViewModel.startDraft(leagueId: league.id) != nil {
                isStartingDraft = false
                showDraftRoom = true
            } else {
                isStartingDraft = false
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 {
            return "\(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(secs) sec"
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FFSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .fill(FFColors.backgroundElevated)
                        .frame(height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(FFColors.goldPrimary)
                }

                Text(title)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
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
