//
//  MovieNightFilterSections.swift
//  FantasyFlicks
//
//  The Movie Night filter controls, as standalone sections.
//
//  Both the setup flow and the host's in-lobby editor render these, so a filter
//  can only exist in one place: add a control here and both surfaces get it.
//  Previously the lobby editor was a separate hand-written copy, which is how it
//  ended up missing filters the setup flow could set.
//

import SwiftUI

// MARK: - Shared Building Blocks

struct MovieNightSectionHeader: View {
    let icon: String
    let title: String
    var tint: Color = FFColors.goldPrimary

    var body: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(tint)
            Text(title)
                .font(FFTypography.titleSmall)
                .foregroundColor(FFColors.textPrimary)
        }
    }
}

/// Horizontal single-select chip row.
struct MovieNightChipRow<Value: Equatable>: View {
    let options: [(label: String, value: Value)]
    let selected: Value
    let onSelect: (Value) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.sm) {
                ForEach(Array(options.enumerated()), id: \.offset) { item in
                    let isSelected = item.element.value == selected
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onSelect(item.element.value)
                        }
                    } label: {
                        Text(item.element.label)
                            .font(FFTypography.labelSmall)
                            .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                            .padding(.horizontal, FFSpacing.md)
                            .padding(.vertical, FFSpacing.sm)
                            .background(isSelected
                                        ? AnyShapeStyle(FFColors.goldPrimary)
                                        : AnyShapeStyle(FFColors.backgroundElevated))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct MovieNightToggleLabel: View {
    let icon: String
    var tint: Color = FFColors.goldPrimary
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FFTypography.labelLarge)
                    .foregroundColor(FFColors.textPrimary)
                Text(subtitle)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Mood (genres in / genres out)

struct MovieNightMoodSection: View {
    @Binding var filters: MovieNightFilters
    let genres: [Genre]
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.xl) {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                MovieNightSectionHeader(icon: "theatermasks.fill", title: "In the mood for")

                if isLoading {
                    ProgressView()
                        .tint(FFColors.goldPrimary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    genreGrid(selection: filters.genreIds, tint: FFColors.goldPrimary) { id in
                        toggleIncluded(id)
                    }
                    if filters.genreIds.isEmpty {
                        Text("Nothing picked means every genre is fair game.")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                }
            }

            if !isLoading {
                // Most groups know what they *don't* want far more clearly than
                // what they do, so this gets equal billing.
                VStack(alignment: .leading, spacing: FFSpacing.md) {
                    MovieNightSectionHeader(icon: "nosign", title: "Not tonight", tint: FFColors.ruby)

                    Text("Anything touching these is dropped, even if it matches above.")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)

                    genreGrid(selection: filters.excludedGenreIds, tint: FFColors.ruby) { id in
                        toggleExcluded(id)
                    }
                }
            }
        }
    }

    private func genreGrid(
        selection: [Int],
        tint: Color,
        onTap: @escaping (Int) -> Void
    ) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: FFSpacing.sm),
            GridItem(.flexible(), spacing: FFSpacing.sm),
            GridItem(.flexible(), spacing: FFSpacing.sm)
        ], spacing: FFSpacing.sm) {
            ForEach(genres) { genre in
                let isSelected = selection.contains(genre.id)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        onTap(genre.id)
                    }
                } label: {
                    Text(genre.name)
                        .font(FFTypography.labelSmall)
                        .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, FFSpacing.xs)
                        .padding(.vertical, FFSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background {
                            Capsule().fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(FFColors.backgroundElevated))
                        }
                        .overlay {
                            if !isSelected {
                                Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Include and exclude are mutually exclusive — picking a genre on one side
    /// clears it from the other so the query can't contradict itself.
    private func toggleIncluded(_ id: Int) {
        if filters.genreIds.contains(id) {
            filters.genreIds.removeAll { $0 == id }
        } else {
            filters.genreIds.append(id)
            filters.excludedGenreIds.removeAll { $0 == id }
        }
    }

    private func toggleExcluded(_ id: Int) {
        if filters.excludedGenreIds.contains(id) {
            filters.excludedGenreIds.removeAll { $0 == id }
        } else {
            filters.excludedGenreIds.append(id)
            filters.genreIds.removeAll { $0 == id }
        }
    }
}

// MARK: - Where To Watch

struct MovieNightWhereSection: View {
    @Binding var filters: MovieNightFilters

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            MovieNightSectionHeader(icon: "play.tv.fill", title: "Where can you watch?")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: FFSpacing.md) {
                ForEach(StreamingProvider.allCases) { provider in
                    providerCard(provider)
                }
            }

            if filters.watchProviderIds.isEmpty {
                Text("Nothing picked means we won't filter by service.")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            } else {
                Divider().background(Color.white.opacity(0.1))

                Toggle(isOn: $filters.includeRentals) {
                    MovieNightToggleLabel(
                        icon: "creditcard.fill",
                        title: "Include rentals & purchases",
                        subtitle: "Widens the deck to films you'd pay for on those services"
                    )
                }
                .tint(FFColors.goldPrimary)
            }
        }
    }

    private func providerCard(_ provider: StreamingProvider) -> some View {
        let isSelected = filters.watchProviderIds.contains(provider.id)

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if isSelected {
                    filters.watchProviderIds.removeAll { $0 == provider.id }
                } else {
                    filters.watchProviderIds.append(provider.id)
                }
            }
        } label: {
            HStack(spacing: FFSpacing.md) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? FFColors.backgroundDark : Color(hex: provider.color))
                    .frame(width: 30)

                Text(provider.name)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(FFColors.backgroundDark)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(isSelected
                        ? AnyShapeStyle(FFColors.goldGradientHorizontal)
                        : AnyShapeStyle(FFColors.backgroundElevated))
            }
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Length

