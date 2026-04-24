//
//  AchievementDetailSheet.swift
//  FantasyFlicks
//
//  Shown when the user taps a badge in the Achievements section. Displays
//  the badge's name, description, unlock criteria, and current progress
//  (or unlock date if already earned).
//

import SwiftUI

struct AchievementDetailSheet: View {
    let progress: AchievementProgress
    @Environment(\.dismiss) private var dismiss

    private var def: AchievementDefinition { progress.definition }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: FFSpacing.xl) {
                    badge

                    VStack(spacing: FFSpacing.sm) {
                        Text(def.name)
                            .font(FFTypography.displaySmall)
                            .foregroundColor(FFColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(def.description)
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, FFSpacing.xl)
                    }

                    if progress.isUnlocked {
                        unlockedCard
                    } else {
                        progressCard
                    }

                    Spacer()
                }
                .padding(.top, FFSpacing.xxl)
                .padding(.horizontal)
            }
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }

    // MARK: - Badge

    private var badge: some View {
        ZStack {
            Circle()
                .fill(progress.isUnlocked ? AnyShapeStyle(FFColors.goldGradient) : AnyShapeStyle(FFColors.backgroundElevated))
                .frame(width: 120, height: 120)

            if progress.isUnlocked {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.3))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
            }

            Image(systemName: def.icon)
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(progress.isUnlocked ? FFColors.backgroundDark : FFColors.textTertiary)

            if !progress.isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(FFColors.textTertiary)
                    .padding(8)
                    .background(Circle().fill(FFColors.backgroundDark))
                    .offset(x: 38, y: 38)
            }
        }
    }

    // MARK: - Unlocked card

    private var unlockedCard: some View {
        VStack(spacing: FFSpacing.sm) {
            HStack(spacing: FFSpacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(FFColors.success)
                Text("Unlocked")
                    .font(FFTypography.labelLarge)
                    .foregroundColor(FFColors.textPrimary)
            }

            if let date = progress.unlockedAt {
                Text(date, style: .date)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FFSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.success.opacity(0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(FFColors.success.opacity(0.4), lineWidth: 1)
                }
        }
    }

    // MARK: - Progress card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Progress")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textTertiary)
                Spacer()
                if let goal = def.goal {
                    Text("\(progress.current) / \(goal)")
                        .font(FFTypography.labelLarge)
                        .foregroundColor(FFColors.goldPrimary)
                        .monospacedDigit()
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FFColors.backgroundElevated2)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(FFColors.goldGradient)
                        .frame(width: max(8, geo.size.width * progress.progressFraction), height: 8)
                }
            }
            .frame(height: 8)

            Text("Requires: \(def.goalText)")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
        }
        .padding(FFSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}
