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
        print("DEBUG Auth: checkExistingCredential called (isSimulator: \(isSimulator))")
        guard let userIdentifier = KeychainService.get(.userIdentifier) else {
            print("DEBUG Auth: No userIdentifier in Keychain")
            return
        }
        print("DEBUG Auth: Found userIdentifier: \(userIdentifier)")

        // Simulator doesn't reliably support getCredentialState - trust Keychain instead
        if isSimulator {
            print("DEBUG Auth: Simulator detected, skipping credential state check")
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
            print("DEBUG Auth: getCredentialState returned: \(state.rawValue) (0=revoked, 1=authorized, 2=notFound, 3=transferred)")
            if let error = error {
                print("DEBUG Auth: getCredentialState error: \(error)")
            }
            Task { @MainActor in
                switch state {
                case .authorized:
                    print("DEBUG Auth: Credential authorized, setting isAuthenticated = true")
                    self?.userIdentifier = userIdentifier
                    self?.userName = KeychainService.get(.userName)
                    self?.userEmail = KeychainService.get(.userEmail)
                    self?.isAuthenticated = true

                    if self?.userName == nil || self?.userName?.isEmpty == true {
                        await self?.fetchProfileFromServer(userIdentifier: userIdentifier)
                    }
                case .revoked, .notFound:
                    print("DEBUG Auth: Credential revoked or not found, signing out")
                    self?.signOut()
                default:
                    print("DEBUG Auth: Unexpected credential state: \(state.rawValue)")
                    break
                }
            }
        }
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("DEBUG: Could not get AppleIDCredential")
                return
            }

            let userIdentifier = appleIDCredential.user
            KeychainService.save(userIdentifier, for: .userIdentifier)
            self.userIdentifier = userIdentifier

            // Debug logging
            print("DEBUG: Apple Sign In received:")
            print("DEBUG: - userIdentifier: \(userIdentifier)")
            print("DEBUG: - fullName: \(String(describing: appleIDCredential.fullName))")
            print("DEBUG: - givenName: \(String(describing: appleIDCredential.fullName?.givenName))")
            print("DEBUG: - familyName: \(String(describing: appleIDCredential.fullName?.familyName))")
            print("DEBUG: - email: \(String(describing: appleIDCredential.email))")

            // Only save name if Apple provides it (first sign-in only)
            if let fullName = appleIDCredential.fullName {
                let givenName = fullName.givenName ?? ""
                let familyName = fullName.familyName ?? ""
                let name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                print("DEBUG: - constructed name: '\(name)'")
                if !name.isEmpty {
                    self.userName = name
                    KeychainService.save(name, for: .userName)
                    print("DEBUG: - saved name to Keychain")
                }
            }

            // Fall back to stored name if Apple didn't provide one
            if self.userName == nil || self.userName?.isEmpty == true {
                if let storedName = KeychainService.get(.userName) {
                    self.userName = storedName
                    print("DEBUG: - loaded name from Keychain: \(storedName)")
                }
            }

            // Only save email if Apple provides it (first sign-in only)
            if let email = appleIDCredential.email {
                self.userEmail = email
                KeychainService.save(email, for: .userEmail)
                print("DEBUG: - saved email to Keychain")
            } else if let storedEmail = KeychainService.get(.userEmail) {
                self.userEmail = storedEmail
                print("DEBUG: - loaded email from Keychain: \(storedEmail)")
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
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }

    func completeProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        self.userName = trimmed
        KeychainService.save(trimmed, for: .userName)
        self.needsProfileCompletion = false
        print("DEBUG Auth: Profile completed with name: \(trimmed)")

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
                print("DEBUG Auth: Got name from server: \(name)")
            }
            if let email = profile.email, !email.isEmpty, self.userEmail == nil {
                self.userEmail = email
                KeychainService.save(email, for: .userEmail)
                print("DEBUG Auth: Got email from server: \(email)")
            }
            self.needsProfileCompletion = (self.userName == nil || self.userName?.isEmpty == true)
        } catch {
            print("DEBUG Auth: Server fetch failed — \(error.localizedDescription)")
            self.needsProfileCompletion = true
        }
    }

    func signOut() {
        print("DEBUG Auth: signOut called")
        KeychainService.deleteAll()
        NavigationStateManager.shared.clearState()
        userIdentifier = nil
        userName = nil
        userEmail = nil
        isAuthenticated = false
        needsProfileCompletion = false
    }
}
