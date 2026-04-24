//
//  UserRow.swift
//  FantasyFlicks
//
//  Compact user row used in search results and the friend list.
//

import SwiftUI

struct UserRow: View {
    enum TrailingStyle {
        case addable           // "Add" pill — tap to add as friend
        case alreadyFriend     // "Friends" pill with checkmark
        case navigate          // chevron only
    }

    let user: FFUser
    var style: TrailingStyle = .navigate
    var onAdd: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                Text("@\(user.username)")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            trailing
        }
        .padding(.horizontal, FFSpacing.md)
        .padding(.vertical, FFSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    private var avatar: some View {
        AvatarView(user: user, size: 44)
    }

    @ViewBuilder
    private var trailing: some View {
        switch style {
        case .addable:
            Button {
                onAdd?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(FFColors.backgroundDark)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, 6)
                .background(FFColors.goldGradient)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

        case .alreadyFriend:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("Friends")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(FFColors.success)
            .padding(.horizontal, FFSpacing.md)
            .padding(.vertical, 6)
            .background(FFColors.success.opacity(0.15))
            .clipShape(Capsule())

        case .navigate:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(FFColors.textTertiary)
        }
    }
}
