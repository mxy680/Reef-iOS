//
//  PreAuthView.swift
//  Reef
//

import SwiftUI
import AuthenticationServices

struct PreAuthView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ZStack {
            LinearGradient.preAuthGradient(for: effectiveColorScheme)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Reef")
                    .font(.quicksand(48, weight: .bold))
                    .foregroundColor(.white)

                Text("Dive into smarter studying")
                    .font(.quicksand(20, weight: .regular))
                    .foregroundColor(effectiveColorScheme == .dark ? .pearlWhite.opacity(0.8) : .sageMist)

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(effectiveColorScheme == .dark ? .white : .white)
                .frame(maxWidth: 340, maxHeight: 50)
                .cornerRadius(12)

                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(effectiveColorScheme)
    }
}

#Preview {
    PreAuthView(authManager: AuthenticationManager())
}
