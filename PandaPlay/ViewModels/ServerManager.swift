//
//  ServerManager.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import Combine

class ServerManager: ObservableObject {
    @Published var servers: [EmbyServer] = []
    @Published var currentServer: EmbyServer?
    @Published var hasConfiguredServer: Bool = false

    private let userDefaults = UserDefaults.standard
    private let serversKey = "saved_servers"
    private let selectedServerIdKey = "selected_server_id"

    init() {
        loadServers()
    }

    // MARK: - Server Management

    func addServer(url: String, name: String) {
        let normalizedURL = normalizeURL(url)

        // Check if server with same URL already exists
        if servers.contains(where: { $0.url == normalizedURL }) {
            // Update existing server name if provided
            if let index = servers.firstIndex(where: { $0.url == normalizedURL }) {
                if !name.isEmpty {
                    servers[index] = EmbyServer(id: servers[index].id, url: normalizedURL, name: name)
                }
                saveServers()
                currentServer = servers[index]
                userDefaults.set(servers[index].id, forKey: selectedServerIdKey)
                hasConfiguredServer = true
            }
            return
        }

        // Add new server
        let server = EmbyServer(id: UUID().uuidString, url: normalizedURL, name: name.isEmpty ? normalizedURL : name)
        servers.append(server)
        saveServers()
        currentServer = server
        userDefaults.set(server.id, forKey: selectedServerIdKey)
        hasConfiguredServer = true
    }

    func removeServer(_ server: EmbyServer) {
        servers.removeAll { $0.id == server.id }
        if currentServer?.id == server.id {
            currentServer = servers.first
            if let newCurrentServer = currentServer {
                userDefaults.set(newCurrentServer.id, forKey: selectedServerIdKey)
            } else {
                userDefaults.removeObject(forKey: selectedServerIdKey)
            }
        }
        saveServers()
        hasConfiguredServer = !servers.isEmpty
    }

    func updateServer(id: String, url: String, name: String) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else {
            return
        }

        let normalizedURL = normalizeURL(url)
        let displayName = name.isEmpty ? normalizedURL : name

        // Prevent URL conflicts with other servers.
        if servers.contains(where: { $0.id != id && $0.url == normalizedURL }) {
            return
        }

        let updated = EmbyServer(id: id, url: normalizedURL, name: displayName)
        servers[index] = updated

        if currentServer?.id == id {
            currentServer = updated
            userDefaults.set(updated.id, forKey: selectedServerIdKey)
        }

        saveServers()
        hasConfiguredServer = !servers.isEmpty
    }

    func setCurrentServer(_ server: EmbyServer) {
        currentServer = server
        userDefaults.set(server.id, forKey: selectedServerIdKey)
    }

    func switchServer(_ server: EmbyServer) {
        currentServer = server
        userDefaults.set(server.id, forKey: selectedServerIdKey)
    }

    func clearCurrentServer() {
        currentServer = nil
        hasConfiguredServer = false
    }

    func clearAllServers() {
        servers = []
        currentServer = nil
        hasConfiguredServer = false
        userDefaults.removeObject(forKey: serversKey)
    }

    // MARK: - Persistence

    private func loadServers() {
        if let data = userDefaults.data(forKey: serversKey),
           let decoded = try? JSONDecoder().decode([EmbyServer].self, from: data) {
            servers = decoded
            hasConfiguredServer = !servers.isEmpty

            // Restore last selected server
            if let selectedServerId = userDefaults.string(forKey: selectedServerIdKey),
               let selectedServer = servers.first(where: { $0.id == selectedServerId }) {
                currentServer = selectedServer
            } else {
                currentServer = servers.first
            }
        }
    }

    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            userDefaults.set(encoded, forKey: serversKey)
        }
    }

    // MARK: - Helpers

    private func normalizeURL(_ url: String) -> String {
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        return cleanURL
    }
}

// MARK: - Models

struct EmbyServer: Codable, Identifiable, Equatable {
    let id: String
    let url: String
    let name: String
}
