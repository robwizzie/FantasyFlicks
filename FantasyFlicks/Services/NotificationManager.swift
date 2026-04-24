//
//  NotificationManager.swift
//  FantasyFlicks
//
//  Wraps UNUserNotificationCenter: permission requests, permission status,
//  and scheduling/cancelling local notifications.
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Published

    /// Current iOS notification permission status. Refreshed on app foreground and after requests.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        Task { await refreshStatus() }
    }

    // MARK: - Permission

    /// Refresh the current authorization status from iOS (e.g., after returning from Settings).
    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Request authorization. Returns true if granted.
    /// If status is `.denied`, returns false — caller should route user to iOS Settings.
    @discardableResult
    func requestAuthorization() async -> Bool {
        // Refresh first so we have accurate state before prompting
        await refreshStatus()

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshStatus()
                return granted
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    var isDenied: Bool {
        authorizationStatus == .denied
    }

    // MARK: - Scheduling

    /// Schedule a local notification.
    /// - Parameters:
    ///   - id: unique identifier (replaces any existing pending notification with the same id)
    ///   - title: notification title
    ///   - body: notification body
    ///   - date: when to fire. If in the past, fires immediately.
    ///   - userInfo: optional payload for deep-linking when the user taps
    func schedule(id: String, title: String, body: String, date: Date, userInfo: [String: Any] = [:]) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let trigger: UNNotificationTrigger
        let interval = max(1, date.timeIntervalSinceNow)
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        // Overwrite any existing request with the same id
        center.removePendingNotificationRequests(withIdentifiers: [id])

        do {
            try await center.add(request)
        } catch {
            // Swallow — local notifications aren't critical
        }
    }

    /// Schedule a notification to fire after a delay in minutes.
    func schedule(id: String, title: String, body: String, afterMinutes minutes: Int, userInfo: [String: Any] = [:]) async {
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        await schedule(id: id, title: title, body: body, date: fireDate, userInfo: userInfo)
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - System Settings Deep Link

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Show banner + sound even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Hook for deep-linking when a notification is tapped.
    /// Inspects userInfo["tab"] to navigate to a tab on open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let tabRaw = userInfo["tab"] as? String
        let sessionId = userInfo["sessionId"] as? String

        Task { @MainActor in
            if let tabRaw, let tab = Tab(rawValue: tabRaw) {
                NavigationCoordinator.shared.navigateTo(tab)
            }
            if let sessionId {
                NavigationCoordinator.shared.resumeMovieNightSession(sessionId)
            }
        }

        completionHandler()
    }
}
