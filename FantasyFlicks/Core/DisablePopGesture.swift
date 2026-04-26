//
//  DisablePopGesture.swift
//  FantasyFlicks
//
//  Toggle UIKit's interactive pop gesture from SwiftUI. Movie Night uses this
//  to prevent an accidental left-edge swipe from dropping the user back into
//  the lobby mid-session.
//

import SwiftUI
import UIKit

private struct DisableInteractivePopGestureModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(GestureDisabler().frame(width: 0, height: 0).allowsHitTesting(false))
    }
}

private struct GestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            // Walk up to the hosting navigation controller and disable its
            // interactive pop gesture. Re-disables on every update so a
            // parent view that re-enables it doesn't accidentally re-arm us.
            var ancestor: UIResponder? = uiViewController
            while let r = ancestor {
                if let nav = r as? UINavigationController {
                    nav.interactivePopGestureRecognizer?.isEnabled = false
                    return
                }
                ancestor = r.next
            }
        }
    }
}

extension View {
    /// Disables iOS's interactive pop (left-edge swipe-to-go-back). Apply on
    /// screens where swiping back could corrupt state — e.g. Movie Night swipe.
    func disableInteractivePopGesture() -> some View {
        modifier(DisableInteractivePopGestureModifier())
    }
}
