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

    init() {
        loadServers()
    }

    // MARK: - Server Management

    func addServer(url: String, name: String) {
        let normalizedURL = normalizeURL(url)
        let server = EmbyServer(id: UUID().uuidString, url: normalizedURL, name: name.isEmpty ? normalizedURL : name)
        servers.append(server)
        saveServers()
        currentServer = server
        hasConfiguredServer = true
    }

    func removeServer(_ server: EmbyServer) {
        servers.removeAll { $0.id == server.id }
        if currentServer?.id == server.id {
            currentServer = servers.first
        }
        saveServers()
        hasConfiguredServer = !servers.isEmpty
    }

    func setCurrentServer(_ server: EmbyServer) {
        currentServer = server
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
            currentServer = servers.first
            hasConfiguredServer = !servers.isEmpty
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

struct EmbyServer: Codable, Identifiable {
    let id: String
    let url: String
    let name: String
}
