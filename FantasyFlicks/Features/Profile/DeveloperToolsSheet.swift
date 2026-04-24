//
//  DeveloperToolsSheet.swift
//  FantasyFlicks
//
//  Gated developer utilities for the app author. Only visible to the
//  whitelisted email — see `DeveloperToolsGate.isAvailable`.
//

import SwiftUI
import FirebaseFirestore

/// Who can see the developer tools. Change the email here if the author account changes.
enum DeveloperToolsGate {
    /// Allowed email addresses that can see the developer tools UI.
    static let allowedEmails: Set<String> = [
        "robertwiscount@gmail.com",
        "rob.wiscount@gmail.com" // alt spelling just in case
    ]

    /// Secondary manual unlock — flipped when the user long-presses the version
    /// footer in Settings. Scoped to this app run so it resets next launch.
    static var manuallyUnlocked: Bool = false

    static var isAvailable: Bool {
        if manuallyUnlocked { return true }
        guard let email = AuthenticationService.shared.currentUser?.email else { return false }
        return allowedEmails.contains(email.lowercased())
    }
}

struct DeveloperToolsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @StateObject private var achievements = AchievementService.shared

    @State private var customUID: String = ""
    @State private var confirmWipeSelf = false
    @State private var confirmWipeOther = false
    @State private var statusMessage: String?
    @State private var isWorking = false

    private var myUID: String { AuthenticationService.shared.currentUser?.id ?? "—" }
    private var myEmail: String { AuthenticationService.shared.currentUser?.email ?? "—" }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: FFSpacing.lg) {
                        header

                        identityCard
                        localSnapshotCard
                        wipeMyDataCard
                        wipeOtherUserCard
                        resetAchievementsCard

                        if let msg = statusMessage {
                            HStack(spacing: FFSpacing.sm) {
                                Image(systemName: "info.circle")
                                Text(msg).font(FFTypography.bodySmall)
                            }
                            .foregroundColor(FFColors.goldPrimary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                    .fill(FFColors.goldPrimary.opacity(0.12))
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.top, FFSpacing.md)
                }
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .alert("Wipe your data?", isPresented: $confirmWipeSelf) {
                Button("Cancel", role: .cancel) {}
                Button("Wipe", role: .destructive) {
                    Task { await wipeMyData() }
                }
            } message: {
                Text("Removes all seen movies, watchlist, ratings, diary entries, and metadata cache for your account.")
            }
            .alert("Wipe that account's data?", isPresented: $confirmWipeOther) {
                Button("Cancel", role: .cancel) {}
                Button("Wipe", role: .destructive) {
                    Task { await wipeOtherUser(uid: customUID) }
                }
            } message: {
                Text("Wipes the media fields on Firestore for user \(customUID). Does not touch their local device.")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Internal Tools")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
            Text("Only visible to the app author. Use with care — actions here are destructive and immediate.")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
        }
        .padding(.horizontal)
    }

    private var identityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                labelValue("Email", myEmail)
                Divider().background(Color.white.opacity(0.1))
                HStack(alignment: .top, spacing: FFSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Firebase UID")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.textTertiary)
                        Text(myUID)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(FFColors.textPrimary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = myUID
                        flashStatus("UID copied")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var localSnapshotCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                Text("Local Snapshot").font(FFTypography.labelMedium).foregroundColor(FFColors.textTertiary)
                labelValue("Seen",      "\(seenService.seenTmdbIds.count)")
                labelValue("Watchlist", "\(seenService.watchlist.count)")
                labelValue("Ratings",   "\(seenService.ratings.count)")
                labelValue("Diary",     "\(seenService.diary.count)")
                labelValue("Movie cache", "\(seenService.movieCache.count)")
                labelValue("Achievements unlocked", "\(achievements.unlockedIds.count)")
                if let count = seenService.lastImportCount {
                    labelValue("Last import matched", "\(count)")
                }
            }
        }
        .padding(.horizontal)
    }

    private var wipeMyDataCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                Text("Wipe My Data").font(FFTypography.labelMedium).foregroundColor(FFColors.textPrimary)
                Text("Clears local UserDefaults + overwrites the media fields on your Firestore user doc with empty arrays. Achievement unlocks are reset too.")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                Button(role: .destructive) {
                    confirmWipeSelf = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Wipe My Data").fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FFColors.ruby)
                    .clipShape(Capsule())
                }
                .disabled(isWorking)
            }
        }
        .padding(.horizontal)
    }

    private var wipeOtherUserCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                Text("Wipe User by UID").font(FFTypography.labelMedium).foregroundColor(FFColors.textPrimary)
                Text("Enter any Firebase UID to wipe that account's media fields on Firestore. Only the server-side data is cleared — their device's local cache persists until they log in again.")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)

                TextField("Firebase UID", text: $customUID)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(FFColors.textPrimary)
                    .padding(FFSpacing.sm)
                    .background(FFColors.backgroundElevated2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button(role: .destructive) {
                    confirmWipeOther = true
                } label: {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Wipe UID").fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FFColors.ruby.opacity(customUID.count >= 8 ? 1 : 0.5))
                    .clipShape(Capsule())
                }
                .disabled(isWorking || customUID.count < 8)
            }
        }
        .padding(.horizontal)
    }

    private var resetAchievementsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                Text("Reset Achievements").font(FFTypography.labelMedium).foregroundColor(FFColors.textPrimary)
                Text("Clears locally tracked unlocks so achievements re-fire their celebration next time they're evaluated.")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                Button {
                    UserDefaults.standard.removeObject(forKey: "ff_achievements_unlocked")
                    UserDefaults.standard.removeObject(forKey: "ff_achievements_unlocked_at")
                    flashStatus("Achievements reset. Restart the app to see them reset fully.")
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Local Unlocks")
                    }
                    .foregroundColor(FFColors.goldPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FFColors.goldPrimary.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func wipeMyData() async {
        guard let uid = AuthenticationService.shared.currentUser?.id else { return }
        isWorking = true
        defer { isWorking = false }

        // Clear local caches
        seenService.seenTmdbIds = []
        seenService.watchlist = []
        seenService.ratings = [:]
        seenService.diary = []
        seenService.movieCache = [:]
        UserDefaults.standard.removeObject(forKey: "ff_seen_movie_tmdb_ids")
        UserDefaults.standard.removeObject(forKey: "ff_movie_ratings")
        UserDefaults.standard.removeObject(forKey: "ff_movie_diary")
        UserDefaults.standard.removeObject(forKey: "ff_movie_watchlist")
        UserDefaults.standard.removeObject(forKey: "ff_movie_cache")
        UserDefaults.standard.removeObject(forKey: "ff_achievements_unlocked")
        UserDefaults.standard.removeObject(forKey: "ff_achievements_unlocked_at")

        // Clear Firestore
        await wipeFirestoreMedia(uid: uid)
        flashStatus("Wiped your data.")
    }

    private func wipeOtherUser(uid: String) async {
        guard !uid.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        await wipeFirestoreMedia(uid: uid)
        flashStatus("Wiped Firestore media for \(uid).")
    }

    private func wipeFirestoreMedia(uid: String) async {
        let db = Firestore.firestore()
        let empty: [String: Any] = [
            "mediaSeenIds": [],
            "mediaWatchlistIds": [],
            "mediaRatings": [String: Double](),
            "mediaDiaryJSON": "[]",
            "mediaCacheJSON": "[]",
            "mediaUpdatedAt": Timestamp(date: Date())
        ]
        do {
            try await db.collection("users").document(uid).updateData(empty)
        } catch {
            flashStatus("Firestore update failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(FFTypography.labelSmall).foregroundColor(FFColors.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(FFColors.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func flashStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(4))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}
