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

    init() {
        // Initialize RAG service on app launch
        Task.detached(priority: .background) {
            do {
                try await RAGService.shared.initialize()
                print("[ReefApp] RAG service initialized")
            } catch {
                print("[ReefApp] Failed to initialize RAG service: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                HomeView(authManager: authManager)
            } else {
                PreAuthView(authManager: authManager)
            }
        }
        .modelContainer(for: [Course.self, Note.self, Quiz.self, ExamAttempt.self, ExamQuestion.self])
    }
}
