//
//  StatsRowView.swift
//  Reef
//
//  Dashboard components: streak hero banner, continue studying card, and weekly stats row.
//

import SwiftUI

// MARK: - Neumorphic Card Modifier

struct NeumorphicModifier: ViewModifier {
    let cornerRadius: CGFloat
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: colorScheme == .dark ? .black.opacity(0.5) : Color(hex: "D1D9E6"),
                    radius: 15, x: 10, y: 10)
            .shadow(color: colorScheme == .dark ? Color(hex: "2A2228") : .white,
                    radius: 15, x: -10, y: -10)
    }
}

extension View {
    func claymorphic(cornerRadius: CGFloat = 28, colorScheme: ColorScheme = .light) -> some View {
        modifier(NeumorphicModifier(cornerRadius: cornerRadius, colorScheme: colorScheme))
    }
}

// MARK: - Dashboard Card Modifier

struct DashboardCardModifier: ViewModifier {
    let colorScheme: ColorScheme
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: colorScheme == .dark ? .black.opacity(0.5) : Color(hex: "D1D9E6"),
                    radius: 8, x: 5, y: 5)
            .shadow(color: colorScheme == .dark ? Color(hex: "2A2228") : .white,
                    radius: 8, x: -5, y: -5)
    }
}

extension View {
    func dashboardCard(colorScheme: ColorScheme, cornerRadius: CGFloat = 18) -> some View {
        modifier(DashboardCardModifier(colorScheme: colorScheme, cornerRadius: cornerRadius))
    }
}

// MARK: - Streak Hero Banner

struct StreakHeroBanner: View {
    let streak: Int
    let colorScheme: ColorScheme
    let userName: String?

    @State private var animatedStreak: Int = 0
    @State private var ringProgress: CGFloat = 0

    private var firstName: String {
        guard let name = userName, !name.isEmpty else { return "" }
        return String(name.split(separator: " ").first ?? Substring(name))
    }

    private var greeting: String {
        firstName.isEmpty ? "Welcome back!" : "Hey \(firstName)!"
    }

    private var motivationalText: String {
        switch streak {
        case 0: return "Start your streak!"
        case 1...2: return "Great start!"
        case 3...6: return "Keep it up!"
        case 7...13: return "One week strong!"
        case 14...29: return "On fire!"
        default: return "Incredible!"
        }
    }

    private var isZeroStreak: Bool { streak == 0 }

    private var bannerGradient: LinearGradient {
        if isZeroStreak {
            return LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "2A5A5A"), .deepTeal]
                    : [.seafoam, .deepTeal],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "8B3A3A"), .deepCoral]
                : [.deepCoral, .softCoral],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var weeklyProgress: CGFloat {
        guard streak > 0 else { return 0 }
        return CGFloat(streak % 7) / 7.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top: greeting + flame ring
            HStack(alignment: .top) {
                Text(greeting)
                    .font(.dynaPuff(18, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 48, height: 48)

                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .opacity(isZeroStreak ? 0.5 : 1)
                }
            }

            Spacer(minLength: 0)

            // Bottom: streak number, label, motivational text
            Text("\(animatedStreak)")
                .font(.dynaPuff(64, weight: .bold))
                .foregroundColor(.white)
                .contentTransition(.numericText())

            Text("day streak")
                .font(.quicksand(16, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Text(motivationalText)
                .font(.quicksand(13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 2)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(bannerGradient)
        .claymorphic(cornerRadius: 28, colorScheme: colorScheme)
        .onAppear {
            // Animate streak count up
            withAnimation(.easeOut(duration: 0.8)) {
                animatedStreak = streak
            }
            // Animate ring trim
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringProgress = weeklyProgress == 0 && streak > 0 ? 1.0 : weeklyProgress
            }
        }
        .onChange(of: streak) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedStreak = newValue
            }
            withAnimation(.easeOut(duration: 0.6)) {
                let wp = CGFloat(newValue % 7) / 7.0
                ringProgress = wp == 0 && newValue > 0 ? 1.0 : wp
            }
        }
    }
}

// MARK: - Continue Studying Card

struct ContinueStudyingCard: View {
    let item: (Note, Course)?
    let colorScheme: ColorScheme
    let onTap: ((Note, Course) -> Void)?

    var body: some View {
        if let (note, course) = item {
            VStack(alignment: .leading, spacing: 12) {
                Text("Continue Studying")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                Button {
                    onTap?(note, course)
                } label: {
                    HStack(spacing: 12) {
                        // File icon in seafoam rounded rect
                        Image(systemName: note.fileTypeIcon)
                            .font(.system(size: 18))
                            .foregroundColor(.deepTeal)
                            .frame(width: 44, height: 44)
                            .background(Color.seafoam.opacity(colorScheme == .dark ? 0.2 : 0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Note name + course name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.name)
                                .font(.quicksand(17, weight: .semiBold))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))
                                .lineLimit(1)

                            Text(course.name)
                                .font(.quicksand(14, weight: .regular))
                                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Arrow circle
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.deepCoral)
                            .clipShape(Circle())
                    }
                    .padding(16)
                    .background(Color.adaptiveCardBackground(for: colorScheme))
                    .dashboardCard(colorScheme: colorScheme)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Bento Stat Card

struct BentoStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let colorScheme: ColorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.warmDarkCard : .cardBackground
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(colorScheme == .dark ? 0.15 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.quicksand(24, weight: .bold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(label)
                    .font(.quicksand(13, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .claymorphic(cornerRadius: 28, colorScheme: colorScheme)
    }
}

#Preview {
    VStack(spacing: 28) {
        HStack(alignment: .top, spacing: 16) {
            StreakHeroBanner(streak: 12, colorScheme: .light, userName: "Mark Shteyn")

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    BentoStatCard(icon: "clock.fill", iconColor: .deepTeal,
                        value: "2h 30m", label: "study time", colorScheme: .light)
                    BentoStatCard(icon: "checkmark.circle.fill", iconColor: .deepCoral,
                        value: "14", label: "problems", colorScheme: .light)
                }
                BentoStatCard(icon: "sparkles", iconColor: .deepTeal,
                    value: "8", label: "AI feedback", colorScheme: .light)
            }
        }
        .fixedSize(horizontal: false, vertical: true)

        ContinueStudyingCard(item: nil, colorScheme: .light, onTap: nil)
    }
    .padding(32)
    .background(Color.adaptiveBackground(for: .light))
}
