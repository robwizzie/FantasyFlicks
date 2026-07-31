//
//  LetterboxdConnectCard.swift
//  FantasyFlicks
//
//  Reusable prompt to link a Letterboxd account.
//
//  Connecting is the single highest-value thing a new user can do — it fills in
//  their watch history, ratings and reviews in one step, which in turn switches
//  on recommendations and stops Movie Night suggesting films they've seen. So
//  it shouldn't live only in Profile settings; this card is dropped wherever a
//  user first hits an empty list.
//

import SwiftUI

struct LetterboxdConnectCard: View {

    enum Style {
        /// Full card with explanation — for empty states and onboarding.
        case prominent
        /// Single row — for lists that already have content.
        case compact
    }

    var style: Style = .prominent
    var headline: String?
    var message: String?

    @StateObject private var letterboxd = LetterboxdService.shared
    @State private var showConnectSheet = false

    /// Hidden once an account is linked — a connected user doesn't need the pitch.
    private var shouldShow: Bool { !letterboxd.isConnected }

    var body: some View {
        if shouldShow {
            Button {
                showConnectSheet = true
            } label: {
                switch style {
                case .prominent: prominentCard
                case .compact: compactRow
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showConnectSheet) {
                LetterboxdConnectSheet()
            }
        }
    }

    // MARK: - Prominent

    private var prominentCard: some View {
        GlassCard(goldTint: true) {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack(spacing: FFSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .fill(FFColors.goldPrimary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20))
                            .foregroundColor(FFColors.goldPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline ?? "Already on Letterboxd?")
                            .font(FFTypography.titleSmall)
                            .foregroundColor(FFColors.textPrimary)
                        Text("Connect in seconds")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }

                    Spacer(minLength: 0)
                }

                Text(message ?? "Bring across everything you've watched, rated and reviewed — then keep it in sync automatically.")
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: FFSpacing.sm) {
                    Text("Connect Letterboxd")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.backgroundDark)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FFColors.backgroundDark)
                }
                .padding(.horizontal, FFSpacing.lg)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(FFColors.goldGradientHorizontal)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Compact

    private var compactRow: some View {
        HStack(spacing: FFSpacing.md) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 18))
                .foregroundColor(FFColors.goldPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline ?? "Connect Letterboxd")
                    .font(FFTypography.labelLarge)
                    .foregroundColor(FFColors.textPrimary)
                Text(message ?? "Import your watches and ratings")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(FFColors.goldPrimary)
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                }
        }
    }
}
