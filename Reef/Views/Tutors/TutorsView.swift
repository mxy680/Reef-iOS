//
//  TutorsView.swift
//  Reef
//
//  Tutors page — auto-scrolling marine animal carousel with profile cards.
//

import SwiftUI

struct TutorsView: View {
    let colorScheme: ColorScheme

    @StateObject private var selectionManager = TutorSelectionManager.shared

    @State private var isInitialLoad = true
    @State private var focusedTutorID: String?
    @State private var autoScrollTimer: Timer?
    @State private var isUserInteracting = false
    @State private var showingVoicePreview = false

    private let tutors = TutorCatalog.allTutors
    private let autoScrollInterval: TimeInterval = 15.0

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
        VStack(spacing: 20) {
            heroCard
                .padding(.horizontal, 32)

            carouselSection

            Spacer(minLength: 0)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: colorScheme))
        .animation(.easeInOut(duration: 0.3), value: focusedTutorID)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let tutor = focusedTutor
        let isActive = selectionManager.selectedTutorID == tutor.id

        let gradient = LinearGradient(
            colors: colorScheme == .dark
                ? [tutor.accentColor.opacity(0.7), tutor.accentColor.opacity(0.35)]
                : [tutor.accentColor.opacity(0.85), tutor.accentColor.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text(tutor.name)
                    .font(.dynaPuff(30, weight: .bold))
                    .foregroundColor(.white)
                    .id(tutor.id + "-name")

                Text("The \(tutor.species)")
                    .font(.quicksand(15, weight: .semiBold))
                    .foregroundColor(.white.opacity(0.85))
            }

            // Two-column: personality+lore | fun fact
            HStack(alignment: .top, spacing: 20) {
                // Left: personality + lore
                VStack(alignment: .leading, spacing: 8) {
                    Text(tutor.personality)
                        .font(.quicksand(14, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(4)
                        .id(tutor.id + "-personality")

                    Text(tutor.lore)
                        .font(.quicksand(13, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(3)
                        .id(tutor.id + "-lore")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: fun fact
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("🧠")
                            .font(.system(size: 14))
                        Text("Did You Know?")
                            .font(.quicksand(13, weight: .semiBold))
                            .foregroundColor(.white)
                    }

                    Text(tutor.funFact)
                        .font(.quicksand(12, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(4)
                        .id(tutor.id + "-funfact")
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Buttons row
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingVoicePreview.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showingVoicePreview ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.system(size: 14))
                        Text("Preview Voice")
                            .font(.quicksand(14, weight: .semiBold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)

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
                        Image(systemName: isActive ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 16))
                        Text(isActive ? "Active Tutor" : "Select as Active Tutor")
                            .font(.quicksand(15, weight: .semiBold))
                    }
                    .foregroundColor(isActive ? .white : Color.adaptiveText(for: colorScheme))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(isActive ? Color.white.opacity(0.25) : Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: 300)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .onChange(of: focusedTutorID) { _, _ in
            showingVoicePreview = false
        }
    }

    // MARK: - Carousel

    private var carouselSection: some View {
        VStack(spacing: 14) {
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
                .padding(.vertical, 12)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedTutorID)
            .frame(height: 230)
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
            HStack(spacing: 6) {
                ForEach(tutors) { tutor in
                    Circle()
                        .fill(tutor.id == focusedTutorID
                            ? Color.deepTeal
                            : Color.adaptiveSecondaryText(for: colorScheme).opacity(0.3))
                        .frame(width: tutor.id == focusedTutorID ? 8 : 5,
                               height: tutor.id == focusedTutorID ? 8 : 5)
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
        VStack(spacing: 20) {
            // Hero skeleton
            ZStack {
                Color.adaptiveCardBackground(for: colorScheme)
                SkeletonShimmerView(colorScheme: colorScheme)
            }
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
            )
            .padding(.horizontal, 32)

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
            .padding(.horizontal, 32)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: colorScheme))
    }
}
