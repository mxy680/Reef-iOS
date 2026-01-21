//
//  WelcomeView.swift
//  Reef
//
//  Created on 2026-01-20.
//

import SwiftUI

struct WelcomeView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        Color.adaptivePrimary(for: effectiveColorScheme)
            .ignoresSafeArea()
            .preferredColorScheme(effectiveColorScheme)
    }
}

#Preview {
    WelcomeView()
}
