//
//  ProfileService.swift
//  Reef
//
//  Networking service for user profile endpoints on Reef-Server.
//

import Foundation

// MARK: - Models

struct ProfileResponse: Codable {
    let apple_user_id: String
    let display_name: String?
    let email: String?
}

struct ProfileRequest: Codable {
    let display_name: String?
    let email: String?
}

// MARK: - ProfileService

@MainActor
class ProfileService {
    static let shared = ProfileService()

    private let baseURL = ServerConfig.baseURL
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    /// Save profile to server. Fire-and-forget — logs errors but doesn't throw.
    func saveProfile(userIdentifier: String, name: String?, email: String?) {
        Task {
            do {
                guard let url = URL(string: baseURL + "/users/profile") else { return }

                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(userIdentifier)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONEncoder().encode(
                    ProfileRequest(display_name: name, email: email)
                )

                let (_, _) = try await session.data(for: request)
            } catch {
                // Fire-and-forget — silently handle errors
            }
        }
    }

    /// Fetch profile from server. Throws on failure.
    func fetchProfile(userIdentifier: String) async throws -> ProfileResponse {
        guard let url = URL(string: baseURL + "/users/profile") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userIdentifier)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ProfileResponse.self, from: data)
    }

    /// Delete profile from server. Fire-and-forget.
    func deleteProfile(userIdentifier: String) {
        Task {
            do {
                guard let url = URL(string: baseURL + "/users/profile") else { return }

                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                request.setValue("Bearer \(userIdentifier)", forHTTPHeaderField: "Authorization")

                let (_, _) = try await session.data(for: request)
            } catch {
                // Fire-and-forget — silently handle errors
            }
        }
    }
}
