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
        case .account: return "person.crop.circle.fill"
        case .ai:      return "brain.fill"
        case .study:   return "book.fill"
        case .privacy: return "lock.shield.fill"
        case .about:   return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .account: return Color.deepTeal
        case .ai:      return Color.deepTeal
        case .study:   return Color.deepCoral
        case .privacy: return Color.deepTeal
        case .about:   return Color.deepCoral
        }
    }
}

// MARK: - Bento Card

private struct BentoCard: View {
    let section: SettingsSection
    let colorScheme: ColorScheme
    var isHero: Bool = false

    private var borderColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.5 : 0.35)
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.warmDarkCard : Color.white
    }

    var body: some View {
        if isHero {
            heroContent
        } else {
            standardContent
        }
    }

    private var heroContent: some View {
        VStack(spacing: 16) {
            Image(systemName: section.icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))

            Text(section.title)
                .font(.quicksand(22, weight: .bold))
                .foregroundColor(.white)

            Text(section.subtitle)
                .font(.quicksand(14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.deepTeal, Color.seafoam],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var standardContent: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(section.iconColor.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(section.iconColor)
                )

            Text(section.title)
                .font(.quicksand(16, weight: .bold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            Text(section.subtitle)
                .font(.quicksand(11, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private let gap: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 64   // 32pt padding each side
            let h = geo.size.height - 64
            let topH = (h - gap) * 0.6
            let botH = (h - gap) * 0.4
            let smallH = (topH - gap) / 2
            let leftCol = (w - gap) * 0.58
            let rightCol = (w - gap) * 0.42
            let botLeft = (w - gap) * 0.42
            let botRight = (w - gap) * 0.58

            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    bentoLink(.account, isHero: true)
                        .frame(width: leftCol, height: topH)

                    VStack(spacing: gap) {
                        bentoLink(.ai)
                            .frame(height: smallH)
                        bentoLink(.study)
                            .frame(height: smallH)
                    }
                    .frame(width: rightCol, height: topH)
                }

                HStack(spacing: gap) {
                    bentoLink(.privacy)
                        .frame(width: botLeft, height: botH)
                    bentoLink(.about)
                        .frame(width: botRight, height: botH)
                }
            }
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
