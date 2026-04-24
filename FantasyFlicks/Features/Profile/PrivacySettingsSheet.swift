//
//  PrivacySettingsSheet.swift
//  FantasyFlicks
//
//  Toggle which of the user's movie lists are visible to friends vs. private.
//

import SwiftUI

struct PrivacySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var diaryPrivate = false
    @State private var watchedPrivate = false
    @State private var watchlistPrivate = false
    @State private var ratingsPrivate = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.xl) {
                        intro

                        GlassCard {
                            VStack(spacing: FFSpacing.lg) {
                                privacyToggle(
                                    icon: "book.closed.fill",
                                    title: "Diary",
                                    subtitle: "Your log of watched movies with dates, ratings, and reviews.",
                                    isPrivate: $diaryPrivate
                                )

                                Divider().background(Color.white.opacity(0.1))

                                privacyToggle(
                                    icon: "eye.fill",
                                    title: "Watched",
                                    subtitle: "The list of movies you've marked as watched.",
                                    isPrivate: $watchedPrivate
                                )

                                Divider().background(Color.white.opacity(0.1))

                                privacyToggle(
                                    icon: "bookmark.fill",
                                    title: "Watchlist",
                                    subtitle: "Movies you want to watch later.",
                                    isPrivate: $watchlistPrivate
                                )

                                Divider().background(Color.white.opacity(0.1))

                                privacyToggle(
                                    icon: "star.fill",
                                    title: "Ratings",
                                    subtitle: "Your 1–5 star ratings for movies.",
                                    isPrivate: $ratingsPrivate
                                )
                            }
                        }
                        .padding(.horizontal)

                        footnote

                        Spacer(minLength: 60)
                    }
                    .padding(.top, FFSpacing.md)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .foregroundColor(FFColors.goldPrimary)
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                if let user = viewModel.user {
                    diaryPrivate = user.diaryPrivate
                    watchedPrivate = user.watchedPrivate
                    watchlistPrivate = user.watchlistPrivate
                    ratingsPrivate = user.ratingsPrivate
                }
            }
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            Text("Who can see what")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)

            Text("Your friends can see your lists by default. Flip a switch on to hide a list from everyone except you.")
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: - Toggle row

    private func privacyToggle(icon: String, title: String, subtitle: String, isPrivate: Binding<Bool>) -> some View {
        HStack(spacing: FFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(FFColors.goldPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(FFTypography.labelLarge)
                        .foregroundColor(FFColors.textPrimary)

                    if isPrivate.wrappedValue {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(FFColors.textTertiary)
                    }
                }

                Text(subtitle)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .lineLimit(3)
            }

            Spacer()

            Toggle("", isOn: isPrivate)
                .labelsHidden()
                .tint(FFColors.ruby)
        }
    }

    // MARK: - Footnote

    private var footnote: some View {
        HStack(alignment: .top, spacing: FFSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundColor(FFColors.textTertiary)
                .font(.system(size: 14))

            Text("Private lists are only ever visible to you. Even friends won't be able to see them.")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, FFSpacing.xl)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        _ = await viewModel.updatePrivacySettings(
            diaryPrivate: diaryPrivate,
            watchedPrivate: watchedPrivate,
            watchlistPrivate: watchlistPrivate,
            ratingsPrivate: ratingsPrivate
        )
        await viewModel.refreshProfile()
        dismiss()
    }
}
