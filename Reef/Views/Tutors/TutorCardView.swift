//
//  TutorCardView.swift
//  Reef
//
//  Carousel card for a single marine tutor.
//

import SwiftUI

struct TutorCardView: View {
    let tutor: Tutor
    let isFocused: Bool
    let isActiveTutor: Bool
    let colorScheme: ColorScheme

    private var cardBackground: Color {
        Color.adaptiveCardBackground(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Emoji avatar
            Text(tutor.emoji)
                .font(.system(size: isFocused ? 52 : 40))
                .shadow(color: tutor.accentColor.opacity(0.4), radius: isFocused ? 8 : 0)

            // Name
            Text(tutor.name)
                .font(.dynaPuff(isFocused ? 18 : 15, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))
                .lineLimit(1)

            // Species
            Text(tutor.species)
                .font(.quicksand(12, weight: .regular))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))

            // Active indicator
            if isActiveTutor {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Active")
                        .font(.quicksand(11, weight: .semiBold))
                }
                .foregroundColor(.deepTeal)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(width: 180, height: 190)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isFocused ? tutor.accentColor : Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4),
                    lineWidth: isFocused ? 2.5 : 1.5
                )
        )
        .shadow(
            color: isFocused ? tutor.accentColor.opacity(0.25) : .black.opacity(colorScheme == .dark ? 0.08 : 0.04),
            radius: isFocused ? 12 : 4,
            x: 0,
            y: isFocused ? 4 : 2
        )
        .scaleEffect(isFocused ? 1.05 : 0.95)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
    }
}
