//
//  NotificationSettingsSheet.swift
//  FantasyFlicks
//
//  Manages notification preferences and iOS authorization.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: ProfileViewModel
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var notificationsEnabled = true
    @State private var reminderMinutes = 30
    @State private var isSaving = false

    private let reminderOptions = [5, 15, 30, 60, 120]

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.xl) {
                        // Permission status banner
                        permissionBanner

                        // Main toggle
                        mainToggleCard

                        // Reminder picker
                        if notificationsEnabled && notificationManager.isAuthorized {
                            reminderCard
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Test notification
                        if notificationManager.isAuthorized {
                            testNotificationButton
                        }

                        // Link out to system settings
                        systemSettingsLink

                        Spacer(minLength: 60)
                    }
                    .padding(.top, FFSpacing.md)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: notificationsEnabled)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: notificationManager.authorizationStatus)
                }
            }
            .navigationTitle("Notifications")
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
            .task {
                if let user = viewModel.user {
                    notificationsEnabled = user.notificationsEnabled
                    reminderMinutes = user.draftReminderMinutes
                }
                await notificationManager.refreshStatus()
            }
            .onChange(of: scenePhase) { _, newValue in
                // Refresh permission status when returning from Settings
                if newValue == .active {
                    Task { await notificationManager.refreshStatus() }
                }
            }
        }
    }

    // MARK: - Permission Banner

    @ViewBuilder
    private var permissionBanner: some View {
        switch notificationManager.authorizationStatus {
        case .denied:
            banner(
                color: FFColors.ruby,
                icon: "bell.slash.fill",
                title: "Notifications are off in iOS Settings",
                subtitle: "Enable them in Settings to get match alerts and reminders."
            ) {
                notificationManager.openSystemSettings()
            }
        case .notDetermined:
            banner(
                color: FFColors.goldPrimary,
                icon: "bell.badge",
                title: "Allow notifications",
                subtitle: "Get notified about Movie Night matches, invites, and reminders."
            ) {
                Task {
                    _ = await notificationManager.requestAuthorization()
                }
            }
        default:
            EmptyView()
        }
    }

    private func banner(color: Color, icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: FFSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FFTypography.labelLarge)
                        .foregroundColor(FFColors.textPrimary)
                    Text(subtitle)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FFColors.textTertiary)
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(color.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(color.opacity(0.35), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Main Toggle

    private var mainToggleCard: some View {
        GlassCard {
            Toggle(isOn: $notificationsEnabled) {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FFColors.goldPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(FFTypography.labelLarge)
                            .foregroundColor(FFColors.textPrimary)

                        Text(toggleSubtitle)
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                }
            }
            .tint(FFColors.goldPrimary)
            .disabled(notificationManager.isDenied)
            .onChange(of: notificationsEnabled) { _, newValue in
                if newValue && !notificationManager.isAuthorized {
                    Task {
                        let granted = await notificationManager.requestAuthorization()
                        if !granted { notificationsEnabled = false }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var toggleSubtitle: String {
        if notificationManager.isDenied {
            return "Blocked in iOS Settings — enable above"
        }
        return "Matches, invites, reminders"
    }

    // MARK: - Reminder Card

    private var reminderCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FFColors.goldPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remind me")
                            .font(FFTypography.labelLarge)
                            .foregroundColor(FFColors.textPrimary)
                        Text("Before scheduled events")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                }

                Picker("Reminder", selection: $reminderMinutes) {
                    ForEach(reminderOptions, id: \.self) { minutes in
                        Text(label(for: minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Test Notification

    private var testNotificationButton: some View {
        Button {
            Task {
                await notificationManager.schedule(
                    id: "test-notification",
                    title: "You're all set!",
                    body: "Notifications are working. See you at Movie Night. 🍿",
                    afterMinutes: 0
                )
            }
        } label: {
            HStack(spacing: FFSpacing.sm) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(FFColors.goldPrimary)
                Text("Send Test Notification")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(FFColors.backgroundElevated.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - System Settings Link

    private var systemSettingsLink: some View {
        Button {
            notificationManager.openSystemSettings()
        } label: {
            HStack(spacing: FFSpacing.sm) {
                Image(systemName: "gear")
                    .foregroundColor(FFColors.goldPrimary)
                Text("iOS Notification Settings")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(FFColors.textTertiary)
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(FFColors.backgroundElevated.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func label(for minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // If turning on and we don't have permission yet, request it.
        if notificationsEnabled && !notificationManager.isAuthorized {
            let granted = await notificationManager.requestAuthorization()
            if !granted {
                notificationsEnabled = false
            }
        }

        _ = await viewModel.updateNotificationSettings(
            enabled: notificationsEnabled,
            reminderMinutes: reminderMinutes
        )

        // If the user disabled notifications app-side, clear any pending scheduled items.
        if !notificationsEnabled {
            notificationManager.cancelAll()
        }

        dismiss()
    }
}
