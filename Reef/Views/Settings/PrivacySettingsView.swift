//
//  PrivacySettingsView.swift
//  Reef
//
//  Privacy settings for data management and analytics preferences.
//

import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var cacheSize: String = "Calculating..."
    @State private var storageUsed: String = "Calculating..."
    @State private var isReindexing = false
    @State private var reindexProgress: Double = 0
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showClearCacheConfirmation = false
    @State private var showClearHistoryConfirmation = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Data & Storage Section
                sectionHeader("Data & Storage", isFirst: true)

                // Clear Cache
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear Cache")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Text(cacheSize)
                            .font(.quicksand(13, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                    }
                    Spacer()
                    Button {
                        showClearCacheConfirmation = true
                    } label: {
                        Text("Clear")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.deepTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Clear Search History
                HStack {
                    Text("Clear Search History")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    Button {
                        showClearHistoryConfirmation = true
                    } label: {
                        Text("Clear")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.deepTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Storage Used
                HStack {
                    Text("Storage Used")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    Text(storageUsed)
                        .font(.quicksand(14, weight: .medium))
                        .foregroundColor(Color.deepTeal)
                }
                .frame(minHeight: 44)

                // RAG Indexing Section
                sectionHeader("RAG Indexing")

                // Index Documents Toggle
                Toggle(isOn: $preferences.indexDocumentsForAI) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Index Documents for AI")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Text("Enable AI to search your documents for better answers")
                            .font(.quicksand(13, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                    }
                }
                .tint(Color.deepTeal)
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Re-index All Documents
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Re-index All Documents")
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                            Text("Rebuild the AI search index")
                                .font(.quicksand(13, weight: .regular))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                        }
                        Spacer()
                        if isReindexing {
                            ProgressView()
                                .tint(Color.deepTeal)
                        } else {
                            Button {
                                startReindexing()
                            } label: {
                                Text("Re-index")
                                    .font(.quicksand(14, weight: .semiBold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.deepTeal)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isReindexing {
                        ProgressView(value: reindexProgress)
                            .tint(Color.deepTeal)
                    }
                }
                .frame(minHeight: 44)

                // Analytics Section
                sectionHeader("Analytics")

                // Share Usage Analytics
                Toggle(isOn: $preferences.shareUsageAnalytics) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Usage Analytics")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Text("Help us improve Reef by sharing anonymous usage data")
                            .font(.quicksand(13, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                    }
                }
                .tint(Color.deepTeal)
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Share Crash Reports
                Toggle(isOn: $preferences.shareCrashReports) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Crash Reports")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Text("Automatically send crash reports to help fix issues")
                            .font(.quicksand(13, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                    }
                }
                .tint(Color.deepTeal)
                .frame(minHeight: 44)

                // Your Data Section
                sectionHeader("Your Data")

                // Export My Data
                Button {
                    exportData()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                        Text("Export My Data")
                            .font(.quicksand(16, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                    }
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // What Data We Collect
                NavigationLink {
                    DataCollectionInfoView()
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                        Text("What Data We Collect")
                            .font(.quicksand(16, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                    }
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(effectiveColorScheme == .dark ? Color.warmDarkCard : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
            )
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateSizes()
        }
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will clear all cached data. Your documents and settings will not be affected.")
        }
        .alert("Clear Search History", isPresented: $showClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearSearchHistory()
            }
        } message: {
            Text("This will clear your search history.")
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, isFirst: Bool = false) -> some View {
        Text(title)
            .font(.quicksand(13, weight: .semiBold))
            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, isFirst ? 0 : 32)
            .padding(.bottom, 12)
    }

    private func calculateSizes() {
        // Calculate cache size
        Task {
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let size = folderSize(at: cacheURL)
            await MainActor.run {
                cacheSize = formatBytes(size)
            }
        }

        // Calculate storage used
        Task {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let size = folderSize(at: documentsURL)
            await MainActor.run {
                storageUsed = formatBytes(size)
            }
        }
    }

    private func folderSize(at url: URL?) -> Int64 {
        guard let url = url else { return 0 }
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        return totalSize
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func clearCache() {
        Task {
            if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                try? FileManager.default.removeItem(at: cacheURL)
                try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
            }
            await MainActor.run {
                calculateSizes()
            }
        }
    }

    private func clearSearchHistory() {
        // TODO: Implement search history clearing
    }

    private func startReindexing() {
        isReindexing = true
        reindexProgress = 0

        Task {
            // Simulate reindexing progress
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    reindexProgress = Double(i) / 10.0
                }
            }

            // TODO: Actually trigger RAGService reindexing
            // try? await RAGService.shared.reindexAllDocuments()

            await MainActor.run {
                isReindexing = false
                reindexProgress = 0
            }
        }
    }

    private func exportData() {
        Task {
            // Create a temporary directory for export
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ReefExport_\(Date().timeIntervalSince1970)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // TODO: Export actual user data
            // For now, create a placeholder file
            let infoFile = tempDir.appendingPathComponent("export_info.txt")
            let info = """
            Reef Data Export
            ================
            Exported: \(Date())

            This export includes:
            - Your profile information
            - Study preferences
            - Quiz and exam history
            - Unlocked species

            Note: Document files are stored locally on your device.
            """
            try? info.write(to: infoFile, atomically: true, encoding: .utf8)

            // Create zip file
            let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("ReefExport.zip")
            try? FileManager.default.removeItem(at: zipURL)

            // For simplicity, just use the info file directly
            await MainActor.run {
                exportURL = infoFile
                showExportSheet = true
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Data Collection Info View

struct DataCollectionInfoView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Group {
                    infoSection(
                        title: "Account Information",
                        items: [
                            "Your name (from Apple ID)",
                            "Your email (from Apple ID)",
                            "Anonymous user identifier"
                        ]
                    )

                    infoSection(
                        title: "Study Data",
                        items: [
                            "Course names and structure",
                            "Quiz and exam scores",
                            "Study time and patterns",
                            "Unlocked species progress"
                        ]
                    )

                    infoSection(
                        title: "Usage Analytics (Optional)",
                        items: [
                            "Feature usage patterns",
                            "App performance metrics",
                            "Error logs"
                        ]
                    )
                }

                Text("All data is stored securely and never shared with third parties. You can export or delete your data at any time from the Privacy settings.")
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("What Data We Collect")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.quicksand(16, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.deepTeal)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(item)
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.8))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(effectiveColorScheme == .dark ? Color.warmDarkCard : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
