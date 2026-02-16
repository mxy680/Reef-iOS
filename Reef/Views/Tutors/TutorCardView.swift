//
//  TutorCardView.swift
//  Reef
//
//  Grid card for a single AI tutor persona.
//

import SwiftUI

struct TutorCardView: View {
    let tutor: Tutor
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var cardBackground: Color {
        Color.adaptiveCardBackground(for: colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(tutor.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: tutor.avatarSymbol)
                        .font(.system(size: 28))
                        .foregroundColor(tutor.accentColor)
                }

                // Name
                Text(tutor.name)
                    .font(.dynaPuff(16, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .lineLimit(1)

                // Specialty pill
                Text(tutor.specialty)
                    .font(.quicksand(12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .brightTealDark : .deepTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.deepTeal.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    )

                // Tagline
                Text(tutor.tagline)
                    .font(.quicksand(12, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Color.deepTeal : Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4),
                        lineWidth: isSelected ? 2 : 1.5
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.04), radius: 4, x: 0, y: 2)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.deepTeal)
                        .background(Circle().fill(Color.adaptiveCardBackground(for: colorScheme)).padding(2))
                        .offset(x: -8, y: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
