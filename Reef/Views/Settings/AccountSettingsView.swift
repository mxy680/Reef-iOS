//
//  AccountSettingsView.swift
//  Reef
//
//  Account settings tab showing profile info and account actions.
//

import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var userInitials: String {
        guard let name = authManager.userName else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Card
                profileCard

                // Profile Info Section
                settingsSection(title: "Profile Info") {
                    infoRow(label: "Name", value: authManager.userName ?? "Not set")
                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))
                    infoRow(label: "Email", value: authManager.userEmail ?? "Not set")
                }

                // Sign In Method Section
                settingsSection(title: "Sign In Method") {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Text("Apple ID")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Text("Connected")
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.vibrantTeal)
                    }
                    .padding(.vertical, 4)
                }

                // Actions Section
                settingsSection(title: "Actions") {
                    // Sign Out Button
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                            Text("Sign Out")
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

                    // Delete Account Button
                    Button {
                        showDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                            Text("Delete Account")
                                .font(.quicksand(16, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.deleteRed.opacity(0.5))
                        }
                        .foregroundColor(Color.deleteRed)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out of Reef?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // TODO: Implement account deletion
                authManager.signOut()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color.vibrantTeal)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(userInitials)
                        .font(.quicksand(28, weight: .bold))
                        .foregroundColor(.white)
                )

            // Name and Email
            VStack(spacing: 4) {
                Text(authManager.userName ?? "User")
                    .font(.quicksand(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                if let email = authManager.userEmail {
                    Text(email)
                        .font(.quicksand(14, weight: .regular))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.3) : Color.sageMist.opacity(0.5))
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
        )
    }

    // MARK: - Helper Views

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

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.quicksand(16, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
            Spacer()
            Text(value)
                .font(.quicksand(16, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AccountSettingsView(authManager: AuthenticationManager())
}
