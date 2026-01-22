//
//  VersionHistoryView.swift
//  Reef
//
//  View for displaying and restoring annotation version history

import SwiftUI

struct VersionHistoryView: View {
    let versions: [AnnotationVersion]
    let onRestore: (UUID) -> Void
    let onDismiss: () -> Void
    let colorScheme: ColorScheme

    @State private var selectedVersionId: UUID?
    @State private var isShowingRestoreConfirmation = false

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Content card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Version History")
                        .font(.quicksand(18, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(colorScheme == .dark ? Color.deepOcean : Color.sageMist)

                Divider()

                // Version list
                if versions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.3))

                        Text("No versions yet")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.6))

                        Text("Versions are saved automatically as you draw")
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                                VersionRow(
                                    version: version,
                                    isLatest: index == 0,
                                    colorScheme: colorScheme,
                                    onRestore: {
                                        selectedVersionId = version.id
                                        isShowingRestoreConfirmation = true
                                    }
                                )

                                if index < versions.count - 1 {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 400)
            .frame(maxHeight: 500)
            .background(colorScheme == .dark ? Color.deepOcean : Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
            .alert("Restore Version?", isPresented: $isShowingRestoreConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedVersionId = nil
                }
                Button("Restore") {
                    if let versionId = selectedVersionId {
                        onRestore(versionId)
                        onDismiss()
                    }
                }
            } message: {
                Text("This will restore your annotations to this version. Your current work will be saved as a new version.")
            }
        }
    }
}

// MARK: - Version Row

struct VersionRow: View {
    let version: AnnotationVersion
    let isLatest: Bool
    let colorScheme: ColorScheme
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Timeline indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(isLatest ? Color.vibrantTeal : Color.adaptiveText(for: colorScheme).opacity(0.3))
                    .frame(width: 12, height: 12)
            }
            .frame(width: 20)

            // Version info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(version.formattedDate)
                        .font(.quicksand(15, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))

                    if isLatest {
                        Text("Current")
                            .font(.quicksand(12, weight: .semiBold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.vibrantTeal)
                            .cornerRadius(4)
                    }
                }

                Text("\(version.drawings.count) page\(version.drawings.count == 1 ? "" : "s") with annotations")
                    .font(.quicksand(13, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.6))
            }

            Spacer()

            // Restore button (not shown for latest)
            if !isLatest {
                Button {
                    onRestore()
                } label: {
                    Text("Restore")
                        .font(.quicksand(14, weight: .semiBold))
                        .foregroundColor(Color.vibrantTeal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.vibrantTeal.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}
