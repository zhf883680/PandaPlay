//
//  AuthManager.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: EmbyUser?
    @Published var accessToken: String?
    @Published var userId: String?

    private var embyClient: EmbyClient?
    private let keychain = KeychainManager.shared
    private let preferences = UserDefaultsManager.shared

    private var currentServerId: String?

    // MARK: - Authentication

    func authenticate(serverURL: String, serverId: String, username: String, password: String) async throws {
        embyClient = EmbyClient(serverURL: serverURL)
        currentServerId = serverId

        let authResponse = try await embyClient?.authenticate(username: username, password: password)

        await MainActor.run {
            self.accessToken = authResponse?.accessToken
            self.userId = authResponse?.user?.id
            self.currentUser = authResponse?.user
            self.isAuthenticated = true

            // Save to keychain
            if let token = authResponse?.accessToken, let userId = authResponse?.user?.id {
                self.keychain.saveAccessToken(for: serverId, token: token)
                self.keychain.saveUserId(for: serverId, userId: userId)
                self.keychain.savePassword(for: serverId, password: password)
                self.keychain.saveUsername(for: serverId, username: username)
                self.preferences.selectedServerId = serverId
            }
        }
    }

    func loadSavedCredentials(serverId: String) -> (username: String, password: String)? {
        let username = keychain.loadUsername(for: serverId) ?? ""
        let password = keychain.loadPassword(for: serverId)
        if let password = password {
            return (username, password)
        }
        return nil
    }

    func tryAutoLogin(serverURL: String, serverId: String) async -> Bool {
        // Try to load saved credentials and authenticate
        if let (username, password) = loadSavedCredentials(serverId: serverId) {
            do {
                try await authenticate(serverURL: serverURL, serverId: serverId, username: username, password: password)
                return true
            } catch {
                return false
            }
        }
        return false
    }

    func logout(serverId: String? = nil) {
        if let serverId = serverId ?? currentServerId {
            keychain.delete(forKey: "server_\(serverId)_token")
            keychain.delete(forKey: "server_\(serverId)_userId")
        }

        isAuthenticated = false
        currentUser = nil
        accessToken = nil
        userId = nil
        embyClient = nil
        currentServerId = nil
    }

    // MARK: - Token Management

    func getAuthorizedHeaders() -> [String: String] {
        var headers = ["X-Emby-Token": ""]
        if let token = accessToken {
            headers["X-Emby-Token"] = token
        }
        return headers
    }
}
