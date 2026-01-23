//
//  AboutView.swift
//  Reef
//
//  About tab showing app info, support links, and legal information.
//

import SwiftUI

struct AboutView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Info Section
                settingsSection(title: "App Info") {
                    // Version
                    HStack {
                        Text("Version")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Text(appVersion)
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.oceanMid)
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // What's New
                    NavigationLink {
                        WhatsNewView()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                            Text("What's New")
                                .font(.quicksand(16, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                        }
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                // Support Section
                settingsSection(title: "Support") {
                    // Send Feedback
                    linkRow(icon: "envelope", title: "Send Feedback", url: "mailto:feedback@reefapp.com")

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Help Center
                    linkRow(icon: "questionmark.circle", title: "Help Center", url: "https://reefapp.com/help")

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Report a Bug
                    linkRow(icon: "ant", title: "Report a Bug", url: "mailto:bugs@reefapp.com?subject=Bug%20Report")
                }

                // Connect Section
                settingsSection(title: "Connect") {
                    // Twitter/X
                    linkRow(icon: "bird", title: "Twitter / X", url: "https://twitter.com/reefapp")

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Instagram
                    linkRow(icon: "camera", title: "Instagram", url: "https://instagram.com/reefapp")

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Discord
                    linkRow(icon: "bubble.left.and.bubble.right", title: "Discord", url: "https://discord.gg/reefapp")
                }

                // Credits Section
                settingsSection(title: "Credits") {
                    // Meet the Team
                    NavigationLink {
                        TeamView()
                    } label: {
                        HStack {
                            Image(systemName: "person.3")
                                .font(.system(size: 18))
                            Text("Meet the Team")
                                .font(.quicksand(16, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                        }
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Acknowledgments
                    NavigationLink {
                        AcknowledgmentsView()
                    } label: {
                        HStack {
                            Image(systemName: "heart")
                                .font(.system(size: 18))
                            Text("Acknowledgments")
                                .font(.quicksand(16, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                        }
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                // Legal Section
                settingsSection(title: "Legal") {
                    // Terms of Service
                    linkRow(icon: "doc.text", title: "Terms of Service", url: "https://reefapp.com/terms")

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Privacy Policy
                    linkRow(icon: "lock.shield", title: "Privacy Policy", url: "https://reefapp.com/privacy")

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Open Source Licenses
                    NavigationLink {
                        OpenSourceLicensesView()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 18))
                            Text("Open Source Licenses")
                                .font(.quicksand(16, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                        }
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                // Reef Graphic
                reefGraphic
                    .padding(.top, 16)

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Helpers

    private func linkRow(icon: String, title: String, url: String) -> some View {
        Button {
            if let linkURL = URL(string: url) {
                UIApplication.shared.open(linkURL)
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.quicksand(16, weight: .medium))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
            }
            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.oceanMid)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.3) : Color.sageMist.opacity(0.5))
            )
        }
    }

    // MARK: - Reef Graphic

    private var reefGraphic: some View {
        VStack(spacing: 12) {
            // Simple reef-themed illustration using SF Symbols
            HStack(spacing: 20) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.vibrantTeal)
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.oceanMid)
                Image(systemName: "hare.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Color.deepSea)
            }

            Text("Made with \u{2764} for students")
                .font(.quicksand(14, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))

            Text("\u{00A9} 2026 Reef App")
                .font(.quicksand(12, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - What's New View

struct WhatsNewView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                releaseSection(
                    version: "1.0.0",
                    date: "January 2025",
                    changes: [
                        "Initial release of Reef",
                        "Document upload and annotation",
                        "Live AI feedback while studying",
                        "Quiz and exam generation",
                        "Species unlocking system",
                        "Personal reef visualization"
                    ]
                )
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func releaseSection(version: String, date: String, changes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version \(version)")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                Spacer()
                Text(date)
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.oceanMid)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(changes, id: \.self) { change in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.vibrantTeal)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(change)
                            .font(.quicksand(15, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.3) : Color.sageMist.opacity(0.5))
        )
    }
}

// MARK: - Team View

struct TeamView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("The people behind Reef")
                    .font(.quicksand(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                    .padding(.bottom, 8)

                // Team members
                teamMember(name: "Mark Shteyn", role: "Founder & Developer", emoji: "\u{1F9D1}\u{200D}\u{1F4BB}")
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("Meet the Team")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func teamMember(name: String, role: String, emoji: String) -> some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                Text(role)
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.oceanMid)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.3) : Color.sageMist.opacity(0.5))
        )
    }
}

// MARK: - Acknowledgments View

struct AcknowledgmentsView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Reef wouldn't be possible without the amazing open source community and these wonderful tools and services:")
                    .font(.quicksand(15, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.8))

                acknowledgmentSection(items: [
                    ("SwiftUI", "Apple's declarative UI framework"),
                    ("Core ML", "On-device machine learning"),
                    ("Vision", "Image analysis framework"),
                    ("PDFKit", "PDF rendering and annotation")
                ])
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func acknowledgmentSection(items: [(String, String)]) -> some View {
        VStack(spacing: 12) {
            ForEach(items, id: \.0) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0)
                            .font(.quicksand(16, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Text(item.1)
                            .font(.quicksand(13, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.3) : Color.sageMist.opacity(0.5))
        )
    }
}

// MARK: - Open Source Licenses View

struct OpenSourceLicensesView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reef uses the following open source libraries:")
                    .font(.quicksand(15, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.8))

                Text("No third-party open source libraries are currently used in this project. All functionality is built using Apple's native frameworks.")
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.3) : Color.sageMist.opacity(0.5))
                    )
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("Open Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AboutView()
}
