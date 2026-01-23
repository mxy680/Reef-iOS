//
//  QuicksandFont.swift
//  Reef
//
//  Custom font extension for Quicksand font family
//

import SwiftUI

// MARK: - Quicksand Font Extension
extension Font {

    // MARK: - Font Weights

    static func quicksand(_ size: CGFloat, weight: QuicksandWeight = .regular) -> Font {
        return .custom(weight.fontName, size: size)
    }

    enum QuicksandWeight {
        case regular
        case medium
        case semiBold
        case bold

        var fontName: String {
            switch self {
            case .regular: return "Quicksand-Regular"
            case .medium: return "Quicksand-Medium"
            case .semiBold: return "Quicksand-SemiBold"
            case .bold: return "Quicksand-Bold"
            }
        }
    }

    // MARK: - Semantic Text Styles

    static var quicksandLargeTitle: Font {
        .quicksand(34, weight: .bold)
    }

    static var quicksandTitle: Font {
        .quicksand(28, weight: .bold)
    }

    static var quicksandTitle2: Font {
        .quicksand(22, weight: .semiBold)
    }

    static var quicksandTitle3: Font {
        .quicksand(20, weight: .semiBold)
    }

    static var quicksandHeadline: Font {
        .quicksand(17, weight: .semiBold)
    }

    static var quicksandBody: Font {
        .quicksand(17, weight: .regular)
    }

    static var quicksandCallout: Font {
        .quicksand(16, weight: .regular)
    }

    static var quicksandSubheadline: Font {
        .quicksand(15, weight: .regular)
    }

    static var quicksandFootnote: Font {
        .quicksand(13, weight: .regular)
    }

    static var quicksandCaption: Font {
        .quicksand(12, weight: .regular)
    }

    static var quicksandCaption2: Font {
        .quicksand(11, weight: .regular)
    }
}

// MARK: - View Modifier for Default Quicksand Font
struct QuicksandFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.QuicksandWeight

    func body(content: Content) -> some View {
        content.font(.quicksand(size, weight: weight))
    }
}

extension View {
    func quicksandFont(_ size: CGFloat, weight: Font.QuicksandWeight = .regular) -> some View {
        modifier(QuicksandFontModifier(size: size, weight: weight))
    }
}
