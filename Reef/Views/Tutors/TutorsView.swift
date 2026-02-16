//
//  TutorsView.swift
//  Reef
//
//  Tutors page — auto-scrolling marine animal carousel with profile display.
//

import SwiftUI

struct TutorsView: View {
    let colorScheme: ColorScheme

    @StateObject private var selectionManager = TutorSelectionManager.shared

    @State private var isInitialLoad = true
    @State private var focusedTutorID: String?
    @State private var autoScrollTimer: Timer?
    @State private var isUserInteracting = false

    private let tutors = TutorCatalog.allTutors
    private let autoScrollInterval: TimeInterval = 4.0

    private var focusedTutor: Tutor {
        tutors.first { $0.id == focusedTutorID } ?? tutors[0]
    }

    var body: some View {
        Group {
            if isInitialLoad {
                skeletonView
            } else {
                mainContent
            }
        }
        .onAppear {
            if focusedTutorID == nil {
                focusedTutorID = tutors[0].id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isInitialLoad = false
                }
            }
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top: Profile section
            profileSection
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)

            Spacer(minLength: 0)

            // Bottom: Carousel
            carouselSection
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        let tutor = focusedTutor
        let isActive = selectionManager.selectedTutorID == tutor.id

        return VStack(spacing: 14) {
            // Large emoji
            Text(tutor.emoji)
                .font(.system(size: 64))
                .shadow(color: tutor.accentColor.opacity(0.3), radius: 12)
                .id(tutor.id + "-emoji")

            // Name + species
            VStack(spacing: 4) {
                Text(tutor.name)
                    .font(.dynaPuff(28, weight: .bold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                Text("The \(tutor.species)")
                    .font(.quicksand(15, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
            }
            .id(tutor.id + "-name")

            // Personality
            Text(tutor.personality)
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 40)
                .id(tutor.id + "-personality")

            // Voice + Lore in two columns
            HStack(alignment: .top, spacing: 20) {
                profileDetail(
                    icon: "quote.bubble.fill",
                    title: "Voice",
                    text: tutor.voice
                )

                profileDetail(
                    icon: "book.fill",
                    title: "Lore",
                    text: tutor.lore
                )
            }
            .padding(.horizontal, 32)

            // Fun fact
            HStack(alignment: .top, spacing: 8) {
                Text("🧠")
                    .font(.system(size: 14))
                Text(tutor.funFact)
                    .font(.quicksand(12, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                    .italic()
            }
            .padding(.horizontal, 48)
            .id(tutor.id + "-funfact")

            // Select button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isActive {
                        selectionManager.selectedTutorID = nil
                    } else {
                        selectionManager.selectTutor(tutor, preset: tutor.presetModes.first)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Active Tutor")
                            .font(.quicksand(16, weight: .semiBold))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Select as Active Tutor")
                            .font(.quicksand(16, weight: .semiBold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(isActive ? tutor.accentColor : Color.deepTeal)
                )
                .shadow(color: (isActive ? tutor.accentColor : Color.deepTeal).opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .animation(.easeInOut(duration: 0.3), value: focusedTutorID)
    }

    private func profileDetail(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(focusedTutor.accentColor)
                Text(title)
                    .font(.quicksand(13, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
            }

            Text(text)
                .font(.quicksand(12, weight: .regular))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Carousel

    private var carouselSection: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(tutors) { tutor in
                        TutorCardView(
                            tutor: tutor,
                            isFocused: tutor.id == focusedTutorID,
                            isActiveTutor: selectionManager.selectedTutorID == tutor.id,
                            colorScheme: colorScheme
                        )
                        .id(tutor.id)
                        .onTapGesture {
                            isUserInteracting = true
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                focusedTutorID = tutor.id
                            }
                            restartAutoScroll()
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 32)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedTutorID)
            .frame(height: 210)
            .onChange(of: focusedTutorID) { _, _ in
                // Reset auto-scroll when user swipes
                if isUserInteracting {
                    restartAutoScroll()
                }
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in isUserInteracting = true }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isUserInteracting = false
                        }
                    }
            )

            // Page dots
            HStack(spacing: 8) {
                ForEach(tutors) { tutor in
                    Circle()
                        .fill(tutor.id == focusedTutorID
                            ? Color.deepTeal
                            : Color.adaptiveSecondaryText(for: colorScheme).opacity(0.3))
                        .frame(width: tutor.id == focusedTutorID ? 8 : 6,
                               height: tutor.id == focusedTutorID ? 8 : 6)
                        .animation(.easeOut(duration: 0.2), value: focusedTutorID)
                }
            }
        }
    }

    // MARK: - Auto Scroll

    private func startAutoScroll() {
        stopAutoScroll()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { _ in
            Task { @MainActor in
                guard !isUserInteracting else { return }
                advanceCarousel()
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func restartAutoScroll() {
        stopAutoScroll()
        DispatchQueue.main.asyncAfter(deadline: .now() + autoScrollInterval) {
            isUserInteracting = false
            startAutoScroll()
        }
    }

    private func advanceCarousel() {
        guard let currentID = focusedTutorID,
              let currentIndex = tutors.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIndex = (currentIndex + 1) % tutors.count
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            focusedTutorID = tutors[nextIndex].id
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(spacing: 24) {
            // Profile skeleton
            VStack(spacing: 14) {
                Circle()
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                    .frame(width: 72, height: 72)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 120, height: 28)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                    .frame(width: 80, height: 16)

                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06))
                        .frame(width: 320, height: 14)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06))
                        .frame(width: 260, height: 14)
                }

                // Two-column placeholder
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                            .frame(width: 50, height: 14)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06))
                            .frame(height: 40)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                            .frame(width: 50, height: 14)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06))
                            .frame(height: 40)
                    }
                }
                .padding(.horizontal, 32)

                Capsule()
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.1))
                    .frame(width: 200, height: 44)
            }
            .padding(.top, 32)

            Spacer()

            // Carousel skeleton
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    ZStack {
                        Color.adaptiveCardBackground(for: colorScheme)
                        SkeletonShimmerView(colorScheme: colorScheme)
                    }
                    .frame(width: 180, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
                    )
                }
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: colorScheme))
    }
}
