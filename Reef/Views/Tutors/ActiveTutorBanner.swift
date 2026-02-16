//
//  ActiveTutorBanner.swift
//  Reef
//
//  Hero banner showing the currently selected AI tutor, or a welcome prompt.
//

import SwiftUI

struct ActiveTutorBanner: View {
    let tutor: Tutor?
    let presetName: String?
    let colorScheme: ColorScheme
    let onChangeTapped: () -> Void

    private var bannerGradient: LinearGradient {
        if let tutor {
            return LinearGradient(
                colors: colorScheme == .dark
                    ? [tutor.accentColor.opacity(0.8), tutor.accentColor.opacity(0.5)]
                    : [tutor.accentColor, tutor.accentColor.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: colorScheme == .dark
                ? [Color.deepTeal.opacity(0.6), Color.deepTeal.opacity(0.3)]
                : [.seafoam, .deepTeal.opacity(0.3)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let tutor {
                selectedTutorContent(tutor)
            } else {
                welcomeContent
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bannerGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Selected Tutor

    private func selectedTutorContent(_ tutor: Tutor) -> some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 56, height: 56)

                Image(systemName: tutor.avatarSymbol)
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Tutor")
                    .font(.quicksand(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                Text(tutor.name)
                    .font(.dynaPuff(22, weight: .semiBold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Text(tutor.specialty)
                        .font(.quicksand(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))

                    if let presetName {
                        Text("·")
                            .foregroundColor(.white.opacity(0.6))
                        Text(presetName)
                            .font(.quicksand(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }

            Spacer()

            Button(action: onChangeTapped) {
                Text("Change")
                    .font(.quicksand(14, weight: .semiBold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Welcome

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white : .deepTeal)
                Text("Choose Your Tutor")
                    .font(.dynaPuff(20, weight: .semiBold))
                    .foregroundColor(colorScheme == .dark ? .white : .charcoal)
            }

            Text("Pick an AI tutor that matches your learning style. Each tutor has a unique personality and teaching approach.")
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Color.midGray)
        }
    }
}
