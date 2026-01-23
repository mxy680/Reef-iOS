//
//  SettingsView.swift
//  Reef
//
//  Main settings view with tabbed navigation.
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case account = "Account"
    case ai = "AI"
    case study = "Study"
    case privacy = "Privacy"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .account: return "person.circle"
        case .ai: return "brain"
        case .study: return "book"
        case .privacy: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: SettingsTab = .account

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            tabPicker

            // Tab content
            tabContent
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(tab.rawValue)
                            .font(.quicksand(14, weight: .semiBold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedTab == tab ? Color.vibrantTeal : Color.sageMist.opacity(effectiveColorScheme == .dark ? 0.2 : 1))
                    )
                    .foregroundColor(selectedTab == tab ? .white : Color.adaptiveText(for: effectiveColorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .account:
            AccountSettingsView(authManager: authManager)
        case .ai:
            AISettingsView()
        case .study:
            StudySettingsView()
        case .privacy:
            PrivacySettingsView()
        case .about:
            AboutView()
        }
    }
}

#Preview {
    SettingsView(authManager: AuthenticationManager())
}
