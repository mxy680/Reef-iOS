//
//  AuthenticationManager.swift
//  Reef
//

import SwiftUI
import AuthenticationServices

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userIdentifier: String?
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var needsProfileCompletion = false

    init() {
        // Load cached user info from Keychain
        userName = KeychainService.get(.userName)
        userEmail = KeychainService.get(.userEmail)
        checkExistingCredential()
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func checkExistingCredential() {
        guard let userIdentifier = KeychainService.get(.userIdentifier) else {
            return
        }

        // Simulator doesn't reliably support getCredentialState - trust Keychain instead
        if isSimulator {
            self.userIdentifier = userIdentifier
            self.userName = KeychainService.get(.userName)
            self.userEmail = KeychainService.get(.userEmail)
            self.isAuthenticated = true

            if self.userName == nil || self.userName?.isEmpty == true {
                Task { await fetchProfileFromServer(userIdentifier: userIdentifier) }
            }
            return
        }

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: userIdentifier) { [weak self] state, error in
            Task { @MainActor in
                switch state {
                case .authorized:
                    self?.userIdentifier = userIdentifier
                    self?.userName = KeychainService.get(.userName)
                    self?.userEmail = KeychainService.get(.userEmail)
                    self?.isAuthenticated = true

                    if self?.userName == nil || self?.userName?.isEmpty == true {
                        await self?.fetchProfileFromServer(userIdentifier: userIdentifier)
                    }
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            let userIdentifier = appleIDCredential.user
            KeychainService.save(userIdentifier, for: .userIdentifier)
            self.userIdentifier = userIdentifier

            // Only save name if Apple provides it (first sign-in only)
            if let fullName = appleIDCredential.fullName {
                let givenName = fullName.givenName ?? ""
                let familyName = fullName.familyName ?? ""
                let name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    self.userName = name
                    KeychainService.save(name, for: .userName)
                }
            }

            // Fall back to stored name if Apple didn't provide one
            if self.userName == nil || self.userName?.isEmpty == true {
                if let storedName = KeychainService.get(.userName) {
                    self.userName = storedName
                }
            }

            // Only save email if Apple provides it (first sign-in only)
            if let email = appleIDCredential.email {
                self.userEmail = email
                KeychainService.save(email, for: .userEmail)
            } else if let storedEmail = KeychainService.get(.userEmail) {
                self.userEmail = storedEmail
            }

            self.isAuthenticated = true

            // Sync with server
            if let name = self.userName, !name.isEmpty {
                // Have a name — fire-and-forget save to server
                ProfileService.shared.saveProfile(
                    userIdentifier: userIdentifier,
                    name: self.userName,
                    email: self.userEmail
                )
                self.needsProfileCompletion = false
            } else {
                // No name locally — try server before showing alert
                Task { await fetchProfileFromServer(userIdentifier: userIdentifier) }
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
        }
    }

    func completeProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        self.userName = trimmed
        KeychainService.save(trimmed, for: .userName)
        self.needsProfileCompletion = false

        // Back up to server
        if let uid = userIdentifier {
            ProfileService.shared.saveProfile(
                userIdentifier: uid,
                name: trimmed,
                email: userEmail
            )
        }
    }

    /// Fetch profile from server, save to Keychain if found, update published properties.
    private func fetchProfileFromServer(userIdentifier: String) async {
        do {
            let profile = try await ProfileService.shared.fetchProfile(userIdentifier: userIdentifier)
            if let name = profile.display_name, !name.isEmpty {
                self.userName = name
                KeychainService.save(name, for: .userName)
            }
            if let email = profile.email, !email.isEmpty, self.userEmail == nil {
                self.userEmail = email
                KeychainService.save(email, for: .userEmail)
            }
            self.needsProfileCompletion = (self.userName == nil || self.userName?.isEmpty == true)
        } catch {
            self.needsProfileCompletion = true
        }
    }

    func signOut() {
        KeychainService.deleteAll()
        NavigationStateManager.shared.clearState()
        userIdentifier = nil
        userName = nil
        userEmail = nil
        isAuthenticated = false
        needsProfileCompletion = false
    }
}
