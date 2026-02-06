//
//  OscarDraftView.swift
//  FantasyFlicks
//
//  Oscar prediction draft room - pick nominees for each category
//  Features search/filter, expert odds, roster %, and ADP
//

import SwiftUI

struct OscarDraftView: View {
    let draftId: String
    let leagueId: String
    let leagueName: String

    @StateObject private var viewModel = OscarDraftViewModel()
    @State private var selectedTab: OscarDraftTab = .categories
    @State private var showConfirmPick = false
    @State private var selectedNominee: OscarNominee?
    @State private var selectedCategory: OscarCategory?
    @State private var showSearch = false
    @Environment(\.dismiss) private var dismiss

    enum OscarDraftTab: String, CaseIterable {
        case categories = "Categories"
        case all = "All Nominees"
        case myPicks = "My Picks"
        case standings = "Standings"
        case history = "History"
    }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            if viewModel.isLoading && viewModel.draftStatus == .pending {
                loadingView
            } else if viewModel.isDraftComplete {
                draftCompleteView
            } else {
                VStack(spacing: 0) {
                    oscarDraftHeader
                    currentPickBanner

                    // Search bar (when active)
                    if showSearch {
                        searchBar
                    }

                    tabSelector

                    TabView(selection: $selectedTab) {
                        categoriesView
                            .tag(OscarDraftTab.categories)

                        allNomineesView
                            .tag(OscarDraftTab.all)

                        myPicksView
                            .tag(OscarDraftTab.myPicks)

                        standingsView
                            .tag(OscarDraftTab.standings)

                        historyView
                            .tag(OscarDraftTab.history)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadOscarDraft(leagueId: leagueId, draftId: draftId)
        }
        .sheet(isPresented: $showConfirmPick) {
            if let nominee = selectedNominee, let category = selectedCategory {
                OscarConfirmPickSheet(
                    nominee: nominee,
                    category: category,
                    viewModel: viewModel,
                    isSubmitting: viewModel.isSubmittingPick
                ) {
                    Task {
                        if await viewModel.submitOscarPick(
                            categoryId: category.id,
                            nominee: nominee,
                            draftId: draftId,
                            leagueId: leagueId
                        ) {
                            selectedNominee = nil
                            selectedCategory = nil
                            showConfirmPick = false
                        }
                    }
                }
            }
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

            Text("Loading Oscar Draft...")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
        }
    }

    // MARK: - Header

    private var oscarDraftHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(FFColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(FFColors.backgroundElevated)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundColor(FFColors.goldPrimary)
                    Text(leagueName)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)
                }

