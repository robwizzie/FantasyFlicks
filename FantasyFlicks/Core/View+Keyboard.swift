//
//  View+Keyboard.swift
//  FantasyFlicks
//
//  Reusable keyboard dismissal for text fields across the app.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Dismisses the keyboard by resigning the first responder.
/// Call from toolbar "Done" buttons, submit handlers, or tap gestures.
func dismissKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
    #endif
}

extension View {

    /// Dismisses the keyboard. Use from tap gestures or when coordinating focus.
    func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }

    /// Adds a "Done" button above the keyboard that dismisses it.
    /// Apply to a view that contains text fields (e.g. the same view that has the ScrollView).
    func keyboardDoneToolbar(accentColor: Color = FFColors.goldPrimary) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()  // global function
                }
                .fontWeight(.semibold)
                .foregroundColor(accentColor)
            }
        }
    }
}
