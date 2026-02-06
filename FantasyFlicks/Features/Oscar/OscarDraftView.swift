//
//  OscarDraftView.swift
//  FantasyFlicks
//
//  Oscar prediction draft room - pick nominees for each category
//

import SwiftUI

struct OscarDraftView: View {
    let draftId: String
    let leagueId: String
    let leagueName: String

    @StateObject private var viewModel = OscarDraftViewModel()
    @State private var selectedTab: OscarDraftTab = .categories
    @State private var selectedCategoryId: String?
    @State private var showConfirmPick = false
    @State private var selectedNominee: OscarNominee?
    @State private var selectedCategory: OscarCategory?
    @Environment(\.dismiss) private var dismiss

    enum OscarDraftTab: String, CaseIterable {
        case categories = "Categories"
        case myPicks = "My Picks"
        case standings = "Standings"
        case history = "History"
    }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            if viewModel.isLoading && viewModel.draftStatus == .pending {
                loadingView
            } else {
                VStack(spacing: 0) {
                    // Header
                    oscarDraftHeader

                    // Current pick banner
                    currentPickBanner

                    // Tab selector
                    tabSelector

                    // Content
                    TabView(selection: $selectedTab) {
                        categoriesView
                            .tag(OscarDraftTab.categories)

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
                Image(systemName: "xmark")
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

                Text("Oscar Predictions - Round \(viewModel.currentRound) of \(viewModel.totalRounds)")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }

            Spacer()

            // Timer or no-limit indicator
            if viewModel.pickTimerSeconds > 0 {
                TimerView(remainingTime: viewModel.remainingTime)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "infinity")
                        .font(.system(size: 12))
                    Text("No Limit")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(FFColors.goldPrimary)
                .padding(.horizontal, FFSpacing.sm)
                .padding(.vertical, FFSpacing.xs)
                .background(FFColors.goldPrimary.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(FFColors.backgroundElevated)
    }

    // MARK: - Current Pick Banner

    private var currentPickBanner: some View {
        Group {
            if viewModel.isDraftComplete {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(FFColors.success)
                    Text("Draft Complete!")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.success)
                    Spacer()
                }
                .padding()
                .background(FFColors.success.opacity(0.15))
            } else if viewModel.isMyTurn {
                HStack(spacing: FFSpacing.md) {
                    Circle()
                        .fill(FFColors.goldPrimary)
                        .frame(width: 10, height: 10)
                        .modifier(PulsingModifier())

                    Text("Your Pick!")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.goldPrimary)

                    Spacer()

                    Text("\(viewModel.myPicks.count)/\(viewModel.totalRounds)")
                        .font(FFTypography.statSmall)
                        .foregroundColor(FFColors.goldPrimary)
                }
                .padding()
                .background(FFColors.goldPrimary.opacity(0.15))
            } else {
                HStack(spacing: FFSpacing.md) {
                    Text("Pick \(viewModel.totalPicksMade + 1) of \(viewModel.totalPicksNeeded)")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)

                    Text("Waiting for pick...")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textTertiary)

                    Spacer()

                    let progress = viewModel.totalPicksNeeded > 0
                        ? Double(viewModel.totalPicksMade) / Double(viewModel.totalPicksNeeded)
                        : 0
                    Text("\(Int(progress * 100))%")
                        .font(FFTypography.statSmall)
                        .foregroundColor(FFColors.goldPrimary)
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
                // Major categories first
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
                            nominees: viewModel.nominees(for: category.id),
                            isPicked: viewModel.hasPickedCategory(category.id),
                            isPickable: viewModel.isMyTurn && !viewModel.hasPickedCategory(category.id),
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
                            nominees: viewModel.nominees(for: category.id),
                            isPicked: viewModel.hasPickedCategory(category.id),
                            isPickable: viewModel.isMyTurn && !viewModel.hasPickedCategory(category.id),
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

    // MARK: - My Picks View

    private var myPicksView: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                VStack(spacing: FFSpacing.sm) {
                    Text("Your Predictions")
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text("\(viewModel.myPicks.count) of \(viewModel.totalRounds) picks made")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
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

                    if viewModel.isDraftComplete {
                        Text("Draft complete - awaiting ceremony results")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    } else {
                        Text("Live draft standings")
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                    }
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
}

// MARK: - Oscar Category Card

struct OscarCategoryCard: View {
    let category: OscarCategory
    let nominees: [OscarNominee]
    let isPicked: Bool
    let isPickable: Bool
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
                VStack(spacing: FFSpacing.sm) {
                    if nominees.isEmpty {
                        Text("Nominees not yet announced")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textTertiary)
                            .padding()
                    } else {
                        ForEach(nominees) { nominee in
                            NomineeRow(
                                nominee: nominee,
                                isPickable: isPickable && !isPicked,
                                onSelect: { onSelectNominee(nominee) }
                            )
                        }
                    }
                }
                .padding(.horizontal)
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
    let isPickable: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            // Poster thumbnail
            if let url = nominee.posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FFColors.backgroundDark)
                }
                .frame(width: 36, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(FFColors.backgroundDark)
                    .frame(width: 36, height: 54)
                    .overlay {
                        Image(systemName: "film")
                            .font(.system(size: 12))
                            .foregroundColor(FFColors.textTertiary)
                    }
            }

            // Nominee info
            VStack(alignment: .leading, spacing: 2) {
                Text(nominee.name)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                if let movie = nominee.movieTitle {
                    Text(movie)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                        .lineLimit(1)
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
        .padding(.vertical, FFSpacing.xs)
    }
}

// MARK: - Oscar Pick Card

struct OscarPickCard: View {
    let pick: OscarPick

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            // Category icon
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

            // Result indicator
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
            // Rank
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
            // Category icon
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

            // Result
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
    let isSubmitting: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: FFSpacing.xl) {
                    // Trophy icon
                    ZStack {
                        Circle()
                            .fill(FFColors.goldPrimary.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(FFColors.goldGradient)
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
