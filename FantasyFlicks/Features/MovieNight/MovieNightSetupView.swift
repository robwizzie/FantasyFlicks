//
//  MovieNightSetupView.swift
//  FantasyFlicks
//
//  Multi-step setup flow for creating a Movie Night session.
//
//  The controls themselves live in MovieNightFilterSections so the host's
//  in-lobby editor renders exactly the same ones. Every filter here maps to a
//  TMDB discover parameter applied on every deck query, and the live match
//  count shows what those choices are actually doing before anyone is invited.
//

import SwiftUI

struct MovieNightSetupView: View {
    @ObservedObject var viewModel: MovieNightViewModel
    @State private var currentStep = 0
    @State private var filters = MovieNightFilters.default
    @State private var genres: [Genre] = []
    @State private var isLoadingGenres = true
    @State private var showExitConfirm = false

    private let totalSteps = 5

    private var genreNames: [Int: String] {
        Dictionary(uniqueKeysWithValues: genres.map { ($0.id, $0.name) })
    }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar

                Group {
                    switch currentStep {
                    case 0: moodStep
                    case 1: whereToWatchStep
                    case 2: constraintsStep
                    case 3: tuneStep
                    default: reviewStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)

                // Hidden on the first step — there's nothing to report before
                // the host has made a choice.
                if currentStep > 0 {
                    MovieNightMatchCountBar(filters: filters)
                        .padding(.horizontal)
                        .padding(.top, FFSpacing.xs)
                }

                navigationButtons
            }
        }
        .navigationTitle(stepTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showExitConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
        .alert("Discard Setup?", isPresented: $showExitConfirm) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                viewModel.currentPhase = .entry
            }
        } message: {
            Text("Your filter selections will be lost.")
        }
        .task {
            await loadGenres()
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Mood"
        case 1: return "Where to Watch"
        case 2: return "Time & Audience"
        case 3: return "Fine-Tune"
        default: return "Review"
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: FFSpacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep
                          ? FFColors.goldGradientHorizontal
                          : LinearGradient(colors: [FFColors.backgroundElevated2], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 4)
                    .animation(FFAnimations.smooth, value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.md)
    }

    // MARK: - Steps

    private var moodStep: some View {
        stepScroll(
            title: "What are you in the mood for?",
            subtitle: "Pick any genres you fancy — or skip for everything"
        ) {
            MovieNightMoodSection(filters: $filters, genres: genres, isLoading: isLoadingGenres)
        }
    }

    private var whereToWatchStep: some View {
        stepScroll(
            title: "Where can you watch?",
            subtitle: "We'll only show films you can actually start tonight"
        ) {
            MovieNightWhereSection(filters: $filters)
        }
    }

    private var constraintsStep: some View {
        stepScroll(
            title: "How long have you got?",
            subtitle: "And who's watching"
        ) {
            VStack(spacing: FFSpacing.lg) {
                GlassCard { MovieNightLengthSection(filters: $filters) }
                GlassCard { MovieNightRatingSection(filters: $filters) }
                GlassCard { MovieNightEraSection(filters: $filters) }
                GlassCard { MovieNightAudienceSection(filters: $filters) }
            }
        }
    }

    private var tuneStep: some View {
        stepScroll(
            title: "Fine-tune",
            subtitle: "Quality bar, sources, and how many cards to swipe"
        ) {
            VStack(spacing: FFSpacing.lg) {
                GlassCard { MovieNightQualitySection(filters: $filters) }
                GlassCard { MovieNightSourcesSection(filters: $filters) }
                GlassCard { MovieNightWatchedSection(filters: $filters) }
                GlassCard { MovieNightDeckSizeSection(filters: $filters) }
            }
        }
    }

    private var reviewStep: some View {
        stepScroll(
            title: "Ready to go",
            subtitle: "Here's what your deck will be built from"
        ) {
            VStack(spacing: FFSpacing.lg) {
                GlassCard(goldTint: true) {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        Text("Active filters")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.textTertiary)

                        let chips = filters.activeSummaryChips(genreNames: genreNames)
                        if chips.isEmpty {
                            Text("No filters — anything goes.")
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textPrimary)
                        } else {
                            FlowChips(chips: chips)
                        }

                        Divider().background(Color.white.opacity(0.1))

                        reviewRow(
                            icon: "square.stack.fill",
                            title: "Deck size",
                            value: "\(filters.deckSize) movies to swipe"
                        )
                        reviewRow(
                            icon: "sparkles",
                            title: "Sources",
                            value: sourcesSummary
                        )
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: FFSpacing.sm) {
                        MovieNightSectionHeader(icon: "lightbulb.fill", title: "Tip")
                        Text("If the count above looks low, go back a step. Dropping the minimum rating, widening the era, or adding a streaming service opens things up fastest.")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var sourcesSummary: String {
        var parts = ["Popular", "Highest rated"]
        if filters.includeTrending { parts.append("Recent") }
        if filters.includeNowPlaying { parts.append("In theaters") }
        return parts.joined(separator: " · ")
    }

    private func reviewRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: FFSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(FFColors.goldPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.textTertiary)
                Text(value)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: FFSpacing.md) {
            if currentStep > 0 {
                GoldButton(title: "Back", style: .secondary, size: .medium) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                }
            }

            if currentStep < totalSteps - 1 {
                GoldButton(title: "Next", style: .primary, size: .medium, fullWidth: true) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                }
            } else {
                GoldButton(
                    title: viewModel.isLoading ? "Creating…" : "Create Movie Night",
                    icon: "party.popper.fill",
                    style: .ruby,
                    size: .large,
                    isLoading: viewModel.isLoading,
                    fullWidth: true
                ) {
                    Task { await viewModel.createSession(filters: filters) }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
    }

    // MARK: - Shared Bits

    private func stepScroll<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FFSpacing.xl) {
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text(title)
                        .font(FFTypography.displaySmall)
                        .foregroundColor(FFColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                content()
            }
            .padding()
        }
    }

    private func loadGenres() async {
        do {
            genres = try await TMDBService.shared.getGenres()
        } catch {
            genres = MovieNightSetupView.fallbackGenres
        }
        isLoadingGenres = false
    }

    /// Used when TMDB's genre list is unreachable, and by the lobby editor.
    static let fallbackGenres = [
        Genre(id: 28, name: "Action"),
        Genre(id: 12, name: "Adventure"),
        Genre(id: 16, name: "Animation"),
        Genre(id: 35, name: "Comedy"),
        Genre(id: 80, name: "Crime"),
        Genre(id: 99, name: "Documentary"),
        Genre(id: 18, name: "Drama"),
        Genre(id: 10751, name: "Family"),
        Genre(id: 14, name: "Fantasy"),
        Genre(id: 27, name: "Horror"),
        Genre(id: 9648, name: "Mystery"),
        Genre(id: 10749, name: "Romance"),
        Genre(id: 878, name: "Sci-Fi"),
        Genre(id: 53, name: "Thriller")
    ]
}

