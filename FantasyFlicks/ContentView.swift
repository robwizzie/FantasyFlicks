//
//  ContentView.swift
//  FantasyFlicks
//
//  Created by Robert Wiscount on 1/31/26.
//

import SwiftUI

/// Root content view - redirects to MainTabView
/// Kept for backward compatibility with older SwiftUI patterns
struct ContentView: View {
    var body: some View {
        MainTabView()
            .ffTheme()
    }
}

#Preview {
    ContentView()
}
