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

    // MARK: - Primary Colors

    /// Primary actions, interactive elements, highlights, active states, and key call-to-action buttons
    static let vibrantTeal = Color(hex: "119DA4")

    /// Secondary elements, links, hover states, and supporting UI components
    static let oceanMid = Color(hex: "0C7489")

    /// Headers, emphasis areas, dark backgrounds, and navigation elements
    static let deepSea = Color(hex: "13505B")

    // MARK: - Neutral Colors

    /// Body text, icons, and high-contrast elements requiring maximum readability
    static let inkBlack = Color(hex: "040404")

    /// Backgrounds, cards, dividers, and neutral surfaces
    static let sageMist = Color(hex: "E8EAE1")

    // MARK: - Card Colors

    /// Card background - pure white
    static let cardBackground = Color(hex: "FFFFFF")

    /// Thumbnail background - light gray
    static let thumbnailBackground = Color(hex: "F5F5F5")

    /// Thumbnail border - subtle gray
    static let thumbnailBorder = Color(hex: "E0E0E0")

    /// Delete button red
    static let deleteRed = Color(hex: "E07A5F")

    /// Delete button background - very light red tint
    static let deleteRedBackground = Color(hex: "FDF2F0")

    // MARK: - Semantic Aliases

    static let reefPrimary = vibrantTeal
    static let reefSecondary = oceanMid
    static let reefAccent = deepSea
    static let reefText = inkBlack
    static let reefBackground = sageMist

    // MARK: - Dark Mode Colors

    /// Dark mode background - deep ocean darkness
    static let deepOcean = Color(hex: "0A1628")

    /// Dark mode text - pearl white for readability
    static let pearlWhite = Color(hex: "F0F2F5")

    /// Dark mode secondary - slightly brighter teal
    static let brightTeal = Color(hex: "14B8C4")

    /// Dark mode accent - lighter teal for dark backgrounds
    static let lightTeal = Color(hex: "1A7A8A")

    /// Dark mode card background - slightly lighter than deepOcean for contrast
    static let deepOceanCard = Color(hex: "131F33")

    // MARK: - Adaptive Colors

    /// Light gray background for light mode (close to white)
    static let lightGrayBackground = Color(white: 0.96)

    /// Adaptive background color
    static func adaptiveBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? deepOcean : lightGrayBackground
    }

    /// Adaptive text color
    static func adaptiveText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? pearlWhite : inkBlack
    }

    /// Adaptive primary color (unchanged across themes)
    static func adaptivePrimary(for scheme: ColorScheme) -> Color {
        vibrantTeal
    }

    /// Adaptive secondary color
    static func adaptiveSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? brightTeal : oceanMid
    }

    /// Adaptive accent color
    static func adaptiveAccent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? lightTeal : deepSea
    }

    /// Adaptive card background - slightly elevated from page background in dark mode
    static func adaptiveCardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? deepOceanCard : .white
    }
}

// MARK: - Reef Gradients
extension LinearGradient {

    /// Ocean gradient: Deep Sea → Ocean Mid → Vibrant Teal
    static let reefOcean = LinearGradient(
        colors: [.deepSea, .oceanMid, .vibrantTeal],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vertical ocean gradient for backgrounds
    static let reefOceanVertical = LinearGradient(
        colors: [.deepSea, .oceanMid, .vibrantTeal],
        startPoint: .bottom,
        endPoint: .top
    )

    /// Deep gradient: Deep Sea → Ocean Mid
    static let reefDeep = LinearGradient(
        colors: [.deepSea, .oceanMid],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Adaptive vertical gradient for PreAuth screen
    static func preAuthGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [.lightTeal, .deepOcean],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [.oceanMid, .deepSea],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