// MARK: - Flow Chips

/// Wrapping row of filter chips. Used anywhere we summarise a filter set.
struct FlowChips: View {
    let chips: [(icon: String, text: String)]

    var body: some View {
        FlowLayout(spacing: FFSpacing.sm) {
            ForEach(Array(chips.enumerated()), id: \.offset) { item in
                HStack(spacing: 5) {
                    Image(systemName: item.element.icon)
                        .font(.system(size: 10))
                    Text(item.element.text)
                        .font(FFTypography.labelSmall)
                        .lineLimit(1)
                }
                .foregroundColor(FFColors.goldPrimary)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, 6)
                .background(FFColors.goldPrimary.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }
}

/// Minimal wrapping layout — chips flow onto as many lines as they need.
///
/// A subview wider than the container is clamped to the container rather than
/// allowed to run past its edge. Chips size themselves from their text, so one
/// long label (a list of every selected genre, a row of provider names) would
/// otherwise be placed at its full intrinsic width and visibly bleed out of the
/// card. Clamping hands it a narrower proposal instead, so its `lineLimit(1)`
/// text truncates and the capsule stays inside.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = Self.clampedSize(of: subview, toWidth: maxWidth)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? spacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        return CGSize(
            width: maxWidth == .infinity ? rowWidth : maxWidth,
            height: totalHeight + rowHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = Self.clampedSize(of: subview, toWidth: bounds.width)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    /// A subview's natural size, narrowed to the container when it doesn't fit.
    /// Height is re-measured at the clamped width so a wrapped label still gets
    /// the room it needs.
    private static func clampedSize(of subview: LayoutSubview, toWidth limit: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard natural.width > limit else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: limit, height: nil))
    }
}
