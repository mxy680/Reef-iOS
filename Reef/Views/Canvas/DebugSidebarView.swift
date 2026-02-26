//
//  DebugSidebarView.swift
//  Reef
//

import SwiftUI

struct DebugSidebarView: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack {
            Spacer()
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .background(
            Color.adaptiveCardBackground(for: colorScheme)
                .shadow(.inner(color: .black.opacity(0.08), radius: 4, x: -2, y: 0))
        )
    }
}
