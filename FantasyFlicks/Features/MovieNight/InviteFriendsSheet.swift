//
//  InviteFriendsSheet.swift
//  FantasyFlicks
//
//  Pick friends to add to a Movie Night. Selected friends are added directly
//  to the session's participant list via Firestore — no share link, no code
//  needed. The session will appear automatically in each invitee's
//  "Your Sessions" list on their next sync.
//

import SwiftUI

struct InviteFriendsSheet: View {
    let sessionId: String
    let inviteCode: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsService = FriendsService.shared
    @State private var selectedFriendIds: Set<String> = []
    @State private var isInviting = false
    @State private var justInvitedNames: [String] = []
    @State private var errorMessage: String?
    @State private var showShareSheet = false

    private var selectedFriends: [FFUser] {
        friendsService.friends.filter { selectedFriendIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if friendsService.friends.isEmpty && !friendsService.isLoading {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: FFSpacing.sm) {
                            header
                            ForEach(friendsService.friends) { friend in
                                friendRow(friend: friend)
                            }
                        }
                        .padding(.top, FFSpacing.md)
                        .padding(.bottom, 140)
                    }
                }

                if !selectedFriendIds.isEmpty {
                    VStack {
                        Spacer()
                        bottomBar
                    }
                }

                if !justInvitedNames.isEmpty {
                    VStack {
                        Spacer()
                        successToast
                            .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
            }
            .task {
                await friendsService.refreshFriendList()
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: ["Join my Movie Night on FantasyFlicks. Code: \(inviteCode)"])
            }
            .alert("Invite failed", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: FFSpacing.xs) {
            Text("They'll get added to this Movie Night automatically.")
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: FFSpacing.sm) {
                Image(systemName: "number")
                    .font(.system(size: 12))
                    .foregroundColor(FFColors.goldPrimary)
                Text("Invite code:")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                Text(inviteCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(FFColors.goldLight)
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.goldPrimary.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(FFColors.goldPrimary.opacity(0.2), lineWidth: 1)
                }
        }
        .padding(.horizontal)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: FFSpacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(FFColors.textTertiary)
            Text("No friends yet")
                .font(FFTypography.titleMedium)
                .foregroundColor(FFColors.textSecondary)
            Text("Add friends in the Friends tab to invite them directly.")
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.center)

            GoldButton(title: "Share Code Instead", icon: "square.and.arrow.up", style: .secondary, size: .medium) {
                showShareSheet = true
            }
            .padding(.top, FFSpacing.md)
        }
        .padding()
    }

    // MARK: - Row

    private func friendRow(friend: FFUser) -> some View {
        let selected = selectedFriendIds.contains(friend.id)

        return Button {
            if selected {
                selectedFriendIds.remove(friend.id)
            } else {
                selectedFriendIds.insert(friend.id)
            }
        } label: {
            HStack(spacing: FFSpacing.md) {
                AvatarView(user: friend, size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)
                    Text("@\(friend.username)")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.5))
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(selected ? FFColors.goldPrimary.opacity(0.1) : FFColors.backgroundElevated.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .stroke(selected ? FFColors.goldPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))

            GoldButton(
                title: isInviting
                    ? "Adding…"
                    : "Add \(selectedFriendIds.count) friend\(selectedFriendIds.count == 1 ? "" : "s")",
                icon: "person.badge.plus",
                style: .primary,
                size: .large,
                isLoading: isInviting,
                fullWidth: true
            ) {
                Task { await invite() }
            }
            .disabled(isInviting)
            .padding(FFSpacing.md)
        }
        .background(FFColors.backgroundDark.opacity(0.95))
    }

    // MARK: - Success toast

    private var successToast: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(FFColors.success)
            Text("Added \(justInvitedNames.prefix(3).joined(separator: ", "))\(justInvitedNames.count > 3 ? ", +\(justInvitedNames.count - 3) more" : "")")
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textPrimary)
                .lineLimit(2)
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.success.opacity(0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(FFColors.success.opacity(0.4), lineWidth: 1)
                }
        }
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func invite() async {
        let toInvite = selectedFriends
        guard !toInvite.isEmpty else { return }

        isInviting = true
        defer { isInviting = false }

        do {
            try await MovieNightService.shared.inviteFriends(sessionId: sessionId, friends: toInvite)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                justInvitedNames = toInvite.map { $0.displayName }
                selectedFriendIds.removeAll()
            }
            // Auto-dismiss the toast and then the sheet
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