struct MovieNightLengthSection: View {
    @Binding var filters: MovieNightFilters

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            MovieNightSectionHeader(icon: "clock.fill", title: "Length")

            MovieNightChipRow(
                options: [(label: "Any length", value: RuntimeLimit?.none)]
                    + RuntimeLimit.allCases.map { (label: $0.displayName, value: RuntimeLimit?.some($0)) },
                selected: filters.maxRuntime,
                onSelect: { filters.maxRuntime = $0 }
            )

            Divider().background(Color.white.opacity(0.1))

            Toggle(isOn: $filters.excludeShorts) {
                MovieNightToggleLabel(
                    icon: "timer",
                    title: "Feature length only",
                    subtitle: "Hides anything under 40 minutes"
                )
            }
            .tint(FFColors.goldPrimary)
        }
    }
}

// MARK: - Content Rating

struct MovieNightRatingSection: View {
    @Binding var filters: MovieNightFilters

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            MovieNightSectionHeader(icon: "figure.2.and.child.holdinghands", title: "Content Rating")

            MovieNightChipRow(
                options: [(label: "Any", value: ContentRating?.none)]
                    + ContentRating.allCases.map { (label: $0.displayName, value: ContentRating?.some($0)) },
                selected: filters.maxCertification,
                onSelect: { filters.maxCertification = $0 }
            )

            Text(filters.maxCertification.map { "\($0.subtitle). Films with no US rating on file are excluded." }
                 ?? "No limit on content rating.")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Era

struct MovieNightEraSection: View {
    @Binding var filters: MovieNightFilters

    private var rangeIsBackwards: Bool {
        guard let min = filters.minimumYear, let max = filters.maximumYear else { return false }
        return min > max
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            MovieNightSectionHeader(icon: "calendar", title: "Era")

            Text("From")
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textTertiary)
            MovieNightChipRow(
                options: [(label: "Any", value: Int?.none)]
                    + [2020, 2010, 2000, 1990, 1980, 1970].map { (label: "\($0)", value: Int?.some($0)) },
                selected: filters.minimumYear,
                onSelect: { filters.minimumYear = $0 }
            )

            Text("Up to")
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textTertiary)
            MovieNightChipRow(
                options: [(label: "Now", value: Int?.none)]
                    + [2019, 2009, 1999, 1989, 1979].map { (label: "\($0)", value: Int?.some($0)) },
                selected: filters.maximumYear,
                onSelect: { filters.maximumYear = $0 }
            )

            if rangeIsBackwards {
                Label("That range is backwards — nothing will match.", systemImage: "exclamationmark.triangle.fill")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.ruby)
            }
        }
    }
}

// MARK: - Familiarity

struct MovieNightAudienceSection: View {
    @Binding var filters: MovieNightFilters

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            MovieNightSectionHeader(icon: "person.3.fill", title: "Familiarity")

            ForEach(AudienceMode.allCases, id: \.self) { mode in
                let isSelected = filters.audienceMode == mode
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        filters.audienceMode = mode
                    }
                } label: {
                    HStack(spacing: FFSpacing.md) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? FFColors.goldPrimary : FFColors.textTertiary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(FFTypography.labelLarge)
                                .foregroundColor(FFColors.textPrimary)
                            Text(mode.subtitle)
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(isSelected ? FFColors.goldPrimary : FFColors.textTertiary)
                    }
                    .padding(.vertical, FFSpacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Quality

struct MovieNightQualitySection: View {
    @Binding var filters: MovieNightFilters

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                MovieNightSectionHeader(icon: "star.fill", title: "Minimum Rating")
                Spacer()
                Text(String(format: "%.1f+", filters.minVoteAverage))
                    .font(FFTypography.statSmall)
                    .foregroundColor(FFColors.goldPrimary)
            }

            Slider(value: $filters.minVoteAverage, in: 4.0...8.5, step: 0.5)
                .tint(FFColors.goldPrimary)

            HStack {
                Text("More movies")
                Spacer()
                Text("Higher quality")
            }
            .font(FFTypography.caption)
            .foregroundColor(FFColors.textTertiary)
        }
    }
}

// MARK: - Sources

struct MovieNightSourcesSection: View {
    @Binding var filters: MovieNightFilters

