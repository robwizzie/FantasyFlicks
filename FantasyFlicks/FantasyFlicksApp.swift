//
//  FantasyFlicksApp.swift
//  FantasyFlicks
//
//  Created by Robert Wiscount on 1/31/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

// MARK: - App Delegate for Firebase & URL handling

class AppDelegate: NSObject, UIApplicationDelegate, UISceneDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        // Initialize NotificationManager early so UNUserNotificationCenter.delegate is set
        // before any notifications could be delivered (e.g., tap from a prior run).
        Task { @MainActor in
            _ = NotificationManager.shared
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = AppDelegate.self
        return config
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            GIDSignIn.sharedInstance.handle(context.url)
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        for context in connectionOptions.urlContexts {
            GIDSignIn.sharedInstance.handle(context.url)
        }
    }
}

// MARK: - Main App

@main
struct FantasyFlicksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthenticationService.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authService.isInitializing {
                        SplashScreen()
                    } else if !authService.isAuthenticated {
                        OnboardingView()
                    } else if !authService.hasCompletedProfileSetup {
                        ProfileSetupView()
                    } else {
                        MainTabView()
                    }
                }

                // Global overlay that fires whenever any achievement unlocks.
                // Hit testing is managed inside the overlay itself so it stays reactive.
                AchievementUnlockOverlay()
            }
            .ffTheme()
            .animation(.easeInOut(duration: 0.35), value: authService.isInitializing)
            .animation(.easeInOut(duration: 0.25), value: authService.isAuthenticated)
        }
    }
}
