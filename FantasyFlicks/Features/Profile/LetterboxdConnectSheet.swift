//
//  LetterboxdConnectSheet.swift
//  FantasyFlicks
//
//  Connect a Letterboxd account so watches, ratings and reviews flow in
//  automatically, plus the one-time CSV backfill for full history.
//

import SwiftUI
import UniformTypeIdentifiers

struct LetterboxdConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var letterboxd = LetterboxdService.shared
    @StateObject private var seenService = SeenMoviesService.shared

    @State private var usernameInput = ""
    @State private var connectError: String?
    @State private var isConnecting = false
    @State private var showCSVImporter = false
    @State private var showDisconnectConfirm = false
    @State private var justSyncedCount: Int?
    @State private var csvImportResult: LetterboxdImportResult?

    @FocusState private var usernameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.lg) {
                        if letterboxd.isConnected {
                            connectedCard
                            autoSyncCard
                        } else {
                            connectCard
                        }

                        csvBackfillCard
                        howItWorksCard

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal)
                    .padding(.top, FFSpacing.md)
                    .animation(FFAnimations.smooth, value: letterboxd.isConnected)
                }
            }
            .navigationTitle("Letterboxd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .fileImporter(
                isPresented: $showCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result, !urls.isEmpty else { return }
                Task {
                    // Report the total across the whole selection — the service's
                    // own counter only remembers the last file processed.
                    var total = LetterboxdImportResult()
                    for url in urls {
                        total = total + (await seenService.importLetterboxd(from: url))
                    }
                    withAnimation(FFAnimations.smooth) { csvImportResult = total }
                    // A backfill usually moves the ratings set a lot, so the
                    // taste profile is stale the moment this finishes.
                    if total.isSuccess { await RecommendationEngine.shared.rebuild() }
                }
            }
            .alert("Disconnect Letterboxd?", isPresented: $showDisconnectConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    letterboxd.disconnect()
                    usernameInput = ""
                }
            } message: {
                Text("New activity will stop syncing. Everything already imported stays in your diary.")
            }
        }
    }

    // MARK: - Connect

    private var connectCard: some View {
        GlassCard(goldTint: true) {
            VStack(alignment: .leading, spacing: FFSpacing.lg) {
                HStack(spacing: FFSpacing.md) {
                    iconBadge("link", tint: FFColors.goldPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect your account")
                            .font(FFTypography.titleSmall)
                            .foregroundColor(FFColors.textPrimary)
                        Text("Everything you log on Letterboxd shows up here")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: FFSpacing.sm) {
                    Text("letterboxd.com/")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textTertiary)
                        .lineLimit(1)
                        .layoutPriority(1)

                    TextField("username", text: $usernameInput)
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($usernameFieldFocused)
                        .onSubmit { Task { await connect() } }
                }
                .padding(FFSpacing.md)
                .background(FFColors.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(connectError == nil ? Color.white.opacity(0.08) : FFColors.ruby.opacity(0.6),
                                lineWidth: connectError == nil ? 0.5 : 1)
                }

                if let connectError {
                    Label(connectError, systemImage: "exclamationmark.triangle.fill")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.ruby)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GoldButton(
                    title: isConnecting ? "Connecting…" : "Connect",
                    icon: "arrow.triangle.2.circlepath",
                    style: .primary,
                    size: .medium,
                    isLoading: isConnecting,
                    fullWidth: true
                ) {
                    Task { await connect() }
                }
                .disabled(isConnecting || usernameInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Text("Your Letterboxd profile needs to be public. We only read your activity — nothing is ever posted.")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Connected

    private var connectedCard: some View {
        GlassCard(goldTint: true) {
            VStack(alignment: .leading, spacing: FFSpacing.lg) {
                HStack(spacing: FFSpacing.md) {
                    iconBadge("checkmark.circle.fill", tint: FFColors.success)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(letterboxd.username ?? "")
                            .font(FFTypography.titleSmall)
                            .foregroundColor(FFColors.textPrimary)
                            .lineLimit(1)
                        Text(lastSyncedDescription)
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }

                    Spacer(minLength: 0)

                    if let url = letterboxd.profileURL {
                        Button {
                            openURL(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 18))
                                .foregroundColor(FFColors.goldPrimary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Letterboxd profile")
                    }
                }

                if let count = justSyncedCount {
                    Label(
                        count == 0
                            ? "Already up to date"
                            : "Synced \(count) \(count == 1 ? "entry" : "entries")",
                        systemImage: count == 0 ? "checkmark.circle" : "sparkles"
                    )
                    .font(FFTypography.labelMedium)
                    .foregroundColor(count == 0 ? FFColors.textSecondary : FFColors.success)
                    .transition(.opacity)
                }

                if let error = letterboxd.syncError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.ruby)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: FFSpacing.md) {
                    GoldButton(
                        title: letterboxd.isSyncing ? "Syncing…" : "Sync Now",
                        icon: "arrow.clockwise",
                        style: .primary,
                        size: .medium,
                        isLoading: letterboxd.isSyncing,
                        fullWidth: true
                    ) {
                        Task {
                            let count = await letterboxd.syncNow()
                            withAnimation(FFAnimations.smooth) { justSyncedCount = count }
                        }
                    }
                    .disabled(letterboxd.isSyncing)

                    Button {
                        showDisconnectConfirm = true
                    } label: {
                        Text("Disconnect")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.ruby)
                            .padding(.horizontal, FFSpacing.md)
                            .frame(height: 48)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var autoSyncCard: some View {
        GlassCard {
            Toggle(isOn: $letterboxd.autoSyncEnabled) {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(FFColors.goldPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Sync")
                            .font(FFTypography.labelLarge)
                            .foregroundColor(FFColors.textPrimary)
                        Text("Check for new Letterboxd activity when you open the app")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tint(FFColors.goldPrimary)
        }
    }

    // MARK: - CSV Backfill

    private var csvBackfillCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack(spacing: FFSpacing.md) {
                    iconBadge("square.and.arrow.down.fill", tint: FFColors.goldPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Full History")
                            .font(FFTypography.titleSmall)
                            .foregroundColor(FFColors.textPrimary)
                        Text("watched · diary · reviews · watchlist · favorites")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                Text("The live connection covers your recent activity. To bring across everything you've ever logged, export your data from Letterboxd and import the CSVs here — you can pick several at once.")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GoldButton(
                    title: seenService.isImporting ? "Importing…" : "Choose CSV Files",
                    icon: "doc.fill",
                    style: .secondary,
                    size: .medium,
                    isLoading: seenService.isImporting,
                    fullWidth: true
                ) {
                    showCSVImporter = true
                }
                .disabled(seenService.isImporting)

                if let csvImportResult {
                    VStack(alignment: .leading, spacing: FFSpacing.sm) {
                        Label(
                            csvImportResult.summary,
                            systemImage: csvImportResult.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(FFTypography.labelMedium)
                        .foregroundColor(csvImportResult.isSuccess ? FFColors.success : FFColors.ruby)
                        .fixedSize(horizontal: false, vertical: true)

                        // Name the films we skipped so a bad match is fixable by
                        // hand instead of silently missing from Movie Night.
                        // Mostly TV — Letterboxd lets you log limited series,
                        // and we only ever search TMDB's movie catalogue.
                        let skipped = csvImportResult.distinctUnmatchedTitles
                        if !skipped.isEmpty {
                            Text(skipped.prefix(8).joined(separator: ", ")
                                 + (skipped.count > 8 ? " and \(skipped.count - 8) more" : ""))
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Button {
                    if let url = URL(string: "https://letterboxd.com/settings/data/") {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Export your data on Letterboxd")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.goldPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - How it works

    private var howItWorksCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("What syncs")
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)

                ForEach(syncFacts, id: \.text) { fact in
                    HStack(alignment: .top, spacing: FFSpacing.md) {
                        Image(systemName: fact.icon)
                            .font(.system(size: 14))
                            .foregroundColor(FFColors.goldPrimary)
                            .frame(width: 20)
                        Text(fact.text)
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var syncFacts: [(icon: String, text: String)] {
        [
            ("eye.fill", "Films you log are marked as watched, so they stop showing up in Movie Night."),
            ("star.fill", "Your star ratings come across at half-star resolution."),
            ("text.quote", "Reviews land in your diary — edit one on Letterboxd and the next sync updates it here."),
            ("wand.and.stars", "Everything you rate highly feeds your recommendations.")
        ]
    }

    // MARK: - Helpers

    private func iconBadge(_ systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(tint.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundColor(tint)
        }
    }

    private var lastSyncedDescription: String {
        guard let date = letterboxd.lastSyncedAt else { return "Not synced yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func connect() async {
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isConnecting else { return }

        usernameFieldFocused = false
        isConnecting = true
        connectError = nil

        do {
            let count = try await letterboxd.connect(username: trimmed)
            withAnimation(FFAnimations.smooth) { justSyncedCount = count }
        } catch {
            connectError = error.localizedDescription
        }

        isConnecting = false
    }
}
