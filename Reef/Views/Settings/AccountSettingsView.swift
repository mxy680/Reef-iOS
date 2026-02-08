//
//  AccountSettingsView.swift
//  Reef
//
//  Account settings tab showing profile info and account actions.
//

import SwiftUI
import PhotosUI

struct AccountSettingsView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @AppStorage("profileImageData") private var profileImageData: Data?

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var userInitials: String {
        let name = editedName.isEmpty ? (authManager.userName ?? "") : editedName
        guard !name.isEmpty else { return "?" }
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
                // Profile Section
                settingsSection(title: "Profile") {
                    // Avatar Row
                    HStack {
                        Text("Photo")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        Spacer()

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let profileImage = profileImage {
                                    profileImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.vibrantTeal)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Text(userInitials)
                                                .font(.quicksand(20, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }

                                // Pencil badge
                                Circle()
                                    .fill(Color.oceanMid)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Name Row
                    HStack {
                        Text("Name")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        Spacer()

                        if isEditingName {
                            TextField("Name", text: $editedName)
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    saveName()
                                }

                            Button {
                                saveName()
                            } label: {
                                Text("Save")
                                    .font(.quicksand(14, weight: .semiBold))
                                    .foregroundColor(Color.vibrantTeal)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(authManager.userName ?? "Not set")
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                            Button {
                                editedName = authManager.userName ?? ""
                                isEditingName = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.vibrantTeal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Email Row (read-only)
                    HStack {
                        Text("Email")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Text(authManager.userEmail ?? "Not set")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                    }
                    .padding(.vertical, 4)
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

                Spacer(minLength: 16)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .onAppear {
            loadProfileImage()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    profileImageData = data
                    if let uiImage = UIImage(data: data) {
                        profileImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
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
                if let uid = authManager.userIdentifier {
                    ProfileService.shared.deleteProfile(userIdentifier: uid)
                }
                authManager.signOut()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }

    // MARK: - Helpers

    private func saveName() {
        if !editedName.isEmpty {
            authManager.userName = editedName
            KeychainService.save(editedName, for: .userName)

            // Back up to server
            if let uid = authManager.userIdentifier {
                ProfileService.shared.saveProfile(
                    userIdentifier: uid,
                    name: editedName,
                    email: authManager.userEmail
                )
            }
        }
        isEditingName = false
    }

    private func loadProfileImage() {
        if let data = profileImageData, let uiImage = UIImage(data: data) {
            profileImage = Image(uiImage: uiImage)
        }
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
}

#Preview {
    AccountSettingsView(authManager: AuthenticationManager())
}
