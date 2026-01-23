//
//  DynaPuffFont.swift
//  Reef
//
//  Custom font extension for DynaPuff font family
//

import SwiftUI

// MARK: - DynaPuff Font Extension
extension Font {

    static func dynaPuff(_ size: CGFloat, weight: DynaPuffWeight = .regular) -> Font {
        return .custom(weight.fontName, size: size)
    }

    enum DynaPuffWeight {
        case regular
        case medium
        case semiBold
        case bold

        var fontName: String {
            switch self {
            case .regular: return "DynaPuff-Regular"
            case .medium: return "DynaPuff-Medium"
            case .semiBold: return "DynaPuff-SemiBold"
            case .bold: return "DynaPuff-Bold"
            }
        }
    }
}
