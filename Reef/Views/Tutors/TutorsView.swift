//
//  TutorsView.swift
//  Reef
//
//  Tutors gallery page — browse, select, and customize AI tutor personas.
//

import SwiftUI

struct TutorsView: View {
    let colorScheme: ColorScheme

    @StateObject private var selectionManager = TutorSelectionManager.shared

    @State private var isInitialLoad = true
    @State private var selectedTutorForDetail: Tutor?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ZStack {
            Group {
                if isInitialLoad {
                    skeletonView
                } else {
                    mainContent
                }
            }

            // Detail popup overlay
            if let tutor = selectedTutorForDetail {
                TutorDetailPopup(
                    tutor: tutor,
                    isCurrentlySelected: selectionManager.selectedTutorID == tutor.id,
                    colorScheme: colorScheme,
                    initialPresetID: selectionManager.selectedTutorID == tutor.id ? selectionManager.selectedPresetID : tutor.presetModes.first?.id,
                    initialPatience: selectionManager.selectedTutorID == tutor.id ? selectionManager.customPatience : (tutor.presetModes.first?.patience ?? 0.5),
                    initialHintFrequency: selectionManager.selectedTutorID == tutor.id ? selectionManager.customHintFrequency : (tutor.presetModes.first?.hintFrequency ?? 0.5),
                    initialExplanationDepth: selectionManager.selectedTutorID == tutor.id ? selectionManager.customExplanationDepth : (tutor.presetModes.first?.explanationDepth ?? 0.5),
                    onSelect: { tutor, preset in
                        selectionManager.selectTutor(tutor, preset: preset)
                        selectedTutorForDetail = nil
                    },
                    onDismiss: {
                        selectedTutorForDetail = nil
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isInitialLoad = false
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero banner
                ActiveTutorBanner(
                    tutor: selectionManager.selectedTutor,
                    presetName: selectionManager.selectedPreset?.name,
                    colorScheme: colorScheme,
                    onChangeTapped: {}
                )

                // Section header
                HStack {
                    Text("All Tutors")
                        .font(.quicksand(20, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                    Spacer()
                }

                // Tutor grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(TutorCatalog.allTutors) { tutor in
                        TutorCardView(
                            tutor: tutor,
                            isSelected: selectionManager.selectedTutorID == tutor.id,
                            colorScheme: colorScheme,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedTutorForDetail = tutor
                                }
                            }
                        )
                    }
                }
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Banner skeleton
                ZStack {
                    Color.adaptiveCardBackground(for: colorScheme)
                    SkeletonShimmerView(colorScheme: colorScheme)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                // Section header skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 100, height: 20)

                // Card grid skeleton
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        skeletonCard
                    }
                }
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    private var skeletonCard: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                .frame(width: 64, height: 64)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                .frame(width: 90, height: 16)

            Capsule()
                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                .frame(width: 80, height: 22)

            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.06))
                    .frame(width: 100, height: 12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(for: colorScheme))
        .dashboardCard(colorScheme: colorScheme)
    }
}