                Text("Rd \(viewModel.currentRound) \u{2022} Pick \(viewModel.totalPicksMade + 1) of \(viewModel.totalPicksNeeded)")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }

            Spacer()

            HStack(spacing: FFSpacing.sm) {
                // Search toggle
                Button {
                    withAnimation(FFAnimations.snappy) {
                        showSearch.toggle()
                        if !showSearch {
                            viewModel.searchQuery = ""
                        }
                    }
                } label: {
                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(showSearch ? FFColors.goldPrimary : FFColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(showSearch ? FFColors.goldPrimary.opacity(0.15) : FFColors.backgroundElevated)
                        .clipShape(Circle())
                }

                // Timer
                if viewModel.pickTimerSeconds > 0 {
                    TimerView(remainingTime: viewModel.remainingTime)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.sm)
        .background(FFColors.backgroundElevated)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(FFColors.textTertiary)

            TextField("Search nominees, movies...", text: $viewModel.searchQuery)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(FFColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, FFSpacing.md)
        .padding(.vertical, FFSpacing.sm)
        .background(FFColors.backgroundDark)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Current Pick Banner

    private var currentPickBanner: some View {
        Group {
            if viewModel.isMyTurn {
                HStack(spacing: FFSpacing.md) {
                    // On the clock indicator
                    VStack(spacing: 2) {
                        Circle()
                            .fill(FFColors.goldPrimary)
                            .frame(width: 10, height: 10)
                            .modifier(PulsingModifier())
                        if viewModel.pickTimerSeconds > 0 {
                            Text("\(viewModel.remainingTime)s")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(viewModel.remainingTime <= 10 ? FFColors.ruby : FFColors.goldPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ON THE CLOCK")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(FFColors.goldPrimary)
                        Text("Make your prediction")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textSecondary)
                    }

                    Spacer()

                    // Pick counter pill
                    HStack(spacing: 4) {
                        Text("\(viewModel.myPicks.count)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FFColors.goldPrimary)
                        Text("/\(viewModel.totalRounds)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FFColors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(FFColors.backgroundDark)
                    .clipShape(Capsule())
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [FFColors.goldPrimary.opacity(0.15), FFColors.goldPrimary.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            } else if viewModel.draftStatus == .inProgress {
                HStack(spacing: FFSpacing.md) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(FFColors.textSecondary)

                    Text("Waiting for pick...")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)

                    Spacer()

                    // Progress bar
                    let progress = viewModel.totalPicksNeeded > 0
                        ? Double(viewModel.totalPicksMade) / Double(viewModel.totalPicksNeeded)
                        : 0
                    HStack(spacing: 6) {
                        ProgressView(value: progress)
                            .tint(FFColors.goldPrimary)
                            .frame(width: 60)
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
                .padding()
                .background(FFColors.backgroundDark)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                ForEach(OscarDraftTab.allCases, id: \.self) { tab in
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

    // MARK: - Categories View

    private var categoriesView: some View {
        ScrollView {
            LazyVStack(spacing: FFSpacing.md) {
                let majorCats = viewModel.availableCategories.filter { $0.isMajor }
                let otherCats = viewModel.availableCategories.filter { !$0.isMajor }

                if !majorCats.isEmpty {
                    HStack {
                        Text("MAJOR CATEGORIES")
                            .font(FFTypography.overline)
                            .foregroundColor(FFColors.goldPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    ForEach(majorCats) { category in
                        OscarCategoryCard(
                            category: category,
                            nominees: viewModel.filteredNominees(for: category.id),
                            isPicked: viewModel.hasPickedCategory(category.id),
                            isPickable: viewModel.isMyTurn && !viewModel.hasPickedCategory(category.id),
                            viewModel: viewModel,
                            onSelectNominee: { nominee in
                                selectedCategory = category
                                selectedNominee = nominee
                                showConfirmPick = true
                            }
                        )
                    }
                }

                if !otherCats.isEmpty {
                    HStack {
                        Text("OTHER CATEGORIES")
                            .font(FFTypography.overline)
                            .foregroundColor(FFColors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, FFSpacing.md)

                    ForEach(otherCats) { category in
                        OscarCategoryCard(
                            category: category,
                            nominees: viewModel.filteredNominees(for: category.id),
                            isPicked: viewModel.hasPickedCategory(category.id),
                            isPickable: viewModel.isMyTurn && !viewModel.hasPickedCategory(category.id),
                            viewModel: viewModel,
                            onSelectNominee: { nominee in
                                selectedCategory = category
                                selectedNominee = nominee
                                showConfirmPick = true
                            }
                        )
                    }
                }

                if viewModel.availableCategories.isEmpty && !viewModel.isDraftComplete {
                    VStack(spacing: FFSpacing.lg) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(FFColors.goldGradient)

                        Text("All categories picked!")
                            .font(FFTypography.headlineSmall)
                            .foregroundColor(FFColors.textPrimary)

                        Text("Wait for the ceremony to see your results")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                    .padding(FFSpacing.xxxl)
                }
            }
            .padding()
            .padding(.bottom, 60)
        }
    }

    // MARK: - All Nominees View (View All)

    private var allNomineesView: some View {
        VStack(spacing: 0) {
            // Sort by label + options
            VStack(spacing: FFSpacing.sm) {
                HStack {
                    Text("Sort by")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, FFSpacing.sm)

                HStack(spacing: FFSpacing.sm) {
                    ForEach(OscarDraftViewModel.NomineeSortOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.sortOption = option
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: sortIcon(for: option))
                                    .font(.system(size: 12))
                                Text(option.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(viewModel.sortOption == option ? FFColors.backgroundDark : FFColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if viewModel.sortOption == option {
                                    Capsule().fill(FFColors.goldGradientHorizontal)
                                } else {
                                    Capsule().fill(FFColors.backgroundElevated)
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }

            // Category filter chips
            VStack(spacing: FFSpacing.xs) {
                HStack {
                    Text("Filter by category")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.textTertiary)
                    Spacer()
                    if viewModel.playerCategoryFilter != nil {
                        Button {
                            viewModel.playerCategoryFilter = nil
                        } label: {
                            Text("Clear")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(FFColors.goldPrimary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, FFSpacing.sm)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.sm) {
                        Button {
                            viewModel.playerCategoryFilter = nil
                        } label: {
                            Text("All")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(viewModel.playerCategoryFilter == nil ? FFColors.backgroundDark : FFColors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    if viewModel.playerCategoryFilter == nil {
                                        Capsule().fill(FFColors.goldPrimary)
                                    } else {
                                        Capsule().fill(FFColors.backgroundElevated)
                                    }
                                }
                        }

                        ForEach(OscarCategory.allCategories) { cat in
                            Button {
                                viewModel.playerCategoryFilter = cat.id
                            } label: {
                                Text(cat.shortName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(viewModel.playerCategoryFilter == cat.id ? FFColors.backgroundDark : FFColors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background {
                                        if viewModel.playerCategoryFilter == cat.id {
                                            Capsule().fill(FFColors.goldPrimary)
                                        } else {
                                            Capsule().fill(FFColors.backgroundElevated)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, FFSpacing.sm)

            // Column headers
            HStack(spacing: FFSpacing.sm) {
                Text("RK")
                    .frame(width: 24)
                Text("NOMINEE")
                Spacer()
                Text("ODDS")
                    .frame(width: 44)
                Text("RSTD")
                    .frame(width: 40)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(FFColors.textTertiary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(FFColors.backgroundElevated)

            // Nominee list
            ScrollView {
                LazyVStack(spacing: 0) {
                    let sortedNominees = viewModel.allNomineesSorted
                    ForEach(Array(sortedNominees.enumerated()), id: \.element.id) { index, nominee in
                        PlayerRow(
                            rank: index + 1,
                            nominee: nominee,
                            posterURL: viewModel.posterURL(for: nominee),
                            isPickable: viewModel.isMyTurn && !viewModel.hasPickedCategory(nominee.categoryId),
                            isNomineePicked: viewModel.isNomineePicked(nominee.id, in: nominee.categoryId),
                            rosterPct: viewModel.rosterPercentageString(for: nominee.id, categoryId: nominee.categoryId),
                            isFavorite: viewModel.isFavorite(nominee.id),
                            onSelect: {
                                if let cat = nominee.category {
                                    selectedCategory = cat
                                    selectedNominee = nominee
                                    showConfirmPick = true
                                }
                            },
                            onFavorite: {
                                viewModel.toggleFavorite(nominee.id)
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.04))
                    }

                    // Odds attribution
                    VStack(spacing: 4) {
                        if viewModel.hasLiveOdds {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(FFColors.success)
                                    .frame(width: 6, height: 6)
                                Text("Live odds powered by Kalshi")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(FFColors.textSecondary)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                Text("Showing estimated odds. Live Kalshi odds unavailable.")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(FFColors.textTertiary)
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func sortIcon(for option: OscarDraftViewModel.NomineeSortOption) -> String {
        switch option {
        case .odds: return "chart.bar.fill"
        case .rostered: return "person.2.fill"
        case .category: return "rectangle.grid.1x2.fill"
        case .favorites: return "star.fill"
        }
    }

    // MARK: - My Picks View

    private var myPicksView: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                // Stats header
                HStack(spacing: FFSpacing.lg) {
                    StatBubble(value: "\(viewModel.myPicks.count)", label: "Picks", color: FFColors.goldPrimary)
                    StatBubble(value: "\(viewModel.totalRounds)", label: "Total", color: FFColors.textSecondary)
                    StatBubble(
                        value: "\(viewModel.totalRounds - viewModel.myPicks.count)",
                        label: "Remaining",
                        color: viewModel.myPicks.count < viewModel.totalRounds ? FFColors.ruby : FFColors.success
                    )
                }
                .padding(.top)

                if viewModel.myPicks.isEmpty {
                    VStack(spacing: FFSpacing.lg) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundStyle(FFColors.goldGradient)

                        Text("No picks yet")
                            .font(FFTypography.headlineSmall)
                            .foregroundColor(FFColors.textPrimary)

                        Text("When it's your turn, pick your Oscar winner predictions")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(FFSpacing.xxxl)
                } else {
                    LazyVStack(spacing: FFSpacing.md) {
                        ForEach(viewModel.myPicks) { pick in
                            OscarPickCard(pick: pick)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 60)
        }
    }

    // MARK: - Standings View

    private var standingsView: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                VStack(spacing: FFSpacing.sm) {
                    Text("Standings")
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text("Live draft standings")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                }
                .padding(.top)

                if viewModel.standings.isEmpty {
                    VStack(spacing: FFSpacing.lg) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 48))
                            .foregroundStyle(FFColors.goldGradient)

                        Text("Standings will appear once picks are made")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                    .padding(FFSpacing.xxxl)
                } else {
                    LazyVStack(spacing: FFSpacing.sm) {
                        ForEach(viewModel.standings) { standing in
                            OscarStandingRow(
                                standing: standing,
                                isMe: standing.userId == AuthenticationService.shared.currentUser?.id
                            )
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 60)
        }
    }

    // MARK: - History View

    private var historyView: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                VStack(spacing: FFSpacing.sm) {
                    Text("Pick History")
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text("\(viewModel.allPicks.count) picks made")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                }
                .padding(.top)

                if viewModel.allPicks.isEmpty {
                    VStack(spacing: FFSpacing.lg) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundStyle(FFColors.goldGradient)

                        Text("No picks made yet")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
                    .padding(FFSpacing.xxxl)
                } else {
                    LazyVStack(spacing: FFSpacing.sm) {
                        ForEach(viewModel.allPicks.sorted(by: { $0.pickedAt > $1.pickedAt })) { pick in
                            OscarHistoryRow(
                                pick: pick,
                                isMe: pick.userId == AuthenticationService.shared.currentUser?.id
                            )
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 60)
        }
    }

    // MARK: - Draft Complete View

    private var draftCompleteView: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // Trophy animation area
                VStack(spacing: FFSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(FFColors.goldPrimary.opacity(0.15))
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(FFColors.goldPrimary.opacity(0.08))
                            .frame(width: 160, height: 160)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(FFColors.goldGradient)
                    }
                    .padding(.top, FFSpacing.xxxl)

                    Text("Draft Complete!")
                        .font(FFTypography.displaySmall)
                        .foregroundColor(FFColors.textPrimary)

                    Text("Your predictions are locked in for \(leagueName)")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Results summary
                GlassCard {
                    VStack(spacing: FFSpacing.md) {
                        Text("YOUR PREDICTIONS")
                            .font(FFTypography.overline)
                            .foregroundColor(FFColors.goldPrimary)

                        ForEach(viewModel.myPicks) { pick in
                            HStack(spacing: FFSpacing.md) {
                                if let category = pick.category {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(FFColors.goldPrimary)
                                        .frame(width: 28, height: 28)
                                        .background(FFColors.goldPrimary.opacity(0.15))
                                        .clipShape(Circle())
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pick.category?.shortName ?? "")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                    Text(pick.nomineeName)
                                        .font(FFTypography.labelMedium)
                                        .foregroundColor(FFColors.textPrimary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if let isCorrect = pick.isCorrect {
                                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(isCorrect ? FFColors.success : FFColors.ruby)
                                } else {
                                    Text("Pending")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(FFColors.backgroundDark)
                                        .clipShape(Capsule())
                                }
                            }

                            if pick.id != viewModel.myPicks.last?.id {
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Standings
                if !viewModel.standings.isEmpty {
                    GlassCard {
                        VStack(spacing: FFSpacing.md) {
                            Text("STANDINGS")
                                .font(FFTypography.overline)
                                .foregroundColor(FFColors.goldPrimary)

                            ForEach(viewModel.standings) { standing in
                                OscarStandingRow(
                                    standing: standing,
                                    isMe: standing.userId == AuthenticationService.shared.currentUser?.id
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Ceremony countdown
                if let settings = viewModel.oscarSettings, let ceremonyDate = settings.ceremonyDate {
                    GlassCard {
                        VStack(spacing: FFSpacing.md) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 28))
                                .foregroundStyle(FFColors.goldGradient)

                            Text("Oscar Ceremony")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            Text(ceremonyDate, format: .dateTime.month().day().year())
                                .font(FFTypography.titleMedium)
                                .foregroundColor(FFColors.goldPrimary)

                            Text("Results will be scored live during the ceremony")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal)
                }

                // Back button
                GoldButton(title: "Back to Leagues", icon: "arrow.left", fullWidth: true) {
                    dismiss()
                }
                .padding(.horizontal)
                .padding(.bottom, FFSpacing.xxxl)
            }
        }
    }
}

// MARK: - Stat Bubble

private struct StatBubble: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FFTypography.displaySmall)
                .foregroundColor(color)
            Text(label)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
    }
}

// MARK: - Oscar Category Card

struct OscarCategoryCard: View {
    let category: OscarCategory
    let nominees: [OscarNominee]
    let isPicked: Bool
    let isPickable: Bool
    let viewModel: OscarDraftViewModel
    let onSelectNominee: (OscarNominee) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Category header
            Button {
                withAnimation(FFAnimations.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isPicked ? FFColors.success : FFColors.goldPrimary)
                        .frame(width: 36, height: 36)
                        .background((isPicked ? FFColors.success : FFColors.goldPrimary).opacity(0.2))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(FFTypography.titleSmall)
                            .foregroundColor(FFColors.textPrimary)

                        Text("\(nominees.count) nominees")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }

                    Spacer()

                    if isPicked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(FFColors.success)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(FFColors.textTertiary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Nominees list (expanded)
            if isExpanded {
                VStack(spacing: 0) {
                    if nominees.isEmpty {
                        Text("No nominees match your search")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textTertiary)
                            .padding()
                    } else {
                        ForEach(nominees) { nominee in
                            NomineeRow(
                                nominee: nominee,
                                posterURL: viewModel.posterURL(for: nominee),
                                isPickable: isPickable && !isPicked,
                                isNomineePicked: viewModel.isNomineePicked(nominee.id, in: category.id),
                                rosterPct: viewModel.rosterPercentageString(for: nominee.id, categoryId: category.id),
                                onSelect: { onSelectNominee(nominee) }
                            )

                            if nominee.id != nominees.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.05))
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, FFSpacing.md)
            }
        }
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
        .overlay {
            if isPicked {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .stroke(FFColors.success.opacity(0.3), lineWidth: 1)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Nominee Row

struct NomineeRow: View {
    let nominee: OscarNominee
    let posterURL: URL?
    let isPickable: Bool
    let isNomineePicked: Bool
    let rosterPct: String
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            // Poster thumbnail
            if let url = posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    posterPlaceholder
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                posterPlaceholder
            }

            // Nominee info + odds
            VStack(alignment: .leading, spacing: 4) {
                Text(nominee.name)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(isNomineePicked ? FFColors.textTertiary : FFColors.textPrimary)
                    .lineLimit(1)
                    .strikethrough(isNomineePicked)

                if let movie = nominee.movieTitle {
                    Text(movie)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                        .lineLimit(1)
                }

                // Odds + Roster % row
                HStack(spacing: FFSpacing.sm) {
                    if let oddsStr = nominee.oddsString {
                        HStack(spacing: 2) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 8))
                            Text(oddsStr)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(nominee.isFrontrunner ? FFColors.goldPrimary : FFColors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((nominee.isFrontrunner ? FFColors.goldPrimary : FFColors.textTertiary).opacity(0.12))
                        .clipShape(Capsule())
                    }

                    if rosterPct != "0%" {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8))
                            Text(rosterPct)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(FFColors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FFColors.textTertiary.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    if nominee.isFrontrunner {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8))
                            Text("Favorite")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(FFColors.ruby)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FFColors.ruby.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                if nominee.isWinner {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                        Text("WINNER")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }

            Spacer()

            // Pick button
            if isPickable && !isNomineePicked {
                Button(action: onSelect) {
                    Text("Pick")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.backgroundDark)
                        .padding(.horizontal, FFSpacing.lg)
                        .padding(.vertical, FFSpacing.sm)
                        .background(FFColors.goldGradientHorizontal)
                        .clipShape(Capsule())
                }
            } else if isNomineePicked {
                Text("Taken")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .padding(.horizontal, FFSpacing.sm)
                    .padding(.vertical, FFSpacing.xs)
                    .background(FFColors.backgroundDark)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.sm)
        .opacity(isNomineePicked ? 0.5 : 1.0)
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(FFColors.backgroundDark)
            .frame(width: 40, height: 60)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 14))
                    .foregroundColor(FFColors.textTertiary)
            }
    }
}

// MARK: - Player Row (Fantasy Football Style)

struct PlayerRow: View {
    let rank: Int
    let nominee: OscarNominee
    let posterURL: URL?
    let isPickable: Bool
    let isNomineePicked: Bool
    let rosterPct: String
    let isFavorite: Bool
    let onSelect: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        HStack(spacing: FFSpacing.sm) {
            // Rank number
            Text("\(rank)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(rank <= 3 ? FFColors.goldPrimary : FFColors.textTertiary)
                .frame(width: 24)

            // Poster
            if let url = posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    playerPosterPlaceholder
                }
                .frame(width: 36, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                playerPosterPlaceholder
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(nominee.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isNomineePicked ? FFColors.textTertiary : FFColors.textPrimary)
                        .lineLimit(1)
                        .strikethrough(isNomineePicked)

                    if nominee.isFrontrunner {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundColor(FFColors.ruby)
                    }
                }

                if let movie = nominee.movieTitle {
                    Text(movie)
                        .font(.system(size: 11))
                        .foregroundColor(FFColors.textTertiary)
                        .lineLimit(1)
                }

                // Category badge
                Text(nominee.category?.shortName ?? "")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(nominee.category?.isMajor == true ? FFColors.goldPrimary : FFColors.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((nominee.category?.isMajor == true ? FFColors.goldPrimary : FFColors.textTertiary).opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()

            // Odds column
            Text(nominee.oddsString ?? "--")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(nominee.isFrontrunner ? FFColors.goldPrimary : FFColors.textSecondary)
                .frame(width: 44)

            // Rostered column
            Text(rosterPct)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(FFColors.textTertiary)
                .frame(width: 40)

            // Favorite star
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundColor(isFavorite ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.5))
            }
            .frame(width: 28)

            // Pick button (compact)
            if isPickable && !isNomineePicked {
                Button(action: onSelect) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(FFColors.goldGradient)
                }
            } else if isNomineePicked {
                Image(systemName: "minus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(FFColors.textTertiary.opacity(0.3))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isNomineePicked ? FFColors.backgroundDark.opacity(0.5) : Color.clear)
        .opacity(isNomineePicked ? 0.6 : 1.0)
    }

    private var playerPosterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(FFColors.backgroundDark)
            .frame(width: 36, height: 52)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 12))
                    .foregroundColor(FFColors.textTertiary)
            }
    }
}

// MARK: - Oscar Pick Card

struct OscarPickCard: View {
    let pick: OscarPick

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            if let category = pick.category {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(FFColors.goldPrimary)
                    .frame(width: 40, height: 40)
                    .background(FFColors.goldPrimary.opacity(0.2))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pick.category?.shortName ?? "Unknown")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)

                Text(pick.nomineeName)
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)

                if let movie = pick.movieTitle {
                    Text(movie)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                }
            }

            Spacer()

            if let isCorrect = pick.isCorrect {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isCorrect ? FFColors.success : FFColors.ruby)
            } else {
                Text("Pending")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .padding(.horizontal, FFSpacing.sm)
                    .padding(.vertical, FFSpacing.xs)
                    .background(FFColors.backgroundDark)
                    .clipShape(Capsule())
            }
        }
        .padding(FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
    }
}

// MARK: - Oscar Standing Row

struct OscarStandingRow: View {
    let standing: OscarStanding
    let isMe: Bool

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            ZStack {
                Circle()
                    .fill(standing.rank <= 3 ? FFColors.goldPrimary.opacity(0.2) : FFColors.backgroundDark)
                    .frame(width: 36, height: 36)

                Text("\(standing.rank)")
                    .font(FFTypography.statSmall)
                    .foregroundColor(standing.rank <= 3 ? FFColors.goldPrimary : FFColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: FFSpacing.sm) {
                    Text(standing.teamName)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)

                    if isMe {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(FFColors.backgroundDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FFColors.goldPrimary)
                            .clipShape(Capsule())
                    }
                }

                Text("\(standing.correctPicks)/\(standing.totalPicks) correct (\(standing.accuracyString))")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", standing.totalPoints))
                    .font(FFTypography.statSmall)
                    .foregroundStyle(FFColors.goldGradient)

                Text("pts")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }
        }
        .padding(FFSpacing.md)
        .background(isMe ? FFColors.goldPrimary.opacity(0.1) : FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
        .overlay {
            if isMe {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Oscar History Row

struct OscarHistoryRow: View {
    let pick: OscarPick
    let isMe: Bool

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            if let category = pick.category {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(FFColors.goldPrimary)
                    .frame(width: 28, height: 28)
                    .background(FFColors.goldPrimary.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(pick.nomineeName)
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(pick.category?.shortName ?? "")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)

                    Text("by \(isMe ? "You" : "Team \(pick.userId.prefix(6))...")")
                        .font(FFTypography.caption)
                        .foregroundColor(isMe ? FFColors.goldPrimary : FFColors.textTertiary)
                }
            }

            Spacer()

            if let isCorrect = pick.isCorrect {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCorrect ? FFColors.success : FFColors.ruby)
            }
        }
        .padding(.vertical, FFSpacing.sm)
        .padding(.horizontal, FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.small))
    }
}

// MARK: - Oscar Confirm Pick Sheet

struct OscarConfirmPickSheet: View {
    let nominee: OscarNominee
    let category: OscarCategory
    let viewModel: OscarDraftViewModel
    let isSubmitting: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: FFSpacing.xl) {
                    // Poster or trophy icon
                    if let url = viewModel.posterURL(for: nominee) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                .fill(FFColors.backgroundElevated)
                                .frame(width: 100, height: 150)
                                .overlay {
                                    ProgressView().tint(FFColors.goldPrimary)
                                }
                        }
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                        .shadow(color: FFColors.goldPrimary.opacity(0.3), radius: 12)
                    } else {
                        ZStack {
                            Circle()
                                .fill(FFColors.goldPrimary.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(FFColors.goldGradient)
                        }
                    }

                    // Category
                    Text(category.name)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.goldPrimary)
                        .padding(.horizontal, FFSpacing.lg)
                        .padding(.vertical, FFSpacing.sm)
                        .background(FFColors.goldPrimary.opacity(0.15))
                        .clipShape(Capsule())

                    // Nominee info
                    VStack(spacing: FFSpacing.sm) {
                        Text(nominee.name)
                            .font(FFTypography.displaySmall)
                            .foregroundColor(FFColors.textPrimary)
                            .multilineTextAlignment(.center)

                        if let movie = nominee.movieTitle {
                            Text(movie)
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textSecondary)
                        }
                    }

                    // Odds & stats
                    HStack(spacing: FFSpacing.lg) {
                        if let odds = nominee.oddsString {
                            VStack(spacing: 4) {
                                Text(odds)
                                    .font(FFTypography.titleMedium)
                                    .foregroundColor(FFColors.goldPrimary)
                                Text(viewModel.hasLiveOdds ? "Kalshi Odds" : "Est. Odds")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FFSpacing.md)
                            .background(FFColors.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                        }

                        let rosterPct = viewModel.rosterPercentageString(for: nominee.id, categoryId: category.id)
                        VStack(spacing: 4) {
                            Text(rosterPct)
                                .font(FFTypography.titleMedium)
                                .foregroundColor(FFColors.textPrimary)
                            Text("Rostered")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FFSpacing.md)
                        .background(FFColors.backgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Confirm button
                    VStack(spacing: FFSpacing.md) {
                        GoldButton(
                            title: "Confirm Pick",
                            icon: "checkmark.circle.fill",
                            isLoading: isSubmitting,
                            fullWidth: true,
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
            .navigationTitle("Confirm Your Prediction")
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

// MARK: - Preview

#Preview {
    OscarDraftView(draftId: "draft_001", leagueId: "league_003", leagueName: "Oscar Oracles")
}
