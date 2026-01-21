//
//  ReefApp.swift
//  Reef
//
//  Created by Mark Shteyn on 1/20/26.
//

import SwiftUI
import SwiftData

@main
struct ReefApp: App {
    @StateObject private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                HomeView(authManager: authManager)
            } else {
                PreAuthView(authManager: authManager)
            }
        }
        .modelContainer(for: [Course.self, Material.self, Assignment.self, ExamAttempt.self, ExamQuestion.self])
    }
}
