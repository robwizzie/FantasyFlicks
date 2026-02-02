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
            Group {
                if !authService.isAuthenticated {
                    OnboardingView()
                } else if !authService.hasCompletedProfileSetup {
                    ProfileSetupView()
                } else {
                    MainTabView()
                }
            }
            .ffTheme()
        }
    }
}
