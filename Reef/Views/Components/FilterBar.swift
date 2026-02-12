//
//  FilterBar.swift
//  Reef
//
//  Reusable filter bar component with search and sort controls
//

import SwiftUI

struct FilterBar: View {
    @Binding var searchText: String
    @Binding var sortNewestFirst: Bool
    var placeholder: String = "Search..."

    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        HStack(spacing: 16) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.6))

                TextField(placeholder, text: $searchText)
                    .font(.quicksand(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.adaptiveCardBackground(for: effectiveColorScheme))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(effectiveColorScheme == .dark ? 0.08 : 0.04), radius: 8, x: 0, y: 2)

            // Sort toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sortNewestFirst.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sortNewestFirst ? "Newest" : "Oldest")
                        .font(.quicksand(14, weight: .semiBold))

                    Image(systemName: sortNewestFirst ? "arrow.down" : "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.deepTeal)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        FilterBar(searchText: .constant(""), sortNewestFirst: .constant(true))
        FilterBar(searchText: .constant("Chapter"), sortNewestFirst: .constant(false))
        Spacer()
    }
    .background(Color.blushWhite)
}
