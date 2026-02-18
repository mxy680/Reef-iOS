//
//  ReefColors.swift
//  Reef
//
//  Color palette for Reef app
//

import SwiftUI

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }

    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    func toggle() {
        objectWillChange.send()
        isDarkMode.toggle()
    }
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reef Color Palette
extension Color {

    // MARK: - Primary Colors (Light Mode)

    /// Primary accent — warm coral for actions, highlights, CTA buttons
    static let softCoral = Color(hex: "F9C1B6")

    /// Secondary accent — soft seafoam green
    static let seafoam = Color(hex: "C3DFDE")

    /// Pressed/contrast coral — deeper coral for emphasis
    static let deepCoral = Color(hex: "D4877A")

    /// Links, icon accents — muted teal
    static let deepTeal = Color(hex: "5B9E9B")

    // MARK: - Neutral Colors

    /// Headlines, body text
    static let charcoal = Color(hex: "2B2B2B")

    /// Secondary text
    static let midGray = Color(hex: "7A7A7A")

    /// Page background — warm blush white
    static let blushWhite = Color(hex: "EDE7E9")

    // MARK: - Card Colors

    /// Card background - pure white
    static let cardBackground = Color(hex: "FFFFFF")

    /// Thumbnail background — matches blushWhite
    static let thumbnailBackground = Color(hex: "F9F5F6")

    /// Thumbnail border — charcoal retro outline
    static let thumbnailBorder = Color(hex: "2B2B2B")

    /// Delete button red
    static let deleteRed = Color(hex: "E07A5F")

    /// Delete button background - very light red tint
    static let deleteRedBackground = Color(hex: "FDF2F0")

    // MARK: - Semantic Aliases

    static let reefPrimary = deepTeal
    static let reefSecondary = deepTeal
    static let reefAccent = deepCoral
    static let reefText = charcoal
    static let reefBackground = blushWhite

    // MARK: - Dark Mode Colors

    /// Dark mode background — warm darkness
    static let warmDark = Color(hex: "1A1418")

    /// Dark mode card background — slightly lighter than warmDark
    static let warmDarkCard = Color(hex: "251E22")

    /// Dark mode text — warm white for readability
    static let warmWhite = Color(hex: "F5F0EE")

    /// Dark mode secondary — bright seafoam
    static let brightSeafoam = Color(hex: "D4ECE8")

    /// Dark mode accent — bright teal for links on dark backgrounds
    static let brightTealDark = Color(hex: "7CB5AC")

    /// Dark mode toolbar — deepTeal darkened (177°, 27%, 33%)
    static let toolbarDark = Color(hex: "3D6B69")

    /// Dark mode tab strip — deepTeal darker (177°, 27%, 28%)
    static let tabStripDark = Color(hex: "345B59")

    // MARK: - Adaptive Colors

    /// Adaptive background color
    static func adaptiveBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? warmDark : blushWhite
    }

    /// Adaptive text color
    static func adaptiveText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? warmWhite : charcoal
    }

    /// Adaptive primary color (teal for buttons and interactive elements)
    static func adaptivePrimary(for scheme: ColorScheme) -> Color {
        deepTeal
    }

    /// Adaptive secondary color
    static func adaptiveSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? brightSeafoam : deepTeal
    }

    /// Adaptive accent color
    static func adaptiveAccent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? brightTealDark : deepCoral
    }

    /// Adaptive card background - slightly elevated from page background in dark mode
    static func adaptiveCardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? warmDarkCard : .white
    }

    /// Adaptive secondary text color
    static func adaptiveSecondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? warmWhite.opacity(0.6) : midGray
    }

}

// MARK: - Reef Gradients
extension LinearGradient {

    /// Warm gradient: Deep Coral → Soft Coral → Seafoam
    static let reefWarm = LinearGradient(
        colors: [.deepCoral, .softCoral, .seafoam],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vertical warm gradient for backgrounds
    static let reefWarmVertical = LinearGradient(
        colors: [.deepCoral, .softCoral, .seafoam],
        startPoint: .bottom,
        endPoint: .top
    )

    /// Coral gradient: Deep Coral → Soft Coral
    static let reefCoral = LinearGradient(
        colors: [.deepCoral, .softCoral],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Adaptive vertical gradient for PreAuth screen
    static func preAuthGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [.brightTealDark, .warmDark],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [.deepCoral, .softCoral],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

}
