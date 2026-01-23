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

        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }

    func signOut() {
        print("DEBUG Auth: signOut called")
        KeychainService.deleteAll()
        userIdentifier = nil
        userName = nil
        userEmail = nil
        isAuthenticated = false
    }
}
