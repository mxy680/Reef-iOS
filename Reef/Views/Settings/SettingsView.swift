//
//  SettingsView.swift
//  Reef
//
//  Settings home — bento box grid that navigates into detail views.
//

import SwiftUI

// MARK: - Section Enum

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case account, ai, study, privacy, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: return "Account"
        case .ai:      return "AI"
        case .study:   return "Study"
        case .privacy: return "Privacy"
        case .about:   return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .account: return "Profile & sign-in"
        case .ai:      return "Models & feedback"
        case .study:   return "Quiz & exam defaults"
        case .privacy: return "Data & analytics"
        case .about:   return "Info & support"
        }
    }

    var icon: String {
        switch self {
        case .account: return "person.crop.circle"
        case .ai:      return "brain"
        case .study:   return "book"
        case .privacy: return "lock.shield"
        case .about:   return "info.circle"
        }
    }
}

// MARK: - Bento Card

private struct BentoCard: View {
    let section: SettingsSection
    let colorScheme: ColorScheme
    var isHero: Bool = false

    var body: some View {
        VStack(spacing: isHero ? 14 : 8) {
            Image(systemName: section.icon)
                .font(.system(size: isHero ? 36 : 24, weight: .medium))
                .foregroundColor(Color.deepTeal)

            Text(section.title)
                .font(.quicksand(isHero ? 20 : 16, weight: .bold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            Text(section.subtitle)
                .font(.quicksand(isHero ? 14 : 12, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.warmDarkCard : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    // Layout constants
    private let gap: CGFloat = 12
    private let topRowHeight: CGFloat = 240
    private let bottomRowHeight: CGFloat = 160

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                let w = geo.size.width
                let leftCol = (w - gap) * 0.58
                let rightCol = (w - gap) * 0.42
                let smallCardH = (topRowHeight - gap) / 2
                let botLeft = (w - gap) * 0.42
                let botRight = (w - gap) * 0.58

                VStack(spacing: gap) {
                    // ┌──────────────┬──────────┐
                    // │              │    AI    │
                    // │   Account    ├──────────┤
                    // │              │  Study   │
                    // └──────────────┴──────────┘
                    HStack(spacing: gap) {
                        bentoLink(.account, isHero: true)
                            .frame(width: leftCol, height: topRowHeight)

                        VStack(spacing: gap) {
                            bentoLink(.ai)
                                .frame(height: smallCardH)
                            bentoLink(.study)
                                .frame(height: smallCardH)
                        }
                        .frame(width: rightCol, height: topRowHeight)
                    }

                    // ┌─────────┬───────────────┐
                    // │ Privacy │     About      │
                    // └─────────┴───────────────┘
                    HStack(spacing: gap) {
                        bentoLink(.privacy)
                            .frame(width: botLeft, height: bottomRowHeight)
                        bentoLink(.about)
                            .frame(width: botRight, height: bottomRowHeight)
                    }
                }
            }
            .frame(height: topRowHeight + gap + bottomRowHeight)
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationDestination(for: SettingsSection.self) { section in
            switch section {
            case .account: AccountSettingsView(authManager: authManager)
            case .ai:      AISettingsView()
            case .study:   StudySettingsView()
            case .privacy: PrivacySettingsView()
            case .about:   AboutView()
            }
        }
    }

    private func bentoLink(_ section: SettingsSection, isHero: Bool = false) -> some View {
        NavigationLink(value: section) {
            BentoCard(
                section: section,
                colorScheme: effectiveColorScheme,
                isHero: isHero
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView(authManager: AuthenticationManager())
    }
}