    var body: some View {
        VStack(spacing: FFSpacing.lg) {
            Toggle(isOn: $filters.includeForeignLanguage) {
                MovieNightToggleLabel(
                    icon: "globe",
                    title: "Include World Cinema",
                    subtitle: "Non-English films — expect subtitles"
                )
            }
            .tint(FFColors.goldPrimary)

            Divider().background(Color.white.opacity(0.1))

            Toggle(isOn: $filters.includeTrending) {
                MovieNightToggleLabel(
                    icon: "flame.fill",
                    tint: FFColors.ruby,
                    title: "Include Recent Releases",
                    subtitle: "Films from the last 18 months"
                )
            }
            .tint(FFColors.goldPrimary)

            Divider().background(Color.white.opacity(0.1))

            Toggle(isOn: $filters.includeNowPlaying) {
                MovieNightToggleLabel(
                    icon: "popcorn.fill",
                    title: "Include Films In Theaters",
                    subtitle: filters.includeNowPlaying
                        ? "You may not be able to stream these tonight"
                        : "Anything still on screens is kept out"
                )
            }
            .tint(FFColors.goldPrimary)
        }
    }
}

// MARK: - Watched

struct MovieNightWatchedSection: View {
    @Binding var filters: MovieNightFilters
    @StateObject private var seenService = SeenMoviesService.shared

    private var explanation: String {
        switch filters.excludeSeenMode {
        case .none: return "Rewatches are fair game — nothing is filtered out."
        case .mineOnly: return "Films you've logged won't appear in your deck."
        case .everyoneInParty: return "Anything anyone in the party has seen is dropped. Best for finding something new together."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                MovieNightSectionHeader(icon: "eye.slash.fill", title: "Already Watched")
                Spacer()
                Text("\(seenService.count) tracked")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }

            Picker("Exclude Watched", selection: $filters.excludeSeenMode) {
                ForEach(ExcludeSeenMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(explanation)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Deck Size

struct MovieNightDeckSizeSection: View {
    @Binding var filters: MovieNightFilters

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                MovieNightSectionHeader(icon: "square.stack.fill", title: "Deck Size")
                Spacer()
                Text("\(filters.deckSize) movies")
                    .font(FFTypography.statSmall)
                    .foregroundColor(FFColors.goldPrimary)
            }

            Slider(value: Binding(
                get: { Double(filters.deckSize) },
                set: { filters.deckSize = Int($0) }
            ), in: 10...40, step: 5)
                .tint(FFColors.goldPrimary)

            HStack {
                Text("Quick session")
                Spacer()
                Text("More options")
            }
            .font(FFTypography.caption)
            .foregroundColor(FFColors.textTertiary)
        }
    }
}

// MARK: - Match Count Preview

/// Live "how many movies match this?" readout.
///
/// Runs the exact discover query the deck builder will run, so what it reports
/// is what the host will get — the fastest way to tell whether a filter set is
/// workable before anyone is invited.
struct MovieNightMatchCountBar: View {
    let filters: MovieNightFilters

    @State private var matchCount: Int?
    @State private var isCounting = false
    @State private var countTask: Task<Void, Never>?

    enum Quality {
        case plenty, thin, tooFew

        var color: Color {
            switch self {
            case .plenty: return FFColors.success
            case .thin: return FFColors.goldPrimary
            case .tooFew: return FFColors.ruby
            }
        }

        var icon: String {
            switch self {
            case .plenty: return "checkmark.circle.fill"
            case .thin: return "exclamationmark.circle.fill"
            case .tooFew: return "xmark.circle.fill"
            }
        }
    }

    static func quality(count: Int, deckSize: Int) -> Quality {
        if count < deckSize { return .tooFew }
        if count < deckSize * 4 { return .thin }
        return .plenty
    }

    private var quality: Quality {
        guard let matchCount else { return .plenty }
        return Self.quality(count: matchCount, deckSize: filters.deckSize)
    }

    private var message: String {
        guard let matchCount else { return "" }
        switch quality {
        case .tooFew:
            return matchCount == 0
                ? "No movies match these filters — try loosening one"
                : "Only \(matchCount) movies match — your deck will be short"
        case .thin:
            return "\(matchCount) movies match — a bit tight, but workable"
        case .plenty:
            return "\(matchCount.formatted()) movies match your filters"
        }
    }

    var body: some View {
        HStack(spacing: FFSpacing.sm) {
            if isCounting {
                InlineLoader(size: 13)
                Text("Checking your filters…")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            } else if matchCount != nil {
                Image(systemName: quality.icon)
                    .font(.system(size: 12))
                    .foregroundColor(quality.color)
                Text(message)
                    .font(FFTypography.caption)
                    .foregroundColor(quality.color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .animation(FFAnimations.smooth, value: matchCount)
        .animation(FFAnimations.smooth, value: isCounting)
        .task(id: filters) {
            // Debounced so dragging a slider doesn't fire a request per frame.
            // `.task(id:)` cancels and restarts whenever the filters change.
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            isCounting = true
            let count = await TMDBService.shared.matchCount(for: filters)
            guard !Task.isCancelled else { return }
            matchCount = count
            isCounting = false
        }
    }
}
